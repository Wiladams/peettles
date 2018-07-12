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

local function IsPe32Header(sig)
return sig[0] == 0x0b and sig[1] == 0x01
end

local function IsPe32PlusHeader(sig)
return sig[0] == 0x0b and sig[1] == 0x02
end

--
-- Given an RVA, look up the section header that encloses it and return a
-- pointer to its IMAGE_SECTION_HEADER
--
function peparser.GetEnclosingSectionHeader(self, rva)
    --print("==== EnclosingSection: ", rva)
    for secname, section in pairs(self.Sections) do
        -- Is the RVA within this section?
        --print(secname, section.VirtualAddress, section.VirtualAddress+section.VirtualSize)
        local pos = rva - section.VirtualAddress;
        if pos >= 0 and pos < section.VirtualSize then
            -- return section, and the calculated fileoffset of the rva
            return section, pos 
        end
    end

    return false;
end

-- There are many values within the file which are 'RVA' (Relative Virtual Address)
-- In order to translate this RVA into a file offset, we use the following
-- function.
function peparser.fileOffsetFromRVA(self, rva)
--print("==== fileOffsetFromRVA: ", rva)
    local section = self:GetEnclosingSectionHeader( rva);
    if not section then return false; end

    local fileOffset = rva - section.VirtualAddress + section.PointerToRawData;

    return fileOffset
end

function peparser.readDOSHeader(self)
    local ms = self.SourceStream;
    local e_magic = ms:readBytes(2);    -- Magic number, must be 'MZ'
    
    local function isValidDOS(bytes)
        return bytes[0] == string.byte('M') and
            bytes[1] == string.byte('Z')
    end
    
    if not isValidDOS(e_magic) then
        return false, "'MZ' signature not found", e_magic
    end

    local res = {
        e_magic = e_magic;                      -- Magic number
        e_cblp = ms:readUInt16();               -- Bytes on last page of file
        e_cp = ms:readUInt16();                 -- Pages in file
        e_crlc = ms:readUInt16();               -- Relocations
        e_cparhdr = ms:readUInt16();            -- Size of header in paragraphs
        e_minalloc = ms:readUInt16();           -- Minimum extra paragraphs needed
        e_maxalloc = ms:readUInt16();           -- Maximum extra paragraphs needed
        e_ss = ms:readUInt16();                 -- Initial (relative) SS value
        e_sp = ms:readUInt16();                 -- Initial SP value
        e_csum = ms:readUInt16();               -- Checksum
        e_ip = ms:readUInt16();                 -- Initial IP value
        e_cs = ms:readUInt16();                 -- Initial (relative) CS value
        e_lfarlc = ms:readUInt16();             -- File address of relocation table
        e_ovno = ms:readUInt16();               -- Overlay number
        ms:skip(4*2);                           -- e_res, basetype="uint16_t", repeating=4},    -- Reserved s
        e_oemid = ms:readUInt16();              -- OEM identifier (for e_oeminfo)
        e_oeminfo = ms:readUInt16();            -- OEM information; e_oemid specific
        ms:skip(10*2);                          -- e_res2, basetype="uint16_t", repeating=10},  -- Reserved s
        e_lfanew = ms:readUInt32();             -- File address of new exe header
    }


    return res;
end



function peparser.readCOFF(self)
    local ms = self.SourceStream;

    local res = {
        Machine = ms:readUInt16();
        NumberOfSections = ms:readUInt16();     -- Windows loader limits to 96
        TimeDateStamp = ms:readUInt32();
        PointerToSymbolTable = ms:readUInt32();
        NumberOfSymbols = ms:readUInt32();
        SizeOfOptionalHeader = ms:readUInt16();
        Characteristics = ms:readUInt16();
    }

    return res;
end

--[[
    In the context of a PEHeader, a directory is a simple
    structure containing a virtual address, and a size
]]
local function readDirectory(ms, id)
    local res = {
        ID = id;
        VirtualAddress = ms:readUInt32();   -- RVA
        Size = ms:readUInt32();
    }

    return res;
end

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

function peparser.readDirectoryTable(self)
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
    print("==== readPE32Header ====")
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


