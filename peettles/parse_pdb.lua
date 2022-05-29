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
-- indexed from 0
local function readDWORDArray(ms, numEntries, res)
    res = res or {}

    for counter=1,numEntries do
        local index = ms:readUInt32();
        res[counter-1] = index;
        --table.insert(res, index);
    end

    return res;
end

local streamNames = {
	[0] = "Root";
	[1] = "PDB";
	[2] = "TPI";
	[3] = "DBI";
	[4] = "NameMap";
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
local function readRootDirectory(ms, info, res)
    res = res or {}
    

    local firstPageIdx = info.BlockMap[0]
    ms:seek(firstPageIdx * info.BlockSize)

    -- Read number of streams
    res.NumberOfStreams = ms:readDWORD();
    -- table to hold actual stream information
    res.Streams = {}
print("Number of streams: ", res.NumberOfStreams)
--[[
    -- Get individual stream meta data
    for counter = 1,res.NumberOfStreams do 
        local strmLength = ms:readDWORD();
        local numBlocks = calcNumberOfBlocks(strmLength, info.BlockSize);

print(" STREAM LENGTH: ", counter, strmLength, numBlocks)
        --table.insert(res.Streams, {StreamLength = strmLength, NumberOfBlocks = numBlocks})
        local name = streamNames[counter-1]
        --print("NAME: ", name)
        if not name then
            name = tostring(counter-1)
        end

        res.Streams[counter-1] = {
            Index = counter-1;
            Name = name;
            StreamLength = strmLength; 
            NumberOfBlocks = numBlocks;
        };

    end

    -- Now that we have stream lengths and block counts
    -- Read in the BlockMap for each stream
    for counter = 1,res.NumberOfStreams do
        local strm = res.Streams[counter-1]; 
        strm.BlockMap = {}
        local success, err = readDWORDArray(ms, strm.NumberOfBlocks, strm.BlockMap);
    end
--]]
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
    res.NumBlocksInFile = ms:readDWORD();         -- Number of blocks in file

    -- Calculated fields
    res.SignatureString = ffi.string(res.Signature,24)
    res.FileSize = res.NumBlocksInFile * res.BlockSize;

    --print("Signature: ", res.Signature)
    -- print("SignatureString: ", res.SignatureString)
    --print("BlockSize: ", res.BlockSize)
    --print("FreeBlockMapBlock: ", res.FreeBlockMapBlock)
    --print("NumBlocksInFile: ", res.NumBlocksInFile)
    --print("FILE SIZE:" , res.FileSize)

    -- Superblock header
    res.NumDirectoryBytes = ms:readDWORD(); -- Size of the stream directory 
    res.mpspnpn = ms:readDWORD();           -- unknown what this is for
    res.BlockMapAddress = ms:readUInt32();  -- Index (block number) of block map
    res.NumBlockMapBlocks = math.ceil(res.NumDirectoryBytes / res.BlockSize);

    print("NumDirectoryBytes: ", res.NumDirectoryBytes)
    --print("mpspnpn: ", res.mpspnpn)
    --print("BlockMapAddress: ", string.format("0x%x",res.BlockMapAddress))
    print("NumBlockMapBlocks: ", res.NumBlockMapBlocks)

    -- Read the BlockMap, so we can later read the actual
    -- stream directory
    res.BlockMap = {}

    local fileOffset = res.BlockMapAddress * res.BlockSize
    ms:seek(fileOffset)

    readDWORDArray(ms, res.NumBlockMapBlocks, res.BlockMap);

    print("BlockMap[0]: ", res.BlockMap[0])
    print("BlockMap[1]: ", res.BlockMap[1])

    return res;
end

local function parse_pdb(ms, res)
    res = res or {}
    res.Header = {}
    local success, err = readSuperBlock(ms, res.Header)

    res.Directory = {}
    local success, err = readRootDirectory(ms, res.Header, res.Directory)

    return res;
end


return parse_pdb
