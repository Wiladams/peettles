local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;
local lshift = bit.lshift;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")

local parse_exports = require("peettles.parse_exports")
local parse_imports = require("peettles.parse_imports")
local parse_resources = require("peettles.parse_resources")



--
-- Given an RVA, look up the section header that encloses it 
-- return the table that represents that section
--
local section_t = {}
local section_mt = {
    __index = section_t;
}
function section_t.GetEnclosingSection(sections, rva)
    --print("==== EnclosingSection: ", rva)
    for secname, section in pairs(sections) do
        -- Is the RVA within this section?
        local pos = rva - section.VirtualAddress;
        if pos >= 0 and pos < section.VirtualSize then
            -- return section, and the calculated offset within the section
            return section, pos 
        end
    end

    return false;
end

-- There are many values within the file which are 'RVA' (Relative Virtual Address)
-- In order to translate this RVA into a file offset, we use the following
-- function.
function section_t.fileOffsetFromRVA(self, rva)
    local section, pos = self:GetEnclosingSection(rva);
    if not section then return false, "section not found for rva"; end
    
    local fileOffset = section.PointerToRawData + pos;
    
    return fileOffset
end

local function stringFromBuff(buff, size)
	local truelen = size
	for i=size-1,0,-1 do
		if buff[i] == 0 then
		    truelen = truelen - 1
		end
	end
	return ffi.string(buff, truelen)
end

function readSectionHeaders(ms, res, nsections)
    res = res or {}


    for i=1,nsections do
        local sec = {
            Name = ms:readBytes(8);
            VirtualSize = ms:readDWORD();
            VirtualAddress = ms:readDWORD();
            SizeOfRawData = ms:readDWORD();
            PointerToRawData = ms:readDWORD();
            PointerToRelocations = ms:readDWORD();
            PointerToLinenumbers = ms:readDWORD();
            NumberOfRelocations = ms:readWORD();
            NumberOfLinenumbers = ms:readWORD();
            Characteristics = ms:readDWORD();
        }

        -- NOTE: Not sure if we should use all 8 bytes or null terminate
        -- the spec says use 8 bytes, don't assume null terminated ASCII
        -- in practice, these are usually ASCII strings.
        -- They could be UNICODE, or any 8 consecutive bytes.  Since
        -- Lua doesn't really care, I suppose the right thing to do is
        -- use all 8 bytes, and only create a 'pretty' name for display purposes

		sec.Name = stringFromBuff(sec.Name, 8)
--print("Section: ", sec.Name)
		--res[sec.Name] = sec
        table.insert(res, sec)
    end

	return res
end


--[[
    In the context of a PEHeader, a directory is a simple
    structure containing a virtual address, and a size
]]
local function readDirectoryEntry(ms, id, res)
    res = res or {}
    
    res.ID = id;
    res.VirtualAddress = ms:readDWORD();
    res.Size = ms:readDWORD();

    return res;
end

local function readDirectoryData(coffinfo, ms, res)
    res = res or {}

    local dirNames = {
        Exports = parse_exports;
        Imports = parse_imports;
        Resources = parse_resources;
    }

    for dirName, parseit in pairs(dirNames) do
        local success, err = parseit(ms, coffinfo);
        if success then
            res[dirName] = success;
        else
            print("ERROR PARSING: ", dirName, err);
        end
    end

    return res;
end

-- Within the context of the OptionalHeader
-- Read the IMAGE_DATA_DIRECTORY entries
function readDirectoryTable(ms, res)
    res = res or {}

    -- List of directories in the order
-- they show up in the file
    local dirNames = {
    "ExportTable",
    "ImportTable",
    "ResourceTable",
    "ExceptionTable",
    "CertificateTable",
    "BaseRelocationTable",
    "Debug",
    "Architecture",
    "GlobalPtr",
    "TLSTable",
    "LoadConfigTable",
    "BoundImport",
    "IAT",
    "DelayImportDescriptor",
    "CLRRuntimeHeader",
    "Reserved"
    }
    
    -- Read directory index entries
    for i, name in ipairs(dirNames) do
        local dir = readDirectoryEntry(ms, i-1);
        if dir.Size ~= 0 then
            dir.Name = name;
            -- get the section as well
            res[name] = dir;
        end
    end

    return res;
