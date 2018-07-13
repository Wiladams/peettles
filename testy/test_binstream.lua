package.path = package.path..";../?.lua"

local ffi = require("ffi")

local binstream = require("peettles.binstream")

local byteSize = 256;
local bytes = ffi.new("uint8_t[?]", byteSize)
for i=0, byteSize-1 do
    bytes[i] = i;
end

local bs = binstream(bytes, byteSize, 0, true)

local rs = bs:range(10,10)
print("RS Big Endian: ", rs.bigend)
for i=1,10 do
    print("Range: ", rs:readOctet())
end
