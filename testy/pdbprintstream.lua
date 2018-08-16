package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")


local mmap = require("peettles.mmap_win32")
local win32 = require("peettles.w32")

local binstream = require("peettles.binstream")
local readStream = require("peettles.parse_pdb_1")

if not arg[1] or not arg[2] then
    print("USAGE:  pdb_read_strm.lua <number> filename")
    return false;
end

local filename = arg[1];
local streamNumber = tonumber(arg[2]);


local streamParsers = {
    [1] = require("peettles.parse_pdb_1");
    [3] = require("peettles.parse_pdb_3");
}

--[[
    print("stream1 = {")
    print("  Version = ", string.format("%d;",info.Version));
    print("  TimeDateStamp = ", string.format("0x%X;",info.TimeDateStamp));
    print("  Age = ", string.format("%d;",info.Age));
    print("  GUID = ", info.GUID);
    print("  NamesLength = ", string.format("%d;",info.NamesLength));
    print("  Names = {")
    for _, name in ipairs(info.Names) do
        print("  ", name)
    end
    print("  };")
    print("};")
--]]

local function printInfo(info)
    for k,v in pairs(info) do
        print(k,v)
    end

end




function main(filename)

	local mfile = mmap(filename);
	if not mfile then 
		print("Error trying to map: ", filename)
	end

    local bs = binstream(mfile:getPointer(), mfile.size, 0, true)

    local parser = streamParsers[streamNumber].read;
    if not parser then
        print("NO PARSER FOR: ", streamNumber)
        return false;
    end

    local info, err = parser(bs)

	if not info then
		print("ERROR: fromData - ", err)
		return
	end

    if streamParsers[streamNumber].printLua then
        streamParsers[streamNumber].printLua(info)
    else
        printInfo(info);
    end
end

main(filename)