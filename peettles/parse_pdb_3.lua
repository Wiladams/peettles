-- Read PDB stream 3 (DBI Info)
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
    print("  Signature = ", string.format("0x%X;",info.Signature))
    print("  Version = ", DBIVersions[info.Version])
end

--[[
    SN  uint16_t

    Follows structure:
        NewDBIHdr
    Consult dbi.cpp
        BOOL DBI1::fInit(BOOL fCreate)
]]
local function readStream(bs, res)
    res = res or {}

    res.Signature = bs:readUInt32();
    res.Version = bs:readUInt32();
    res.Age = bs:readUInt32();
    
    res.snGSSyms = bs:readUInt16();



    bs:seek(0x3A);
    res.Machine = bs:readUInt16();
    res.Reserved1 = bs:readUInt32();


    return res;
end

return {
    read = readStream;
    printLua = printInfo; 
}

