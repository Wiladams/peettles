-- Read PDB stream 3 (DBI Info)
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

    for k,v in pairs(info) do
        if type(v) == 'number' then
        print(k, string.format("0x%X;", v))
        elseif type(v) == 'boolean' then
            print(k, v)
        elseif type(v) == 'table' then
            printInfo(v)
        end
    end

    return true
end

--[[
    SN  uint16_t

    Follows structure:
        NewDBIHdr
    Consult dbi.cpp
        BOOL DBI1::fInit(BOOL fCreate)

    Read the initial stream structure
]]
local function readStream(bs, res)
    res = res or {}

    res.Signature = bs:readUInt32();
    res.HeaderVersion = bs:readUInt32();
    res.Age = bs:readUInt32();
    

--[[
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
--]]
    -- Global symbols
    res.GSSyms = bs:readUInt16();
    res.Version = bs:readUInt16();

    -- Public Symbols
    res.PSSyms = bs:readUInt16();
    res.VerPdbDllBuild = bs:readUInt16();   -- build version of the pdb dll that built this pdb last
    
    res.SymRecs = bs:readUInt16();
    res.VerPdbDllRBld = bs:readUInt16();    -- rbld version of the pdb dll that built this pdb last.
    
    res.SizeOfGpModi = bs:readUInt32();           -- size of rgmodi substream
    res.SizeOfSC = bs:readUInt32();               -- size of Section Contribution substream

    res.SizeOfSecMap = bs:readUInt32();
    res.SizeOfFileInfo = bs:readUInt32();
    res.SizeOfTSMap = bs:readUInt32();    -- size of the Type Server Map substream
    res.MFC = bs:readUInt32();       -- index of MFC type server
    res.SizeOfDbgHdr = bs:readUInt32();   -- size of optional DbgHdr info appended to the end of the stream
    res.SizeOfECInfo = bs:readUInt32();   -- number of bytes in EC substream, or 0 if EC no EC enabled Mods

--[[
    struct _flags {
        USHORT  fIncLink:1;     // true if linked incrmentally (really just if ilink thunks are present)
        USHORT  fStripped:1;    // true if PDB::CopyTo stripped the private data out
        USHORT  fCTypes:1;      // true if this PDB is using CTypes.
        USHORT  unused:13;      // reserved, must be 0.
    } flags;
--]]
    local flags = bs:readUInt16();
    res.Flags = {
        fIncLink = band(flags, 0x1) ~= 0;
        fStripped = band(flags, 0x2) ~= 0;
        fCTypes = band(flags, 0x4) ~= 0;
    }

    res.Machine = bs:readUInt16();  -- Machine type
    bs:skip(4);                 -- pad out to 64 bytes for future growth.    
    
    -- Save the size of the Header
    res.HeaderSize = bs:tell();

    -- Calculate supposed stream size
    local calcSize = res.HeaderSize +
        res.SizeOfGpModi +
        res.SizeOfSC +
        res.SizeOfSecMap + 
        res.SizeOfFileInfo +
        res.SizeOfTSMap +
        res.SizeOfDbgHdr +
        res.SizeOfECInfo;

print("Calc vs Actual: ", calcSize, bs.size)

    -- Read in GModi substream
    -- Read in Section contribution substream
    -- Read in Section Map substream
    -- Read in FileInfo
    -- Read in TSM substream
    -- Read in EC substream
    -- Read in Debug Header substream
    
    return res;
end

return {
    read = readStream;
    printLua = printInfo; 
}

