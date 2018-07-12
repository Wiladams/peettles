package.path = package.path..";../?.lua"

local ffi = require("ffi")
local putils = require("print_utils")

local mmap = require("peettles.mmap_win32")
local binstream = require("peettles.binstream")




local function main(filename)

    if not filename then
        return false, "NO FILE SPECIFIED"
    end
    
    local mfile = mmap(filename);

    if not mfile then 
        print("Error trying to map: ", filename)
        return false;
    end

    local ms = binstream(mfile:getPointer(), mfile.size)

    putils.printHex(ms, nil, 32, 256)
end

main(arg[1])
