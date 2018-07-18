--[[
    PE file format reader.
    This reader will essentially 'decompress' all the information
    in the PE file, and make all relevant content available
    through a standard Lua table.

    Typical usage on a Windows platform would be:

    local mfile = mmap(filename);
	local peparser = peparser:fromData(mfile:getPointer(), mfile.size);

    Once the peparser object has been constructed, it will already 
    contain the contents in an easily navigable form.
]]
local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")

local parse_DOS = require("peettles.parse_DOS")
local parse_exports = require("peettles.parse_exports")
local parse_imports = require("peettles.parse_imports")
local parse_resources = require("peettles.parse_resources")

local peparser = {}
setmetatable(peparser, {
    __call = function(self, ...)
        return self:create(...)
    end;
})
local peparser_mt = {
    __index = peparser;
}

function peparser.init(self, obj)
    obj = obj or {}

    setmetatable(obj, peparser_mt)

    return obj;
end

function peparser.create(self, obj)
    return self:init(obj)
end

function peparser.fromData(self, data, size)
    local ms = binstream(data, size, 0, true);
    local obj = self:create()

    return obj:parse(ms)
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


--
-- Given an RVA, look up the section header that encloses it 
-- return the table that represents that section
--
function peparser.GetEnclosingSectionHeader(self, rva)
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
function peparser.fileOffsetFromRVA(self, rva)
    local section, pos = self:GetEnclosingSectionHeader( rva);
    if not section then return false, "section not found for rva"; end

    local fileOffset = pos + section.PointerToRawData;

    return fileOffset
end

function peparser.readDOSHeader(self, res)
    local function isValidDOS(bytes)
        return bytes[0] == string.byte('M') and
            bytes[1] == string.byte('Z')
    end
    
    local ms = self.SourceStream;
    local e_magic = ms:readBytes(2);    -- Magic number, must be 'MZ'

    if not isValidDOS(e_magic) then
        return false, "'MZ' signature not found", e_magic
    end

    local res = res or {}

    res.e_magic = e_magic;                      -- Magic number
    res.e_cblp = ms:readUInt16();               -- Bytes on last page of file
    res.e_cp = ms:readUInt16();                 -- Pages in file
    res.e_crlc = ms:readUInt16();               -- Relocations
    res.e_cparhdr = ms:readUInt16();            -- Size of header in paragraphs
    res.e_minalloc = ms:readUInt16();           -- Minimum extra paragraphs needed
    res.e_maxalloc = ms:readUInt16();           -- Maximum extra paragraphs needed
    res.e_ss = ms:readUInt16();                 -- Initial (relative) SS value
    res.e_sp = ms:readUInt16();                 -- Initial SP value
    res.e_csum = ms:readUInt16();               -- Checksum
    res.e_ip = ms:readUInt16();                 -- Initial IP value
    res.e_cs = ms:readUInt16();                 -- Initial (relative) CS value
    res.e_lfarlc = ms:readUInt16();             -- File address of relocation table
    res.e_ovno = ms:readUInt16();               -- Overlay number
        ms:skip(4*2);                           -- e_res, basetype="uint16_t", repeating=4},    -- Reserved s
    res.e_oemid = ms:readUInt16();              -- OEM identifier (for e_oeminfo)
    res.e_oeminfo = ms:readUInt16();            -- OEM information; e_oemid specific
        ms:skip(10*2);                          -- e_res2, basetype="uint16_t", repeating=10},  -- Reserved s
    res.e_lfanew = ms:readUInt32();             -- File address of new exe header
    
    return res;
end

function peparser.readCOFF(self, res)
    
    local ms = self.SourceStream;
    res = res or {}

    res.Machine = ms:readWORD();
    res.NumberOfSections = ms:readWORD();     -- Windows loader limits to 96
    res.TimeDateStamp = ms:readDWORD();
    res.PointerToSymbolTable = ms:readDWORD();
    res.NumberOfSymbols = ms:readDWORD();
    res.SizeOfOptionalHeader = ms:readWORD();
    res.Characteristics = ms:readWORD();

    return res;
