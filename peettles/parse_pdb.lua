--[[
Decode Program DataBase files from the Windows platform.
These files typically contain debug information for a program.

References
    https://github.com/Microsoft/microsoft-pdb/
    https://llvm.org/docs/PDB/MsfFile.html

]]

local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;
local lshift = bit.lshift;
local math = require("math")

local binstream = require("peettles.binstream")

local SigSize_PDB2 = 0x2C;  -- "Microsoft C/C++ program database 2.00\r\n\032JG\0\0"
local SigSize_PDB7 = 0x20;  -- "Microsoft C/C++ MSF 7.00\r\n\x1ADS\0\0\0"

ffi.cdef[[
typedef void *  PV;
typedef uint16_t    SN;     // stream number
typedef uint32_t    UNSN;   // unified stream number
typedef size_t     CB;     // size (count of bytes)
typedef size_t     OFF;    // offset
]]

-- calculate a number of pages given a size
-- and an alignment amount
local function calcAlignedPages(num, alignment)
    --return math.floor((num + alignment) / alignment)
    return math.ceil(num/alignment)
end

local function calcPageForOffset(num, alignment)
    return math.floor(num / alignment)
end

-- Right now, only deal with version 7 .pdb files
local function readBlockMap(ms, hdr, res)
    res = res or {}
    local fileOffset = hdr.BlockMapAddress * hdr.BlockSize
    for counter=1,hdr.NumberOfBlocks do
        local index = ms:readUInt32();
        table.insert(res, index);
    end

    return res;
end


local function readSuperBlock(ms, res)
    res = res or {}
    local bytes = ms:readBytes(SigSize_PDB7)
    res.Signature = bytes;
    res.SignatureString = ffi.string(bytes)

    res.BlockSize = ms:readDWORD();
    res.FreeBlockMapBlock = ms:readDWORD();
    res.NumBlocksInFile = ms:readDWORD();
    res.NumDirectoryBytes = ms:readDWORD();
    res.Unknown = ms:readBytes(4)
    res.BlockMapAddress = ms:readUInt32();

    -- Calculated fields
    res.NumberOfBlocks = calcAlignedPages(res.NumDirectoryBytes, res.BlockSize);
    res.FileSize = res.NumBlocksInFile * res.BlockSize;

    res.BlockMap = readBlockMap(ms, res)

    return res;
end

local function parse_pdb(ms, res)
    res = res or {}
    readSuperBlock(ms, res)

    return res;
end


return parse_pdb
