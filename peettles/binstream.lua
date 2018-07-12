--[[
    This file is a general memory stream interface.
    The primary objective is to satisfy the needs of the 
    truetype parser, but it can be used in general cases.

    It differs from the MemoryStream object in that it can't
    write, and it has more specific data type reading 
    convenience calls.

    More specifically, all of the numeric reading assumes the
    data in the stream is formatted in 'big-endian' order.  That
    is, the high order bytes come first.
]]
local ffi = require("ffi")
local bit = require("bit")
local bor, lshift = bit.bor, bit.lshift
local min = math.min

--[[
    Standard 'object' construct.
    __call is implemented so we get a 'constructor'
    sort of feel:
    binstream(data, size, position)
]]
local binstream = {
    bigend = true;
}
setmetatable(binstream, {
		__call = function(self, ...)
		return self:new(...)
	end,
})

local binstream_mt = {
	__index = binstream;
}


function binstream.init(self, data, size, position, littleendian)
    position = position or 0
--print("SIZE: ", data, size, position, littleendian)
    assert(size > 0);

    local obj = {
        bigend = not littleendian;
        data = ffi.cast("uint8_t *", data);
        size = size;
        cursor = position;
    }
 
    setmetatable(obj, binstream_mt)
    return obj
end

function binstream.new(self, data, size, position, littleendian)
    return self:init(data, size, position, littleendian);
end

-- report how many bytes remain to be read
-- from stream
function binstream.remaining(self)
    return tonumber(self.size - self.cursor)
end

 -- move to a particular position, in bytes
function binstream.seek(self, pos)
    -- if position specified outside of range
    -- just set it past end of stream
    if (pos > self.size)  or (pos < 0) then
        self.cursor = self.size
        return false, self.cursor;
    else
        self.cursor = pos;
    end
 
    return true;
end


-- Report the current cursor position.
function binstream.tell(self)
    return self.cursor;
end


-- move the cursor ahead by the amount
-- specified in the offset
-- seek, relative to current position
function binstream.skip(self, offset)
    --print("SKIP: ", offset)
     return self:seek(self.cursor + offset);
end



--[[
function binstream.skipToEven(self)
    self:skip(self.cursor % 2);
end
--]]

-- get 8 bits, and don't advance the cursor
function binstream.peek8(self)
    if (self.cursor >= self.size) then
        return false;
    end

    return self.data[self.cursor];
end



-- get 8 bits, and advance the cursor
function binstream.read8(self)
    --print("self.cursor: ", self.cursor, self.size)
    if (self.cursor >= self.size) then
       return false, "EOF";
    end

    self.cursor = self.cursor + 1;
    
    return self.data[self.cursor-1]
 end
 
-- get as many bytes specified in n as an integer
 -- this could possibly work up to 7 byte integers
 -- converts from big endian to native format while it goes
function binstream.read(self, n)
    local v = 0;
    local i = 0;

    if self:remaining() < n then
        return false, "NOT ENOUGH DATA AVAILABLE"
    end

    if self.bigend then
        while  (i < n) do
            v = bor(lshift(v, 8), self:read8());
            i = i + 1;
        end 
    else
        while  (i < n) do
            v = bor(v, lshift(self:read8(), 8*i));
            i = i + 1;
        end 
    end

    return v;
end

function binstream.readNumber(self, n)
    return tonumber(self:read(n));
end

-- BUGBUG, do error checking against end of stream
function binstream.readBytes(self, n, bytes)
    if n < 1 then return false, "must specify more then 0 bytes" end

    -- see how many bytes are remaining to be read
    local nActual = min(n, self:remaining())

    -- read the minimum between remaining and 'n'
    bytes = bytes or ffi.new("uint8_t[?]", nActual)
    ffi.copy(bytes, self.data+self.cursor, nActual)
    self:skip(n)

    -- if minimum is less than n, return false, and the number
    -- actually read
    if nActual < n then
        return false, nActual;
    end

    return bytes;
end

-- Read a null terminated ASCIIZ string
-- do not read more than 'n' bytes
-- advance the cursor by actual bytes read
function binstream.readASCIIZ(self, n)
    n = n or 0
    if n < 1 then return ; end
    local bytes = ffi.new("uint8_t[?]", n+1)

    for i=1,n do
        local byte = self:read8();
        bytes[i-1] = byte

        if byte == 0 then break end
    end
    return ffi.string(bytes)
end


function binstream.readString(self, n)
    local str = nil;
    if not n then
        str = ffi.string(self.data+self.cursor)
        self.cursor = self.cursor + #str + 1;
    else
        str = ffi.string(self.data+self.cursor, n)
        self.cursor = self.cursor + n;
    end

    return str;
end

function binstream.read16(self)  
     return self:read(2)
end

function binstream.read32(self)  
    return tonumber(self:read(4))
end

-- These ensure the sign is dealth with properly
function binstream.readInt8(self)
    return tonumber(ffi.cast('int8_t', self:read(1)))
end

function binstream.readUInt8(self)
    return tonumber(ffi.cast('uint8_t', self:read(1)))
end

function binstream.readInt16(self)
    return tonumber(ffi.cast('int16_t', self:read(2)))
end

function binstream.readUInt16(self)
    return tonumber(ffi.cast('uint16_t', self:read(2)))
end



function binstream.readInt32(self)
    return tonumber(ffi.cast('int32_t', self:read(4)))
end

function binstream.readUInt32(self)
    return tonumber(ffi.cast('uint32_t', self:read(4)))
end

function binstream.readInt64(self)
    return tonumber(ffi.cast('int64_t', self:read(8)))
end

function binstream.readUInt64(self)
    local v = 0ULL;
    --ffi.cast("uint64_t", 0);
    local i = 0;
--print("==== readUInt64 ====")
    if self.bigend then
        while  (i < 8) do
            v = bor(lshift(v, 8), self:read8());
            i = i + 1;
        end 
    else
        --print("LITTLE")
        while  (i < 8) do
            local byte = ffi.cast("uint64_t",self:read8());
            local shifted = lshift(byte, 8*i)
            --v = v + shifted
            v = bor(v, lshift(byte, 8*i));
            --print(v)
            i = i + 1;
        end 
    end

    return v;

    --return ffi.cast('uint64_t', self:read(8))
end


function binstream.readFixed(self)
    local decimal = self:readInt16();
    local fraction = self:readUInt16();

    return decimal + fraction / 65535;
end

function binstream.readF2Dot14(self)
    return self:readInt16() / 16384;
end

-- get a subrange of the memory stream
-- returning a new memory stream
function binstream.range(self, size, pos)
    pos = pos or self.cursor;

    if ((pos < 0) or (size < 0) or (pos > self.size) or (size > (self.size - pos))) then 
        return false;
    end

    return binstream(self.data+pos, size, 0 , not self.bigend)
end

-- Convenient types named in the documentation
binstream.readFWord = binstream.readInt16;
binstream.readUFWord = binstream.readUInt16;
binstream.readOffset16 = binstream.readUInt16;
binstream.readOffset32 = binstream.readUInt32;

return binstream