end

--[[
    In the context of a PEHeader, a directory is a simple
    structure containing a virtual address, and a size
]]
local function readDirectory(ms, id, res)
    res = res or {}
    
    res.ID = id;
    res.VirtualAddress = ms:readDWORD();
    res.Size = ms:readDWORD();

    return res;
end

-- Within the context of the OptionalHeader
-- Read the IMAGE_DATA_DIRECTORY entries
function peparser.readDirectoryTable(self)
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

    local ms = self.SourceStream;
    
    -- Read directory index entries
    self.PEHeader.Directories = {}
    for i, name in ipairs(dirNames) do
        local dir = readDirectory(ms, i-1);
        if dir.Size ~= 0 then
            self.PEHeader.Directories[name] = dir;
        end
    end
end

function peparser.readPE32Header(self, ms)
    --print("==== readPE32Header ====")
    local startOff = ms:tell();

    self.PEHeader = {
		-- Fields common to PE32 and PE+
		Magic = ms:readUInt16();	-- , default = 0x10b
		MajorLinkerVersion = ms:readUInt8();
		MinorLinkerVersion = ms:readUInt8();
		SizeOfCode = ms:readUInt32();
		SizeOfInitializedData = ms:readUInt32();
		SizeOfUninitializedData = ms:readUInt32();
		AddressOfEntryPoint = ms:readUInt32();      -- RVA
		BaseOfCode = ms:readUInt32();               -- RVA

		-- PE32 has BaseOfData, which is not in the PE32+ header
		BaseOfData = ms:readUInt32();               -- RVA

		-- The next 21 fields are Windows specific extensions to 
		-- the COFF format
		ImageBase = ms:readUInt32();
		SectionAlignment = ms:readUInt32();             -- How are sections alinged in RAM
		FileAlignment = ms:readUInt32();                -- alignment of sections in file
		MajorOperatingSystemVersion = ms:readUInt16();
		MinorOperatingSystemVersion = ms:readUInt16();
		MajorImageVersion = ms:readUInt16();
		MinorImageVersion = ms:readUInt16();
		MajorSubsystemVersion = ms:readUInt16();
		MinorSubsystemVersion = ms:readUInt16();
		Win32VersionValue = ms:readUInt32();             -- reserved
		SizeOfImage = ms:readUInt32();
		SizeOfHeaders = ms:readUInt32();                    -- Essentially, offset to first sections
		CheckSum = ms:readUInt32();
		Subsystem = ms:readUInt16();
		DllCharacteristics = ms:readUInt16();
		SizeOfStackReserve = ms:readUInt32();
		SizeOfStackCommit = ms:readUInt32();
		SizeOfHeapReserve = ms:readUInt32();
		SizeOfHeapCommit = ms:readUInt32();
		LoaderFlags = ms:readUInt32();
		NumberOfRvaAndSizes = ms:readUInt32();
    }

    -- Read directory index entries
    -- Only save the ones that actually
    -- have data in them
    self:readDirectoryTable();

    return self.PEHeader;
end