function peparser.readDirectory_Export(self)
    --print("==== readDirectory_Export ====")
    local dirTable = self.PEHeader.Directories.ExportTable
    if not dirTable then 
        print("NO EXPORT TABLE")
        return false 
    end

    -- If the virtual address is zero, then we don't actually
    -- have any exports
    if dirTable.VirtualAddress == 0 then
        print("  No Virtual Address")
        return false;
    end

    -- We use the directory entry to lookup the actual export table.
    -- We need to turn the VirtualAddress into an actual file offset
    local fileOffset = self:fileOffsetFromRVA(dirTable.VirtualAddress)

    -- We now know where the actual export table exists, so 
    -- create a binary stream, and position it at the offset
    local ms = binstream(self._data, self._size, fileOffset, true)


    -- We are now in position to read the actual export table data
    -- The data consists of various bits and pieces of information, including
    -- pointers to the actual export information.
    self.Export = {    
        Characteristics = ms:readUInt32();
        TimeDateStamp = ms:readUInt32();
        MajorVersion = ms:readUInt16();
        MinorVersion = ms:readUInt16();
        nName = ms:readUInt32();                -- Relative to image base
        nBase = ms:readUInt32();
        NumberOfFunctions = ms:readUInt32();
        NumberOfNames = ms:readUInt32();
        AddressOfFunctions = ms:readUInt32();
        AddressOfNames = ms:readUInt32();
        AddressOfNameOrdinals = ms:readUInt32();
    }
    local res = self.Export;

    -- Get the internal name of the module
    local nNameOffset = self:fileOffsetFromRVA(res.nName)
    if nNameOffset then
        -- use a separate stream to read the string so we don't
        -- upset the positioning on the one that's reading
        -- the import descriptors
        local ns = binstream(self._data, self._size, nNameOffset, true)
        self.Export.ModuleName = ns:readString();
        self.ModuleName = self.Export.ModuleName;

        --print("Module Name: ", res.ModuleName)
    end 

    -- Get the function pointers
    --local EATable = {}  -- ffi.new("uint32_t[?]", res.NumberOfFunctions)
    self.Export.AllFunctions = {};
    if res.NumberOfFunctions > 0 then
        local EATOffset = self:fileOffsetFromRVA(res.AddressOfFunctions);
        local EATStream = binstream(self._data, self._size, EATOffset, true);

        --print("EATOffset: ", string.format("0x%08X", EATOffset))

        -- Get array of function pointers
        -- EATable represents a '0' based array of these function RVAs
        for i=0, res.NumberOfFunctions-1 do 
            local AddressRVA = EATStream:readUInt32()
            
            --print("----------------")
            --print("    AddressRVA: ", string.format("0x%08X",AddressRVA));
            if AddressRVA ~= 0 then
                local section = self:GetEnclosingSectionHeader(AddressRVA)
                local ExportOffset = self:fileOffsetFromRVA(AddressRVA)

                -- We use the AddressRVA to figure out which section the function
                -- body is located in.  If that section is not a code section, then
                -- the RVA is actually a pointer to a string, which is a forward
                -- reference to a function in another .dll
                
                -- To figure out whether the section pointed to has code or not, 
                -- we can use the name '.text', or '.code'
                -- but, a better approach is to use the peenums.SectionCharacteristics
                -- and look for IMAGE_SCN_MEM_EXECUTE, IMAGE_SCN_MEM_READ and IMAGE_SCN_CNT_CODE
                if section then
                    --print("   Section Name: ", section.Name)
                    -- Check to see if the section the RVA points to is actually
                    -- a code section.  If it is, then save the Address
                    if band(section.Characteristics, peenums.SectionCharacteristics.IMAGE_SCN_MEM_EXECUTE) ~= 0 and
                        band(section.Characteristics, peenums.SectionCharacteristics.IMAGE_SCN_MEM_READ)~=0  and
                        band(section.Characteristics, peenums.SectionCharacteristics.IMAGE_SCN_CNT_CODE)~=0 then

                        self.Export.AllFunctions[i] = AddressRVA;
                    else
                        -- If not a code section, then it must be a forwarder
                        local ForwardStream = binstream(self._data, self._size, ExportOffset, true)
                        local forwardName = ForwardStream:readString();
                        --print("FORWARD: ", forwardName)
                        self.Export.AllFunctions[i] = forwardName;
                    end
                else
                    print("NO SECTION FOUND for AdressRVA:  ", i)
                end
            else
                --EATable[i] = false;
            end
        end
    end

    -- Get the names if the Names array exists
    self.Export.NamedFunctions = {}
    if res.NumberOfNames > 0 then
        local ENTOffset = self:fileOffsetFromRVA(res.AddressOfNames)
        local ENTStream = binstream(self._data, self._size, ENTOffset, true);

        -- Setup a stream for the AddressOfNameOrdinals (EOT) table
        local EOTOffset = self:fileOffsetFromRVA(res.AddressOfNameOrdinals);
        local EOTStream = binstream(self._data, self._size, EOTOffset, true);

        -- create a stream we'll use repeatedly to read name values
        local nameStream = binstream(self._data, self._size, 0, true);
        
        for i=1, res.NumberOfNames do
            -- create a stream pointing at the specific name
            local nameRVA = ENTStream:readUInt32();
            local nameOffset = self:fileOffsetFromRVA(nameRVA)
            nameStream:seek(nameOffset)

            local name = nameStream:readString();
            local hint = EOTStream:readUInt16();
            local ordinal = hint + res.nBase;
            local index = hint;
            --local funcptr = self.Export.AllFunctions[ordinal];
            local funcptr = self.Export.AllFunctions[index];

            --print("  name: ", ordinal, name)
            table.insert(self.Export.NamedFunctions, {name = name, hint=hint, ordinal = ordinal , index = index, funcptr=funcptr})
        end
    end

    -- Last list, functions exported by ordinal only
    local function nameByIndex(index)
        for i, entry in ipairs(self.Export.NamedFunctions) do
            if entry.index == index then
                return entry;
            end
        end
        return false;
    end

    self.Export.OrdinalOnly = {}
    for index, value in pairs(self.Export.AllFunctions) do
        if not nameByIndex(index) then
            self.Export.OrdinalOnly[index] = value;
        end
	end

    return self.Export;
