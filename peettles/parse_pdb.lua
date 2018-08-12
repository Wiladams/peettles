local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;
local lshift = bit.lshift;

local binstream = require("peettles.binstream")

local SigSize_PDB7 = 0x20;

-- calculate a number of pages given a size
-- and an alignment amount
local function calcAligned(num, alignment)
    return (num + alignment) / alignment
end

-- Right now, only deal with version 7 .pdb files
local function readFileHeader(ms, res)
    res = res or {}
    local bytes = ms:readBytes(SigSize_PDB7)
    res.Signature = bytes;
    res.SignatureString = ffi.string(bytes, SigSize_PDB7)
    res.BytesPerPage = ms:readDWORD();
    res.FlagsPage = ms:readDWORD();
    res.FilePages = ms:readDWORD();
    res.BytesInStream = ms:readDWORD();
    res.NumberOfPages = calcAligned(res.BytesInStream, res.BytesPerPage);

    ms:skip(2)

    return res;
end

local function parse_pdb(ms, res)
    res = res or {}
    readFileHeader(ms, res)

    return res;
end


return parse_pdb
