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
    print(string.format("  BytesPerPage = 0x%X;", res.BytesPerPage));
    print(string.format("  FlagsPage = 0x%X;", res.FlagsPage));
    print(string.format("  FilePages = 0x%X;", res.FilePages));
    print(string.format("  BytesInStream = 0x%X;", res.BytesInStream));
    print(string.format("  NumberOfPages = 0x%X;", res.NumberOfPages));
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