function peparser.readPE32PlusHeader(self, ms)
    self.isPE32Plus = true;

    self.PEHeader = {

		-- Fields common with PE32
		Magic = ms:readUInt16();	-- , default = 0x20b
		MajorLinkerVersion = ms:readUInt8();
		MinorLinkerVersion = ms:readUInt8();
		SizeOfCode = ms:readUInt32();
		SizeOfInitializedData = ms:readUInt32();
		SizeOfUninitializedData = ms:readUInt32();
		AddressOfEntryPoint = ms:readUInt32();
		BaseOfCode = ms:readUInt32();

		-- The next 21 fields are Windows specific extensions to 
		-- the COFF format
		ImageBase = ms:readUInt64();						-- size difference
		SectionAlignment = ms:readUInt32();
		FileAlignment = ms:readUInt32();
		MajorOperatingSystemVersion = ms:readUInt16();
		MinorOperatingSystemVersion = ms:readUInt16();
		MajorImageVersion = ms:readUInt16();
		MinorImageVersion = ms:readUInt16();
		MajorSubsystemVersion = ms:readUInt16();
		MinorSubsystemVersion = ms:readUInt16();
		Win32VersionValue = ms:readUInt32();
		SizeOfImage = ms:readUInt32();
		SizeOfHeaders = ms:readUInt32();
		CheckSum = ms:readUInt32();
		Subsystem = ms:readUInt16();
		DllCharacteristics = ms:readUInt16();
		SizeOfStackReserve = ms:readUInt64();				-- size difference
		SizeOfStackCommit = ms:readUInt64();				-- size difference
		SizeOfHeapReserve = ms:readUInt64();				-- size difference
		SizeOfHeapCommit = ms:readUInt64();				-- size difference
		LoaderFlags = ms:readUInt32();
		NumberOfRvaAndSizes = ms:readUInt32();
    }

    self:readDirectoryTable();

    return self.PEHeader;
end


function peparser.readDirectoryData(self)
    self.Directories = self.Directories or {}
    
    local dirNames = {
        Exports = parse_exports;
        Imports = parse_imports;
        Resources = parse_resources;
    }

    for dirName, parseit in pairs(dirNames) do
        local success, err = parseit(self);
        if success then
            self[dirName] = success;
        else
            print("ERROR PARSING: ", dirName, err);
        end
    end

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

function peparser.readSectionHeaders(self)
    local ms = self.SourceStream;

	local nsections = self.COFF.NumberOfSections;
	self.Sections = {}

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

		self.Sections[sec.Name] = sec
	end

	return self
end


function peparser.readPESignature(self)
    local ntheadertype = self.SourceStream:readBytes(4);
    if not IsPEFormatImageFile(ntheadertype) then
        return false, "not PE Format Image File"
    end

    self.PEHeader = {
        signature = ntheadertype;
    }

    return ntheadertype;
end

function peparser.readPEOptionalHeader(self)
    local function IsPe32Header(sig)
        return sig[0] == 0x0b and sig[1] == 0x01
    end
        
    local function IsPe32PlusHeader(sig)
        return sig[0] == 0x0b and sig[1] == 0x02
    end

    local ms = self.SourceStream;

-- NOTE: Using the sizeOfOptionalHeader, and current offset
-- we should be able to get a subrange of the stream to 
-- read from.  Not currently doing it.

    -- Read the 2 byte magic to figure out which kind
    -- of optional header we need to read
    local pemagic = ms:readBytes(2);
    --print(string.format("PEMAGIC: 0x%x 0x%x", pemagic[0], pemagic[1]))

    -- unwind reading the magic so we can read it again
    -- as part of reading the whole 'optional' header
    ms:seek(ms:tell()-2);


    if IsPe32Header(pemagic) then
        self:readPE32Header(ms);
    elseif IsPe32PlusHeader(pemagic) then
        self:readPE32PlusHeader(ms);
    end
end 

function peparser.parse(self, ms)
    self.SourceStream = ms;
    self._data = ms.data;
    self._size = ms.size;

    local err = false;
    self.DOS, err = parse_DOS(ms);

    --local DOSHeader, err, sig = self:readDOSHeader();
    if not self.DOS then 
        return false, err;
    end


    -- The stream should now be located at the 'PE' signature
    -- we assume we can only read Portable Executable
    -- anything else is an error
    local pesig, err = self:readPESignature()

    if not pesig then
        return false, err;
    end

    self.PESignature = pesig;
    self.COFF = self:readCOFF();

    --print("COFF, sizeOfOptionalHeader: ", self.COFF.SizeOfOptionalHeader)
    if self.COFF.SizeOfOptionalHeader > 0 then
        self:readPEOptionalHeader();
    end

    -- Now offset should be positioned at the section table
    self:readSectionHeaders()

    -- Now that we have section information, we should
    -- be able to read detailed directory information
    self:readDirectoryData()

    return self
end


return peparser