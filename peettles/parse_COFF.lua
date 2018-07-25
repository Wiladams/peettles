local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")







--
-- Given an RVA, look up the section header that encloses it 
-- return the table that represents that section
--
local function GetEnclosingSectionHeader(sections, rva)
    --print("==== EnclosingSection: ", rva)
    for secname, section in pairs(self.Sections) do
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
local function fileOffsetFromRVA(sections, rva)
    local section, pos = GetEnclosingSectionHeader(sections, rva);
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

		res[sec.Name] = sec
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
    res.Directories = {}
    for i, name in ipairs(dirNames) do
        local dir = readDirectoryEntry(ms, i-1);
        if dir.Size ~= 0 then
            res.Directories[name] = dir;
        end
    end
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
    readDirectoryTable(ms, res);

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


    readDirectoryTable(ms, res);

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
--[[
    PE\0\0 - PE header
    NE\0\0 - 16-bit Windows New Executable
    LE\0\0 - Windows 3.x virtual device driver (VxD)
    LX\0\0 - OS/2 2.0
]]
local function IsPEFormatImageFile(sig)
    return sig[0] == string.byte('P') and
        sig[1] == string.byte('E') and
        sig[2] == 0 and
        sig[3] == 0
end

-- Windows loader used to limit to 96
-- but now (as of Windows 10), it can be the full 
-- range of 16-bit number (65535)
function readHeader(ms, res)

    res = res or {}

    res.Machine = ms:readWORD();
    res.NumberOfSections = ms:readWORD();     
    res.TimeDateStamp = ms:readDWORD();
    res.PointerToSymbolTable = ms:readDWORD();
    res.NumberOfSymbols = ms:readDWORD();
    res.SizeOfOptionalHeader = ms:readWORD();
    res.Characteristics = ms:readWORD();

    return res;
end


local function parse_COFF(ms, res)
    res = res or {}

    -- We expect to see 'PE' as an indicator that what is
    -- to follow is in fact a PE file.  If not, we quit early
    local ntheadertype = ms:readBytes(4);
    if not IsPEFormatImageFile(ntheadertype) then
        return false, "not PE Format Image File"
    end

    res.Signature = ntheadertype;

    local hdr, err = readHeader(ms, res);

    --print("COFF, sizeOfOptionalHeader: ", self.COFF.SizeOfOptionalHeader)
    if res.SizeOfOptionalHeader < 1 then
        return res;
    end


    res.PEHeader, err = readPEOptionalHeader(ms);
    if not res.PEHeader then
        return false, err;
    end


    -- Now offset should be positioned at the section table
    res.Sections = readSectionHeaders(ms, nil, res.PEHeader.NumberOfRvaAndSizes)

    -- Now that we have section information, we should
    -- be able to read detailed directory information
    --res.Directory = readDirectoryData(ms)

    return res;
end

return parse_COFF;
