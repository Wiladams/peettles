--[[
    PE File Format Spec
    https://docs.microsoft.com/en-us/windows/win32/debug/pe-format
]]
local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;
local lshift = bit.lshift;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local coff_utils = require("peettles.coff_utils")

local parse_exports = require("peettles.parse_exports")
local parse_imports = require("peettles.parse_imports")
local parse_resources = require("peettles.parse_resources")

local SymStorageClass = peenums.SymStorageClass;
local SymSectionNumber = peenums.SymSectionNumber;


-- IMAGE_SECTION_HEADER
-- https://docs.microsoft.com/en-us/windows/win32/debug/pe-format#section-header-format
function readSectionHeaders(ms, res, nsections)
    res = res or {}

    --print("readSectionHeaders: ", nsections)

    if (nsections < 1) then
        return res
    end

    -- should be 40 bytes per section header
    
    for i=1,nsections do
        local sentinel = ms:tell()

        local sec = {
            Name = ms:readBytes(8);
            VirtualSize = ms:readDWORD();
            VirtualAddress = ms:readDWORD();
            SizeOfRawData = ms:readDWORD();
            PointerToRawData = ms:readDWORD();      -- File based offset to raw data
            PointerToRelocations = ms:readDWORD();
            PointerToLinenumbers = ms:readDWORD();
            NumberOfRelocations = ms:readWORD();
            NumberOfLinenumbers = ms:readWORD();
            Characteristics = ms:readDWORD();
        }

        -- NOTE: The Name field is 8 bytes long.  It can 
        -- contain anything, including unicode.  We keep the
        -- raw byte array, and create a hopefully printable
        -- version in the StringName field.
		sec.StringName = coff_utils.stringFromBuff(sec.Name, 8)

        --print("  section: ", string.format("ID: %d, %s  0x%x", i-1, sec.StringName, sentinel))

        -- We capture the raw section data as well so that
        -- consumers can further parse this data if they wish.
        if sec.SizeOfRawData > 0 then
            local ds = ms:range(sec.SizeOfRawData, sec.PointerToRawData)
            sec.Data = ds:readBytes(sec.SizeOfRawData)
        end

        table.insert(res, sec)
    end
    --setmetatable(res, section_mt)

	return res
end


--[[
    In the context of a PEHeader, a directory is a simple
    structure containing a virtual address, and a size
    IMAGE_DIRECTORY_ENTRY_XXX
]]
local function readDirectoryEntry(ms, res)
    --print("readDirectoryEntry(): ", id)

    res = res or {}
    
    res.ID = id;
    res.VirtualAddress = ms:readDWORD();
    res.Size = ms:readDWORD();

    --print("readDirectoryEntry: ", res.id, res.VirtualAddress, res.Size)
    return res;
end

local function readContentData(ms, peinfo, res)
    res = res or {}

    local dirNames = {
        Exports = parse_exports;
        Imports = parse_imports;
        Resources = parse_resources;
    }

    for dirName, parseit in pairs(dirNames) do
        local success, err = parseit(ms, peinfo);
        if success then
            res[dirName] = success;
        else
            --print("ERROR PARSING: ", dirName, err);
        end
    end

    return res;
end

-- Within the context of the OptionalHeader
-- Read the IMAGE_DATA_DIRECTORY entries
function readDirectoryTable(bs, res)
    --print("==== readDirectoryTable ====")
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
        local dir = {id=i-1}
        --print("Reading directory: ", name, string.format("0x%x ", bs:tell()))
        local success, err = readDirectoryEntry(bs, dir);

        if success and (dir.Size ~= 0) then
            dir.Name = name;

            -- make the directory entry accessible in the results
            -- table
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

    return res;
end

local function readPE32PlusHeader(ms, res)
    --print("==== readPE32PlusHeader ====")

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

    return res;
end

--
-- IMAGE_OPTIONAL_HEADER
--  magic
--    0x010b = PE32
--    0x020b = PE32+
--
function readOptionalHeader(ms, res)
    --print("==== readOptionalHeader ====")
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
    --print("before readPE32Header: ", string.format("0x%x", ms:tell()))


    if IsPe32Header(pemagic) then
        readPE32Header(ms, res);
    elseif IsPe32PlusHeader(pemagic) then
        readPE32PlusHeader(ms, res);
    end

        -- Read directory index entries
    -- Only save the ones that actually
    -- have data in them
    --print("before readDirectoryEntries: ", string.format("0x%x", ms:tell()))
    res.Directory = {}
    local success, err = readDirectoryTable(ms, res.Directory);


    return res;
end 

--[[
    Do the work of actually parsing the interesting
    data in the file.
]]
local SizeOfSymbol = 18;

