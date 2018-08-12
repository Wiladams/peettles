package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")


local enum = require("peettles.enum")
local peenums = require("peettles.penums")
local mmap = require("peettles.mmap_win32")
local binstream = require("peettles.binstream")
local putils = require("peettles.print_utils")
local parse_pdb = require("peettles.parse_pdb")

local StorageClass = peenums.SymStorageClass;


local filename = arg[1];

if not filename then
	print("NO FILE SPECIFIED")
    return
end

local function printpdb(res)
    print(res.SignatureString)
    print(string.format("  BlockSize = 0x%X;", res.BlockSize));
    print(string.format("  FreeBlockMapBlock = 0x%X;", res.FreeBlockMapBlock));
    print(string.format("  NumBlocksInFile = 0x%X;", res.NumBlocksInFile));
    print(string.format("  NumDirectoryBytes = 0x%X;", res.NumDirectoryBytes));
	print(string.format("  NumberOfBlocks = 0x%X;", res.NumberOfBlocks));
	print(string.format("  BlockMapAddress = 0x%X;", res.BlockMapAddress));
	print(string.format("  FileSize = 0x%x;", res.FileSize))
	print("  BlockMap = {")
	for idx, blockNum in ipairs(res.BlockMap) do 
		print(string.format("    0x%04X;", blockNum))
	end
	print("  };")
end

function main(filename)
	local mfile = mmap(filename);
	if not mfile then 
		print("Error trying to map: ", filename)
	end

    local bs = binstream(mfile:getPointer(), mfile.size, 0, true)

	local info, err = parse_pdb(bs);
	if not info then
		print("ERROR: fromData - ", err)
		return
	end

    printpdb(info);
end


main(filename)