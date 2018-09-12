-- Read PDB stream 3 (DBI Info)
-- http://llvm.org/docs/PDB/DbiStream.html

local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;
local enum = require("peettles.enum")

local DBIVersions = enum {
    DBIImpvV41  = 930803,
    DBIImpvV50  = 19960307,
    DBIImpvV60  = 19970606,
    DBIImpvV70  = 19990903,
    DBIImpvV110 = 20091201,
    --DBIImpv     = DBIImpvV70,
};

local function printInfo(info)
    --print("  Signature = ", string.format("0x%X;",info.Signature))
    --print("  HeaderVersion = ", DBIVersions[info.HeaderVersion])
--[[
    for k,v in pairs(info) do
        if type(v) == 'number' then
        print(k, string.format("0x%X;", v))
        elseif type(v) == 'boolean' then
            print(k, v)
        elseif type(v) == 'table' then
            printInfo(v)
        end
    end
--]]
    return true
end

local function readSectionContribEntry(bs, res)
    res = res or {}
    res.Section = bs:readUInt16();
    res.Padding1 = bs:readBytes(2);
    res.Offset = bs:readInt32();
    res.Size = bs:readInt32();
    res.Characteristics = bs:readUInt32();
    res.ModuleIndex = bs:readUInt16();
    res.Padding2 = bs:readBytes(2);
    res.DataCrc = bs:readUInt32();
    res.RelocCrc = bs:readUInt32();

    return res;
end

local function read_ModuleInfoStream(info, ms, res)
    res = res or {}
    local bs = ms:range(info.ModInfoSize);



    local function readModInfo(bs, res)
        res = res or {}
        res.Unused1 = bs:readUInt32();
        res.SectionContr = readSectionContribEntry(bs);
        res.Flags = bs:readUInt16();
        res.ModuleSymStream = bs:readUInt16();
        res.SymByteSize = bs:readUInt32();
        res.C11ByteSize = bs:readUInt32();
        res.C13ByteSize = bs:readUInt32();
        res.SourceFileCount = bs:readUInt16();
        res.Padding = bs:readBytes(2);
        res.Unused2 = bs:readUInt32();
        res.SourceFileNameIndex = bs:readUInt32();
        res.PdbFilePathNameIndex = bs:readUInt32();
        res.ModuleName = bs:readString();
        res.ObjFileName = bs:readString();
--print(res.ModuleName)
--print(res.ObjFileName)
--print("--------------")
        return res;
    end
    
    while not bs:EOF() do
        table.insert(res, readModInfo(bs))
    end

    ms:skip(info.ModInfoSize)

    return res;
end

--[[
    enum class SectionContrSubstreamVersion : uint32_t {
  Ver60 = 0xeffe0000 + 19970605,
  V2 = 0xeffe0000 + 20140516
};
--]]

local function read_SectionContributionSubstream(info, ms, res)
    res = res or {}
    local bs = ms:range(info.SectionContributionSize);

    res.Version = bs:readUInt32();

    while not bs:EOF() do
        local entry = readSectionContribEntry(bs)
        --if res.Version == V2 then
        -- entry.ISectCoff = bs:readUInt32();
        --end

        table.insert(res, entry)
    end
    ms:skip(info.SectionContributionSize)

    return res;
end

--[[
    enum class SectionMapEntryFlags : uint16_t {
  Read = 1 << 0,              // Segment is readable.
  Write = 1 << 1,             // Segment is writable.
  Execute = 1 << 2,           // Segment is executable.
  AddressIs32Bit = 1 << 3,    // Descriptor describes a 32-bit linear address.
  IsSelector = 1 << 8,        // Frame represents a selector.
  IsAbsoluteAddress = 1 << 9, // Frame represents an absolute address.
  IsGroup = 1 << 10           // If set, descriptor represents a group.
};
]]
local function read_SectionMapSubstream(info, ms, res)
    res = res or {}
    local bs = ms:range(info.SectionMapSize);

    local header = {
        Count = bs:readUInt16();        -- number of segment descriptors
        LogCount = bs:readUInt16();     -- number of logical segment descriptors
    }
    res.Header = header;
    
    local entries = {}
    while not bs:EOF() do
        local entry = {
            Flags = bs:readUInt16();
            Ovl = bs:readUInt16();
            Group = bs:readUInt16();
            Frame = bs:readUInt16();
            SectionName = bs:readUInt16();
            ClassName = bs:readUInt16();
            Offset = bs:readUInt32();
            SectionLength = bs:readUInt32();
        }
        table.insert(entries, entry)
    end
    res.Entries = entries;
    ms:skip(info.SectionMapSize);

    return res;
end


-- reloadFileInfo
-- initfileinfo
local function read_SourceInfoSubstream(info, ms, res)
    res = res or {}
    local bs = ms:range(info.SourceInfoSize);

    res.NumModules = bs:readUInt16();       
    res.NumSourceFiles = bs:readUInt16();   -- ignore this, and used computed value instead
    
    res.ModIndices = {};
    for idx=0,res.NumModules-1 do
        res.ModIndices[idx] = bs:readUInt16();
    end

    res.ModFileCounts = {}
    for idx=0,res.NumModules-1 do 
        res.ModFileCounts[idx] = bs:readUInt16();
    end
    -- calculate sum of source file contributions
    res.NumSourceFilesComputed = 0;
    for idx=0,res.NumModules-1 do 
        res.NumSourceFilesComputed = res.NumSourceFilesComputed + res.ModFileCounts[idx];
    end