end



function peparser.readDirectory_Import(self)

    --print("==== readDirectory_Import ====")
    local IMAGE_ORDINAL_FLAG32 = 0x80000000
    local IMAGE_ORDINAL_FLAG64 = 0x8000000000000000ULL;
    
    self.Imports = {}
    local dirTable = self.PEHeader.Directories.ImportTable
    if not dirTable then return false end

    -- Get section import directory is in
    local importsStartRVA = dirTable.VirtualAddress
	local importsSize = dirTable.Size
	local importdescripptr = self:fileOffsetFromRVA(dirTable.VirtualAddress)

	if not importdescripptr then
		print("No section found for import directory")
		return
    end
    

	--print("file offset: ", string.format("0x%x",importdescripptr));

     -- Setup a binstream and start reading
    local ImageImportDescriptorStream = binstream(self._data, self._size, 0, true)
    ImageImportDescriptorStream:seek(importdescripptr);
	while true do
        local res = {
            OriginalFirstThunk  = ImageImportDescriptorStream:readUInt32();   -- RVA to IMAGE_THUNK_DATA array
            TimeDateStamp       = ImageImportDescriptorStream:readUInt32();
            ForwarderChain      = ImageImportDescriptorStream:readUInt32();
            Name1               = ImageImportDescriptorStream:readUInt32();   -- RVA, Name of the .dll or .exe
            FirstThunk          = ImageImportDescriptorStream:readUInt32();
        }

        if (res.Name1 == 0 and res.OriginalFirstThunk == 0 and res.FirstThunk == 0) then 
            break;
        end

--[[
        print("== IMPORT ==")
        print(string.format("OriginalFirstThunk: 0x%08x (0x%08x)", res.OriginalFirstThunk, self:fileOffsetFromRVA(res.OriginalFirstThunk)))
        print(string.format("     TimeDateStamp: 0x%08x", res.TimeDateStamp))
        print(string.format("    ForwarderChain: 0x%08x", res.ForwarderChain))
        print(string.format("             Name1: 0x%08x (0x%08x)", res.Name1, self:fileOffsetFromRVA(res.Name1)))
        print(string.format("        FirstThunk: 0x%08x", res.FirstThunk))
--]]
        -- The .Name1 field contains an RVA which points to
        -- the actual string name of the .dll
        -- So, get the file offset, and read the string
        local Name1Offset = self:fileOffsetFromRVA(res.Name1)
        if Name1Offset then
            -- use a separate stream to read the string so we don't
            -- upset the positioning on the one that's reading
            -- the import descriptors
            local ns = binstream(self._data, self._size, Name1Offset, true)

            res.DllName = ns:readString();
            --print("DllName: ", res.DllName)
            self.Imports[res.DllName] = {};
        end 

        -- Iterate over the invividual import entries
        -- The thunk points to an array of IMAGE_THUNK_DATA structures
        -- which is comprised of a single uint32_t
		local thunkRVA = res.OriginalFirstThunk
		local thunkIATRVA = res.FirstThunk
        if thunkRVA == 0 then
            thunkRVA = thunkIATRVA
        end


		if (thunkRVA ~= 0) then
            local thunkRVAOffset = self:fileOffsetFromRVA(thunkRVA);
