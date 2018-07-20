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
local parse_COFF = require("peettles.parse_COFF")
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

    if not self.DOS then 
        return false, err;
    end

    -- seek to the PE signature
    -- The stream should now be located at the 'PE' signature
    -- we assume we can only read Portable Executable
    -- anything else is an error

    ms:seek(self.DOS.DOSHeader.e_lfanew)
    self.COFF, err = parse_COFF(ms);


    return self
end


return peparser