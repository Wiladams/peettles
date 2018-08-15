--[[
Decode Windows Program DataBase files (.pdb).
These files typically contain debug information for a program.

References
    In root README.md file
]]

local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;
local lshift = bit.lshift;
local math = require("math")

local binstream = require("peettles.binstream")
local pdbenums = require("peettles.pdb_enums")

local SigSize_PDB2 = 0x2C;  -- "Microsoft C/C++ program database 2.00\r\n\032JG\0\0"

-- signature, including first terminating null is up to 0x1e
-- then there are two more nulls after that, bringing the
-- total size of the field to 0x20
local SigSize_PDB7 = 0x20;  -- "Microsoft C/C++ MSF 7.00\r\n\x1ADS\0\0\0"



-- A couple of utilities
-- calculate a number of pages given a size
-- and an alignment amount
local function calcNumberOfBlocks(numBytes, alignment)
    return math.ceil(numBytes/alignment)
end

local function calcPageForOffset(numBytes, alignment)
    return math.floor(numBytes / alignment)
end

-- Read 'numEntries' worth of continguous uint32_t records
local function readDWORDArray(ms, numEntries, res)
    res = res or {}

    for counter=1,numEntries do
        local index = ms:readUInt32();
        table.insert(res, index);
    end

    return res;
end

local streamNames = {
	[0] = "Root";
	"PDB";
	"TPI";
	"DBI";
	"NameMap";
}

--[[
    The root stream is the top level stream that gives
    us information such as the number of other streams,
    their sizes, and block locations.

    The root stream is itself a collection of blocks,
    although there is typically only a single block.

    For now we assume that single block, but really 
    the number is determined by hdr.NumberOfBlocks 
]]
local function readRootStream(ms, hdr, res)
    res = res or {}
    


    local firstPageIdx = hdr.BlockMap[1]
--print("  firstPageIdx: ", string.format("0x%X",firstPageIdx))
    ms:seek(firstPageIdx * hdr.BlockSize)


    res.NumberOfStreams = ms:readDWORD();
--print("  NUM STREAMS: ", res.NumberOfStreams)
    res.Streams = {}

    -- Get the stream lengths, and calculate block counts
    for counter = 1,res.NumberOfStreams do 
        local strmLength = ms:readDWORD();
        local numBlocks = calcNumberOfBlocks(strmLength, hdr.BlockSize);
--print(" STREAM LENGTH: ", counter, strmLength, numBlocks)
        --table.insert(res.Streams, {StreamLength = strmLength, NumberOfBlocks = numBlocks})
        local name = streamNames[counter-1]
        --print("NAME: ", name)
        if not name then
            name = tostring(counter-1)
        end

        res.Streams[counter-1] = {
            StreamLength = strmLength; 
            NumberOfBlocks = numBlocks;
            Name = name;
        };
    end

    -- Now that we have stream lengths and block counts
    -- Read in the BlockMap for each stream
    for counter = 1,res.NumberOfStreams do
        local strm = res.Streams[counter-1]; 
        strm.BlockMap = readDWORDArray(ms, strm.NumberOfBlocks)
    end

    return res;
end


local function readBlockMap(ms, hdr, res)
    res = res or {}
    local fileOffset = hdr.BlockMapAddress * hdr.BlockSize
    ms:seek(fileOffset)

    readDWORDArray(ms, hdr.NumberOfBlocks, res)

    return res;
end

-- The .pdb file begins with a 'superblock'
-- which is essentially a 'root' directory to
-- this 'file system'.  By reading this, we can
-- then recompose the rest of the streams
local function readSuperBlock(ms, res)
    res = res or {}
 
    -- File Header
    res.Signature = ms:readBytes(SigSize_PDB7);
    res.BlockSize = ms:readDWORD();
    res.FreeBlockMapBlock = ms:readDWORD();
    res.NumBlocksInFile = ms:readDWORD();

    -- Superblock header
    res.StreamLength = ms:readDWORD();
    res.mpspnpn = ms:readDWORD();           -- unknown what this is for
    res.BlockMapAddress = ms:readUInt32();  -- Index (block number) of block map

    -- Calculated fields
    res.SignatureString = ffi.string(res.Signature,24)
    res.NumberOfBlocks = calcNumberOfBlocks(res.StreamLength, res.BlockSize);
    res.FileSize = res.NumBlocksInFile * res.BlockSize;

    -- The BlockMap tells us where the pages are
    -- that comprise the actual directory structure
    -- it can be located anywhere in the file
    res.BlockMap = readBlockMap(ms, res)

    return res;
end

local function parse_pdb(ms, res)
    res = res or {}
    local hdr = readSuperBlock(ms, res)
    local rootStream = readRootStream(ms, hdr, hdr)

    return res;
end


return parse_pdb