end

local function readPE32Header(ms, res)
    res = res or {}
    --print("==== readPE32Header ====")

	-- Fields common to PE32 and PE+
	res.Magic = ms:readUInt16();	-- , default = 0x10b
    res.MajorLinkerVersion = ms:readUInt8();
    res.MinorLinkerVersion = ms:readUInt8();
    res.SizeOfCode = ms:readUInt32();
    res.SizeOfInitializedData = ms:readUInt32();
    res.SizeOfUninitializedData = ms:readUInt32();
    res.AddressOfEntryPoint = ms:readUInt32();      -- RVA
    res.BaseOfCode = ms:readUInt32();               -- RVA

	-- PE32 has BaseOfData, which is not in the PE32+ header
	res.BaseOfData = ms:readUInt32();               -- RVA

	-- The next 21 fields are Windows specific extensions to 
	-- the COFF format
	res.ImageBase = ms:readUInt32();
	res.SectionAlignment = ms:readUInt32();             -- How are sections alinged in RAM
	res.FileAlignment = ms:readUInt32();                -- alignment of sections in file
	res.MajorOperatingSystemVersion = ms:readUInt16();
	res.MinorOperatingSystemVersion = ms:readUInt16();
	res.MajorImageVersion = ms:readUInt16();
	res.MinorImageVersion = ms:readUInt16();
	res.MajorSubsystemVersion = ms:readUInt16();
	res.MinorSubsystemVersion = ms:readUInt16();
	res.Win32VersionValue = ms:readUInt32();             -- reserved
	res.SizeOfImage = ms:readUInt32();
	res.SizeOfHeaders = ms:readUInt32();                    -- Essentially, offset to first sections
	res.CheckSum = ms:readUInt32();
	res.Subsystem = ms:readUInt16();
	res.DllCharacteristics = ms:readUInt16();
	res.SizeOfStackReserve = ms:readUInt32();
	res.SizeOfStackCommit = ms:readUInt32();
	res.SizeOfHeapReserve = ms:readUInt32();
	res.SizeOfHeapCommit = ms:readUInt32();
	res.LoaderFlags = ms:readUInt32();
	res.NumberOfRvaAndSizes = ms:readUInt32();


    -- Read directory index entries
    -- Only save the ones that actually
    -- have data in them
    res.Directories = readDirectoryTable(ms);

    return res;
end

local function readPE32PlusHeader(ms, res)
    res = res or {}

    res.isPE32Plus = true;
		-- Fields common with PE32
		res.Magic = ms:readUInt16();	-- should be = 0x20b
		res.MajorLinkerVersion = ms:readUInt8();
		res.MinorLinkerVersion = ms:readUInt8();
		res.SizeOfCode = ms:readUInt32();
		res.SizeOfInitializedData = ms:readUInt32();
		res.SizeOfUninitializedData = ms:readUInt32();
		res.AddressOfEntryPoint = ms:readUInt32();
		res.BaseOfCode = ms:readUInt32();

		-- The next 21 fields are Windows specific extensions to 
		-- the COFF format
		res.ImageBase = ms:readUInt64();						-- size difference
		res.SectionAlignment = ms:readUInt32();
		res.FileAlignment = ms:readUInt32();
		res.MajorOperatingSystemVersion = ms:readUInt16();
		res.MinorOperatingSystemVersion = ms:readUInt16();
		res.MajorImageVersion = ms:readUInt16();
		res.MinorImageVersion = ms:readUInt16();
		res.MajorSubsystemVersion = ms:readUInt16();
		res.MinorSubsystemVersion = ms:readUInt16();
		res.Win32VersionValue = ms:readUInt32();
		res.SizeOfImage = ms:readUInt32();
		res.SizeOfHeaders = ms:readUInt32();
		res.CheckSum = ms:readUInt32();
		res.Subsystem = ms:readUInt16();
		res.DllCharacteristics = ms:readUInt16();
		res.SizeOfStackReserve = ms:readUInt64();				-- size difference
		res.SizeOfStackCommit = ms:readUInt64();				-- size difference
		res.SizeOfHeapReserve = ms:readUInt64();				-- size difference
		res.SizeOfHeapCommit = ms:readUInt64();				-- size difference
		res.LoaderFlags = ms:readUInt32();
		res.NumberOfRvaAndSizes = ms:readUInt32();


    res.Directories = readDirectoryTable(ms);

    return res;
