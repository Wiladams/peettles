package.path = package.path..";../?.lua"

local ffi = require("ffi")
local putils = require("peettles.print_utils")

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

    putils.printHex {stream = ms, offsetbits = 32, iterations = 256}
end

print(main(arg[1]))