--print(string.format("ThunkRVA: 0x%08X (0x%08X)", thunkRVA, ThunkArrayOffset))

            -- this will point to an array of IMAGE_THUNK_DATA objects
            -- so create a separate stream to read them
            local ThunkArrayStream = binstream(self._data, self._size, thunkRVAOffset, true)

            -- Read individual Import names or ordinals
            while (true) do
                local ThunkDataRVA = 0ULL;
                if self.isPE32Plus then
                        --print("PE32Plus")
                    ThunkDataRVA = ThunkArrayStream:readUInt64();
                        --print("ThunkDataRVA(64): ", ThunkDataRVA)
                else
                    ThunkDataRVA = ThunkArrayStream:readUInt32();
                    --print("ThunkDataRVA(32): ", ThunkDataRVA)
                end

                --print(string.format("ThunkDataRVA: 0x%08X (0x%08X)", ThunkDataRVA, self:fileOffsetFromRVA(ThunkDataRVA)))
                if ThunkDataRVA == 0 then
                    break;
                end

                local ThunkDataOffset = self:fileOffsetFromRVA(ThunkDataRVA)

                local asOrdinal = false;
                local ordinal = 0;
                -- ordinal is indicated if high order bit is set
                -- then the ordinal itself is in the lower 16 bits
                if self.isPE32Plus then
                    if band(ThunkDataRVA, IMAGE_ORDINAL_FLAG64) ~= 0 then
                        asOrdinal = true;
                        ordinal = tonumber(band(0xffff, ThunkDataRVA))
                    end
                else
                    if band(ThunkDataRVA, IMAGE_ORDINAL_FLAG32) ~= 0 then
                        asOrdinal = true;
                        ordinal = tonumber(band(0xffff, ThunkDataRVA))
                    end
                end 

                -- Check for Ordinal only import
                -- must be mindful of 32/64-bit
                if (asOrdinal) then
                    --print("** IMPORT ORDINAL!! **")
                    table.insert(self.Imports[res.DllName], ordinal)
                else
                    -- Read the entries in the nametable
                    local HintNameStream = binstream(self._data, self._size, ThunkDataOffset, true);

                    local hint = HintNameStream:readUInt16();
                    local actualName = HintNameStream:readString();

                    --print(string.format("\t0x%04x %s", hint, actualName))
                    table.insert(self.Imports[res.DllName], actualName);
                end
            end
        end
    end

    return res;
end

-- Read the resource directory
    -- Reading the resource hierarchy is recursive
    -- so , we define a function that will be called
    -- recursively to traverse the entire hierarchy
    -- Each time through, we keep track of the level, in case
    -- we want to do something with that information.