end



function readPEOptionalHeader(ms, res)
    res = res or {}

    local function IsPe32Header(sig)
        return sig[0] == 0x0b and sig[1] == 0x01
    end
        
    local function IsPe32PlusHeader(sig)
        return sig[0] == 0x0b and sig[1] == 0x02
    end

-- NOTE: Using the sizeOfOptionalHeader, and current offset
-- we should be able to get a subrange of the stream to 
-- read from.  Not currently doing it.

    -- Read the 2 byte magic to figure out which kind
    -- of optional header we need to read
    local pemagic = ms:readBytes(2);
    res.magic = pemagic;
    --print(string.format("PEMAGIC: 0x%x 0x%x", pemagic[0], pemagic[1]))
    if not IsPe32Header(pemagic) and not IsPe32PlusHeader(pemagic) then
        return false, sig;
    end

    -- unwind reading the magic so we can read it again
    -- as part of reading the whole 'optional' header
    ms:seek(ms:tell()-2);


    if IsPe32Header(pemagic) then
        readPE32Header(ms, res);
    elseif IsPe32PlusHeader(pemagic) then
        readPE32PlusHeader(ms, res);
    end

    return res;
end 

--[[
    Do the work of actually parsing the interesting
    data in the file.
]]
local SizeOfSymbol = 18;

-- nSims includes number of auxilary symbols
local function readSymbolTable(ms, nSims, strTableSize, res)
    res = res or {}
    local actualSims = 0;
    local symStart = ms:tell();
    local strTableStart = symStart + nSims * SizeOfSymbol;
    
    local ns = false;
    if strTableSize then
        ns = ms:range(strTableSize, strTableStart)
    end

--print("NSIMS: ", nSims)
    local counter = 0;
    while counter < nSims do
        counter = counter + 1;
        local sym = {
            SymbolIndex = counter;
            Name = ms:readBytes(8);
            Value = ms:readUInt32();
            SectionNumber = ms:readInt16();
            BaseType = ms:readOctet();
            ComplexType = ms:readOctet();
            --Type = ms:readUInt16();
            StorageClass = ms:readOctet();
            NumberOfAuxSymbols = ms:readUInt8();
        }

        -- if first 4 bytes of string are '0'
        -- then it is a string lookup, otherwise
        -- it's a name <= 8 bytes
        if sym.Name[0] ~= 0 then
            sym.Name = stringFromBuff(sym.Name, 8);
        else
            -- calculate offset within string table
            local idx = sym.Name[4]+
                lshift(sym.Name[5],8)+
                lshift(sym.Name[6], 16)+
                lshift(sym.Name[7],24);
            --print("IDX: ", idx)
            ns:seek(idx)
            sym.Name = ns:readString();
            -- lookup name in string stable
        end

        if sym.NumberOfAuxSymbols > 0 then
            sym.Aux = {}
            for auxCnt = 1, sym.NumberOfAuxSymbols do
                counter = counter + 1;
                ms:skip(SizeOfSymbol);
                table.insert(sym.Aux, {AuxName = "AUX"});
            end
        end
        table.insert(res, sym);
    end

    return res;
end