local function readAuxField(ms, symbol, res)
    if not symbol then 
        return false, "no symbol provided"
    end

    res = res or {}

    -- Format 1
    -- Function Definitions
    if symbol.StorageClass == SymStorageClass.IMAGE_SYM_CLASS_EXTERNAL and
        symbol.Type == 0x20 and symbol.SectionNumber > 0 then
        
        res.Kind = 1;
        res.TagIndex = ms:readUInt32();
        res.TotalSize = ms:readUInt32();
        res.PointerToLinenumber = ms:readUInt32();
        res.PointerToNextFunction = ms:readUInt32();
        ms:skip(2);

print("AUX - Function")

        return res;
    end

    -- Format 2
    -- .bf and .ef Symbols
    if symbol.StorageClass == SymStorageClass.IMAGE_SYM_CLASS_FUNCTION then
        res.Kind = 2;
        ms:skip(4);
        res.LineNumber = ms:readUInt16();
        ms:skip(6);
        --if symbol.Name == ".bf" then
            res.PointerToNextFunction = ms:readUInt32();
        --end
        ms:skip(2);
print("AUX - .bf and .ef")

        return res;
    end

    -- Format 3
    -- Weak externals
    if symbol.StorageClass == SymStorageClass.IMAGE_SYM_CLASS_EXTERNAL and
        symbol.SectionNumber == SymSectionNumber.IMAGE_SYM_UNDEFINED and
        symbol.Value == 0 then
        
        res.Kind = 3;
        res.TagIndex = ms:readUInt32();
        res.Characteristics = ms:readUInt32();
        ms:skip(10);
print("AUX - Weak External")
        return res;
    end

    -- Format 4
    -- Files
    if symbol.StorageClass == SymStorageClass.IMAGE_SYM_CLASS_FILE then
        local bytes = ms:readBytes(SizeOfSymbol)
        res.Kind = 4;
        res.FileName = coff_utils.stringFromBuff(bytes, SizeOfSymbol)
print("AUX - FILE: ", res.FileName)

        return res;
    end

    -- Format 5
    -- Section Definitions
    if symbol.StorageClass == SymStorageClass.IMAGE_SYM_CLASS_STATIC then
        res.Kind = 5;
        res.Length = ms:readUInt32();
        res.NumberOfRelocations = ms:readUInt16();
        res.NumberOfLineNumbers = ms:readUInt16();
        res.CheckSum = ms:readUInt32();
        res.Number = ms:readUInt16();
        res.Selection = ms:readUInt8();
        ms:skip(3);
--print("== AUX 5 - Section Def ==")
--print("Length: ", res.Length)
--print("Number: ", res.Number)

        return res;
    end

    -- Unknown auxilary format
    
    res.Kind = 0;
    res.Data = ms:readBytes(SizeOfSymbol)
    return res;
end


-- nSims includes number of auxilary symbols
local function readSymbolTable(ms, nSims, strTableSize, res)
    res = res or {}

    -- If there are no symbols, then we are done
    if nSims == 0 then
        return res;
    end

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
            --BaseType = ms:readOctet();
            --ComplexType = ms:readOctet();
            Type = ms:readUInt16();
            StorageClass = ms:readOctet();
            NumberOfAuxSymbols = ms:readUInt8();
        }

        -- if first 4 bytes of string are '0'
        -- then it is a string lookup, otherwise
        -- it's a name <= 8 bytes
        if sym.Name[0] ~= 0 then
            sym.Name = coff_utils.stringFromBuff(sym.Name, 8);
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
            -- classify and read the specific aux type

            for auxCnt = 1, sym.NumberOfAuxSymbols do
                counter = counter + 1;
                local auxfld, err = readAuxField(ms, sym)
                --print("AUX FIELD: ", sym.Name, auxfld.Kind)
                table.insert(sym.Aux, auxfld)
            end
        end
        table.insert(res, sym);
    end

    return res;
end

local function readStringTable(ms, res)
    print("==== readStringTable ====")

    res = res or {}

    -- first read a size
    local sizeOfTable = ms:readUInt32();

    print("  SIZE OF TABLE: ", sizeOfTable)
    
    if sizeOfTable <= 4 then
        return false, "No Strings in Table";
    end


    local ns, err = ms:range(sizeOfTable-4)
    if not ns then
        print("ERROR: ", err, sizeOfTable, ms.size, ms.cursor)
        return false, err;
    end

    while true do
        local str, err = ns:readString();
        print("  RST: ", str, err)
        if not str then
            break;
        end
        
        table.insert(res, str);
    end

    return res, sizeOfTable-4;
end

