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

local streamNames = {
	[0] = "Old Directory (0)";
	"PDB (1)";
	"Type Info (2)";
	"Directory (3)";
	"Type Info (4)";


}

local function printpdb(res)

    print(string.format("  Version = '%s';", res.SignatureString));
    print(string.format("  BlockSize = 0x%X;", res.BlockSize));
    print(string.format("  FreeBlockMapBlock = 0x%X;", res.FreeBlockMapBlock));
    print(string.format("  NumBlocksInFile = 0x%X;", res.NumBlocksInFile));
    print(string.format("  NumDirectoryBytes = 0x%X;", res.StreamLength));
	print(string.format("  NumberOfBlocks = 0x%X;", res.NumberOfBlocks));
	print(string.format("  BlockMapAddress = 0x%X;", res.BlockMapAddress));
	print(string.format("  FileSize = 0x%x;", res.FileSize))
	print("  BlockMap = {")
	for idx, blockNum in ipairs(res.BlockMap) do 
		print(string.format("    0x%04X;", blockNum))
	end
	print("  };")
	print("  StreamCount = ", string.format("%d;", res.NumberOfStreams))
	print("  Streams = {")
	for idx=0, res.NumberOfStreams-1  do
		local strm = res.Streams[idx];
		print(string.format("    [%d] = {\n      StreamLength = 0x%x; \n      NumberOfBlocks=%d;",
			idx, strm.StreamLength, strm.NumberOfBlocks))
		print(string.format("      Name = '%s';", streamNames[idx] or "UNKNOWN"));
		print("      BlockMap = {")
		for idx, blockNum in ipairs(strm.BlockMap) do 
			print(string.format("        0x%04X;", blockNum))
		end
		print("    };")
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