local function readStringTable(ms, res)
    res = res or {}

    -- first read a size
    local sizeOfTable = ms:readUInt32();
    if sizeOfTable <= 4 then
        return false, "No Strings in Table";
    end

    --print("SIZE OF TABLE: ", sizeOfTable)
    local ns, err = ms:range(sizeOfTable-4)
    if not ns then
        --print("ERROR: ", err, sizeOfTable, ms.size, ms.cursor)
        return false, err;
    end

    while true do
        local str, err = ns:readString();
        --print("RST: ", str, err)
        if not str then
            break;
        end
        
        table.insert(res, str);
    end

    return res, sizeOfTable-4;
end

local function readImportHeader(bs, res)
    res = res or {}
    res.Sig1 = bs:readUInt16();
    res.Sig2 = bs:readUInt16();
    res.Version = bs:readUInt16();
    res.Machine = bs:readUInt16();
    res.TimeDateStamp = bs:readUInt32();
    res.SizeOfData = bs:readUInt32();
    res.OrdHint = bs:readUInt16();
    res.NameType = bs:readUInt16();

--[[
print("= ImportHeader =")
print(string.format("  Sig1: %04x", res.Sig1))
print(string.format("  Sig2: %04X", res.Sig2))
print(string.format("Version: ", res.Version))
print(string.format("Machine: 0x%04X", res.Machine))
--]]

    return res;
end

-- Windows loader used to limit to 96
-- but now (as of Windows 10), it can be the full 
-- range of 16-bit number (65535)
local function readHeader(ms, res)

    res = res or {}

    res.Machine = ms:readWORD();
    res.NumberOfSections = ms:readWORD();     
--print("MACHINE: ", string.format("0x%x", res.Machine))
--print("SECTIONS: ", res.NumberOfSections)
    res.TimeDateStamp = ms:readDWORD();
    res.PointerToSymbolTable = ms:readDWORD();
    res.NumberOfSymbols = ms:readDWORD();
    res.SizeOfOptionalHeader = ms:readWORD();
    res.Characteristics = ms:readWORD();

--[[
    print("== COFF ==")
    print("Machine:", string.format("0x%x", res.Machine))
    print("nSections: ", res.NumberOfSections)
    print("nSymbols: ", res.NumberOfSymbols)
    print("SizeOfOptionalHeader: ", res.SizeOfOptionalHeader)
--]]

    return res;
end



local function parse_COFF(ms, res)
    res = res or {}

    local fileStart = ms:tell();
    local hdr, err = readHeader(ms, res);

    if res.SizeOfOptionalHeader > 0  then
        res.PEHeader, err = readPEOptionalHeader(ms);
    end

    -- Now offset should be positioned at the section table
    res.Sections = readSectionHeaders(ms, nil, res.NumberOfSections)
    setmetatable(res.Sections, section_mt)

    -- Either read the string table before the symbol
    -- table, or do fixups afterwards
    ms:seek(fileStart + res.PointerToSymbolTable + SizeOfSymbol*hdr.NumberOfSymbols)
    res.StringTable, strTableSize = readStringTable(ms)
    --print("  STRING TABLE SIZE: ", strTableSize)
    if not res.StringTable then
        strTableSize = false;
    end

    -- Read symbol table
    --print("POINTER TO SYMBOLS: ", string.format("0x%04X", res.PointerToSymbolTable))
    --print("  NUMBER OF SYMBOLS: ", hdr.NumberOfSymbols)
    ms:seek(fileStart + res.PointerToSymbolTable)
--    local strTableOffset = fileStart + res.PointerToSymbolTable + SizeOfSymbol*hdr.NumberOfSymbols;
    res.SymbolTable = readSymbolTable(ms, hdr.NumberOfSymbols, strTableSize);


--[[
    -- Now that we have section information, we should
    -- be able to read detailed directory information
    if res.PEHeader then
        res.Directory = readDirectoryData(res, ms)
    end
--]]

    return res;
end

return parse_COFF;
