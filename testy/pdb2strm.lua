package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")


local enum = require("peettles.enum")
local peenums = require("peettles.penums")
local mmap = require("peettles.mmap_win32")
local win32 = require("peettles.w32")

local binstream = require("peettles.binstream")
local parse_pdb = require("peettles.parse_pdb")

local filename = arg[1];

if not filename then
	print("NO FILE SPECIFIED")
    return
end

function writeStream(bs, info, strm, idx, dirname)
--    print(idx,  strm.NumberOfBlocks, info.BlockSize, strm.StreamLength)
    -- create file
    local filename = dirname..string.format("\\%d.dmp", idx)
    local hFile = win32.createFile(filename)
--print("FILE: ", idx, filename)
    -- write the blocks
    for _, blockNum in ipairs(strm.BlockMap) do 
        local buffPtr = bs.data + blockNum * info.BlockSize

        win32.writeFile(hFile, buffPtr, info.BlockSize)
    end

    -- close the file
    ffi.C.CloseHandle(hFile)
end

function decompose(bs, info, dirname)
    print("Number Of Streams: ", info.NumberOfStreams)
    for idx = 0, info.NumberOfStreams-1 do 
        local strm = info.Streams[idx];
        writeStream(bs, info, strm, idx, dirname)
    end
end

-- Split a file path into constituent parts
-- This works for very simple cases, just enough to prototype
-- Returns the Path, Filename, and Extension as 3 values
function SplitFilename(strFilename)
	return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
end

function main(filename)
    local path, fname, ext = SplitFilename(filename)

	local mfile = mmap(filename);
	if not mfile then 
		print("Error trying to map: ", filename)
	end

    local bs = binstream(mfile:getPointer(), mfile.size, 0, true)

    local dirname = fname.."_streams"
    local success, err = win32.createDirectory(dirname)
print("DIRECTORY: ", dirname)

	local info, err = parse_pdb(bs);
	if not info then
		print("ERROR: fromData - ", err)
		return
	end

    decompose(bs, info, dirname);
end

main(filename)