function peparser.readDirectory_Resource(self)
    -- lookup the entry for the resource directory
    local dirTable = self.PEHeader.Directories.ResourceTable
    if not dirTable then 
        return false, "ResourceTable directory not found" 
    end
    
    -- find the associated section
    local resourcedirectoryOffset = self:fileOffsetFromRVA(dirTable.VirtualAddress)
    local bs = self.SourceStream:range(dirTable.Size, resourcedirectoryOffset)


    local function readResourceDirectory(bs, res, tab, level)
        level = level or 0
        res = res or {}
        --print(tab, "-- READ RESOURCE DIRECTORY")

            res.isDirectory = true;
            res.Characteristics = bs:readUInt32();          -- 0
            res.TimeDateStamp = bs:readUInt32();            -- 4
            res.MajorVersion = bs:readUInt16();             -- 8
            res.MinorVersion = bs:readUInt16();             -- 10
            res.NumberOfNamedEntries = bs:readUInt16();     -- 12
            res.NumberOfIdEntries = bs:readUInt16();        -- 14, 16


        res.Entries = {}

        local cnt = 0;
        while (cnt < res.NumberOfNamedEntries + res.NumberOfIdEntries) do
            local entry = {
                first = bs:readUInt32();
                second = bs:readUInt32();
            }
            table.insert(res.Entries, entry)
            cnt = cnt + 1;
        end


        -- Now that we have all the entries (IMAGE_RESOURCE_DIRECTORY_ENTRY)
        -- go through them and perform a specific action for each based on what it is
        for i, entry in ipairs(res.Entries) do
            --print(tab, "ENTRY")
            --local newentry = {}
            -- check to see if it's a string or an ID
            if band(entry.first, 0x80000000) ~= 0 then
                --print(tab, " STRING")
                -- bits 0-30 are an RVA to a UNICODE string
                entry.Name = band(entry.first, 0x7fffffff)
                -- get RVA offset
                -- local unilen = readUInt16();
                -- readString(unilen)
                -- convert unicode to ASCII
            else
                --print(tab, "  ID: ", string.format("0x%x", entry.first))
                entry.ID = entry.first;
            end

            -- entry.second determines whether we're going after
            -- a leaf node, or just another directory
            --print(tab, "  SECOND: ", string.format("0x%x", entry.second), band(entry.second, 0x80000000))
            if band(entry.second, 0x80000000) ~= 0 then
                --print(tab, "  DIRECTORY")
                local offset = band(entry.second, 0x7fffffff)
                -- pointer to another image directory
                bs:seek(offset)
                readResourceDirectory(bs, entry, tab.."    ", level+1)
            else
                --print(tab, "  LEAF: ", entry.second)
                -- we finally have actual data, so read the data entry
                -- entry.second is an offset from start of root directory
                -- seek to the offset, and start reading
                bs:seek(entry.second)

                entry.isData = true;
                entry.DataRVA = bs:readUInt32();
                entry.Size = bs:readUInt32();
                entry.CodePage = bs:readUInt32();
                entry.Reserved = bs:readUInt32();

--[[
                print(tab, "    DataRVA: ", string.format("0x%08X", entry.DataRVA));
                print(tab, "       Size: ",entry.Size);
                print(tab, "  Code Page: ", entry.CodePage);
                print(tab, "   Reserved: ", entry.Reserved);
--]]
                -- The DataRVA points to the actual data
                -- it is supposed to be an offset from the start
                -- of the resource stream
                bs:seek(entry.DataRVA)
                entry.Data = bs:readBytes(entry.Size)
            end
        end

        return res;
    end

    self.Resources = readResourceDirectory(bs, {}, "", 1);
end


function peparser.readDirectoryData(self)
    self.Directories = self.Directories or {}
    
    self:readDirectory_Export();
    self:readDirectory_Import();
    self:readDirectory_Resource();
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
            VirtualSize = ms:readNumber(4);
            VirtualAddress = ms:readNumber(4);
            SizeOfRawData = ms:readNumber(4);
            PointerToRawData = ms:readNumber(4);
            PointerToRelocations = ms:readNumber(4);
            PointerToLinenumbers = ms:readNumber(4);
            NumberOfRelocations = ms:readNumber(2);
            NumberOfLinenumbers = ms:readNumber(2);
            Characteristics = ms:readUInt32();
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

--[[
    DOS Header
    COFF Header
]]
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
    local ms = self.SourceStream;

-- NOTE: Using the sizeOfOptionalHeader, and current offset
-- we should be able to get a subrange of the stream to 
-- read from.  Not currently doing it.

    -- Read the 2 byte magic for the optional header
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

    local DOSHeader, err, sig = self:readDOSHeader();
    if not DOSHeader then 
        return false, err, sig;
    end

    local DOSBodySize = DOSHeader.e_lfanew - ms:tell();
    self.DOS = {
        Header = DOSHeader;
        StubSize = DOSBodySize;
        Stub = ms:readBytes(DOSBodySize);   -- Valid DOS stub program
    }
 
    -- seek to where the PE header
    -- is supposed to start
    ms:seek(DOSHeader.e_lfanew)

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