-- The 'COFF' format shows up in a few places.  It is used
-- at the beginning of .obj files, as well as within .lib files
-- and ultimately in .dll and .exe files
-- For the most part, in all these cases, they can be read the same way
-- The one exception is the .lib file.  In some cases, the regular COFF format
-- is used, but in the case of a import library, this other form, the Import Header
-- is used.  When to use one or the other is determined by the initial "Machine"
-- and "nSections" from the COFF
local function readImportHeader(bs, res)
    res = res or {}
    res.Offset = bs:tell();
    res.Sig1 = bs:readUInt16();
    res.Sig2 = bs:readUInt16();
    res.Version = bs:readUInt16();
    res.Machine = bs:readUInt16();
    res.TimeDateStamp = bs:readUInt32();
    res.SizeOfData = bs:readUInt32();
    res.OrdHint = bs:readUInt16();
    res.NameType = bs:readUInt16();

    -- we can create a binstream range limited
    -- to the SizeOfData to read the strings
    -- but for now, we'll just trust there are 
    -- two null terminated strings
    res.SymbolName = bs:readString();
    res.DllName = bs:readString();

--[[
print("= ImportHeader =")
print(string.format("  Sig1: %04x", res.Sig1))
print(string.format("  Sig2: %04X", res.Sig2))
print(string.format("Version: ", res.Version))
print(string.format("Machine: 0x%04X", res.Machine))
--]]

    return res;
end

-- IMAGE_FILE_HEADER
-- Windows loader used to limit to 96
-- but now (as of Windows 10), it can be the full 
-- range of 16-bit number (65535)
-- Machine
--  0x014C - Intel 386
--  0x014D - Intel 486
--  0x0200 - Intel Itanium
--  0x8664 - AMD64

local function readCOFFHeader(bs, res)

    res = res or {}

    res.HeaderStart = bs:tell();
    res.Machine = bs:readWORD();
    res.NumberOfSections = bs:readWORD();     
    res.TimeDateStamp = bs:readDWORD();
    res.PointerToSymbolTable = bs:readDWORD();
    res.NumberOfSymbols = bs:readDWORD();
    res.SizeOfOptionalHeader = bs:readWORD();
    res.Characteristics = bs:readWORD();

    return res;
end


-- IMAGE_NT_HEADERS
local function parse_COFF(ms, res)
    print("==== parse_COFF ====")

    res = res or {}

    local fileStart = ms:tell();
    local hdr, err = readHeader(ms, res);

    if not hdr then
        return false, err
    end

    if hdr.Machine ==0 and hdr.NumberOfSections == 0xffff then
        -- read it again as an ImportHeader
        ms:seek(fileStart)
        hdr, err = readImportHeader(ms)
--print("IMPORT HEADER ==")
--        print("Sig1: ", hdr.Sig1)
--        print("Sig2: ", hdr.Sig2)
        -- read null terminated import name
        -- read null termianted dll name
        return hdr;
    end

    if hdr.SizeOfOptionalHeader > 0  then
        hdr.PEHeader, err = readPEOptionalHeader(ms);
    end

    -- Now offset should be positioned at the section table
    hdr.Sections = {}
    local success, err = readSectionHeaders(ms, hdr.Sections, hdr.NumberOfSections)
    --setmetatable(hdr.Sections, section_mt)


    -- Either read the string table before the symbol
    -- table, or do fixups afterwards
    local strTableOffset = fileStart + hdr.PointerToSymbolTable + SizeOfSymbol*hdr.NumberOfSymbols;
    ms:seek(strTableOffset)
    hdr.StringTable, strTableSize = readStringTable(ms)
    --print("  STRING TABLE SIZE: ", strTableSize)
    if not hdr.StringTable then
        strTableSize = false;
    end

    -- Read symbol table
    --print("POINTER TO SYMBOLS: ", string.format("0x%04X", res.PointerToSymbolTable))
    --print("  NUMBER OF SYMBOLS: ", hdr.NumberOfSymbols)
    ms:seek(fileStart + hdr.PointerToSymbolTable)
    hdr.SymbolTable = readSymbolTable(ms, hdr.NumberOfSymbols, strTableSize);

--[[
    -- Now that we have section information, we should
    -- be able to read detailed directory information
    if res.PEHeader then
        res.Content = readContentData(res, ms)
    end
--]]

    return res;
end

local exports = {
    readImportHeader = readImportHeader,
    readCOFFHeader = readCOFFHeader,
    readOptionalHeader = readOptionalHeader,
    readSectionHeaders = readSectionHeaders,
    readStringTable = readStringTable,
    readSymbolTable = readSymbolTable,
    readContentData = readContentData,
    parse_COFF = parse_COFF,
}

return exports;