--print("NumSourceFiles: ", res.NumSourceFiles, "SUMMED: ", res.NumSourceFilesComputed)
    -- The filenames are represented as offsets into the stringbuffer
    -- We need to read these offsets so we can turn into indices to 
    -- actual strings later
    res.FileNameOffsets = {}
    for idx=0, res.NumSourceFilesComputed-1 do 
        res.FileNameOffsets[idx] = bs:readUInt32();
    end

    -- Now, use the filename offsets to create actual names
    -- this is wasteful, as we're using the offsets, and reading
    -- a unique name possibly multiple times
    res.UniqueFileNames = {}
    local ns = bs:range(bs:remaining())

    while not ns:EOF() do 
        local offset = ns:tell();
        local name = ns:readString();
        res.UniqueFileNames[offset] = name;
    end

    -- create an index that converts from offsets
    -- to indices for each module
    res.FileNames = {}
    for idx=0, res.NumSourceFilesComputed-1 do 
        res.FileNames[idx] = res.UniqueFileNames[res.FileNameOffsets[idx]]
        --print(res.FileNames[idx])
    end


    ms:skip(info.SourceInfoSize);

    return res;
end

local function read_OptionalDebugHeaderSubstream(info, ms, res)
    local res = res or {}
    local bs = ms:range(info.OptionalDbgHeaderSize);

    while not bs:EOF() do 
        local index = bs:readUInt16();
        --print(string.format("0x%x", index))
        print(index)
    end

    ms:skip(info.SourceInfoSize);

    return res;
end


--[[
    SN  uint16_t

    Follows structure:
        NewDBIHdr
    Consult dbi.cpp
        BOOL DBI1::fInit(BOOL fCreate)

    Read the initial stream structure

    BuildNumber bitfield

    // Version information
        union {
        struct {
            USHORT      usVerPdbDllMin : 8; // minor version and
            USHORT      usVerPdbDllMaj : 7; // major version and 
            USHORT      fNewVerFmt     : 1; // flag telling us we have rbld stored elsewhere (high bit of original major version)
        } vernew;                           // that built this pdb last.
        struct {
            USHORT      usVerPdbDllRbld: 4;
            USHORT      usVerPdbDllMin : 7;
            USHORT      usVerPdbDllMaj : 5;
        } verold;
        USHORT          usVerAll;
    };


    struct _flags {
        USHORT  fIncLink:1;     // true if linked incrmentally (really just if ilink thunks are present)
        USHORT  fStripped:1;    // true if PDB::CopyTo stripped the private data out
        USHORT  fCTypes:1;      // true if this PDB is using CTypes.
        USHORT  unused:13;      // reserved, must be 0.
    } flags;

]]
local function readStream(bs, res)
    res = res or {}

    res.VersionSignature = bs:readInt32();      -- Always 0xffff
    res.VersionHeader = bs:readUInt32();        -- a value from DBIVersions (usually V70)
    res.Age = bs:readUInt32();                  -- Number of times PDB has been written
    
    -- Global symbols
    res.GlobalStreamIndex = bs:readUInt16();
    res.BuildNumber = bs:readUInt16();

    -- Public Symbols
    res.PublicStreamIndex = bs:readUInt16();
    res.PdbDllVersion = bs:readUInt16();        -- build version of the pdb dll that built this pdb last
    
    res.SymRecordStream = bs:readUInt16();
    res.PdbDllRbld = bs:readUInt16();           -- rbld version of the pdb dll that built this pdb last.
    
    -- Seven substreams follow immediately after header
    -- These are their sizes
    res.ModInfoSize = bs:readUInt32();           -- size of rgmodi substream
    res.SectionContributionSize = bs:readUInt32();               -- size of Section Contribution substream
    res.SectionMapSize = bs:readUInt32();
    res.SourceInfoSize = bs:readUInt32();
    res.TypeServerSize = bs:readUInt32();           -- size of the Type Server Map substream
    res.MFCTypeServerIndex = bs:readUInt32();       -- index of MFC type server
    res.OptionalDbgHeaderSize = bs:readUInt32();    -- size of optional DbgHdr info appended to the end of the stream
    res.ECSubstreamSize = bs:readUInt32();          -- number of bytes in EC substream, or 0 if EC no EC enabled Mods


    local flags = bs:readUInt16();
    res.Flags = {
        WasIncrementallyLinked = band(flags, 0x1) ~= 0;
        PrivateSymbolsStripped = band(flags, 0x2) ~= 0;
        HasConflictingTypes = band(flags, 0x4) ~= 0;
    }

    res.Machine = bs:readUInt16();  -- Machine type
    bs:skip(4);                 -- pad out to 64 bytes for future growth.    
    
    -- Save the size of the Header
    res.HeaderSize = bs:tell();

    -- Read in Module Information  substream
    res.ModuleInfoStream = read_ModuleInfoStream(res, bs)
    
    -- Read in Section contribution substream
    res.SectionContributionStream = read_SectionContributionSubstream(res, bs);


    -- Read in Section Map substream
    res.SectionMapStream = read_SectionMapSubstream(res, bs);

    -- Read in FileInfo
    res.SourceInfoStream = read_SourceInfoSubstream(res, bs);


    -- Read in TSM substream
    res.TypeServerStream = bs:readBytes(res.TypeServerSize)

    -- Read in EC substream
    res.ECStream = bs:readBytes(res.ECSubstreamSize)

    -- Read in Debug Header substream
    res.OptionalDebugHeaderStream = read_OptionalDebugHeaderSubstream(res, bs)


    return res;
end

return {
    read = readStream;
    printLua = printInfo; 
}

