--[[
    An octet stream is simply a stream of 8-bit bytes.
    It could be associated with anything, but most typically
    it's going to be a pointer to some memory.


]]
local ffi = require("ffi")
local bit = require("bit")
local bor, lshift = bit.bor, bit.lshift
local min = math.min

--[[
    Standard 'object' construct.
    __call is implemented so we get a 'constructor'
    sort of feel:
    octetstream(data, size, position)
]]
local octetstream = {}
setmetatable(octetstream, {
		__call = function(self, ...)
		return self:new(...)
	end,
})

local octetstream_mt = {
	__index = octetstream;
}

function octetstream.init(self, data, size, position)
    position = position or 0
    assert(size > 0);

    local obj = {
        data = ffi.cast("uint8_t *", data);
        size = size;
        cursor = position;
    }
 
    setmetatable(obj, octetstream_mt)

    return obj
end

function octetstream.new(self, data, size, position)
    return self:init(data, size, position);
end

-- get a subrange of the memory stream
-- returning a new memory stream
function octetstream.range(self, size, pos)
    pos = pos or self.cursor;

    if pos < 0 or size < 0 then
        return false, "pos or size < 0"
    end

    if pos > self.size then
        return false, "pos > self.size"
    end

    if ((size > (self.size - pos))) then 
        return false, "size is greater than remainder";
    end

    return octetstream(self.data+pos, size, 0)
end

-- report how many bytes remain to be read
-- from stream
function octetstream.remaining(self)
    return tonumber(self.size - self.cursor)
end

function octetstream.isEOF(self)
    return self:remaining() < 1
end

function octetstream.canSeek(self)
    return true;
end

 -- move to a particular position, in bytes
function octetstream.seek(self, pos)
    -- if position specified outside of range
    -- just keep it where it is, and return false;
    if (pos > self.size)  or (pos < 0) then
        return false, self.cursor;
    end

    self.cursor = pos;
 
    return self;
end

-- Move past last octet in stream
function octetstream.seekToEnd(self)
    self.cursor = self.size;
    return self;
end

-- Report the current cursor position.
function octetstream.tell(self)
    return self.cursor;
end


-- move the cursor ahead by the amount
-- specified in the offset
-- seek, relative to current position
function octetstream.skip(self, offset)
     return self:seek(self.cursor + offset);
end

function octetstream.alignTo(self, num)
    self:skip(self.cursor % num)
end

-- Return a pointer to the current position
function octetstream.getPositionPointer(self)
    return self.data + self.cursor;
end

-- get 8 bits, and don't advance the cursor
function octetstream.peekOctet(self, offset)
    offset = offset or 0

    if (self.cursor+offset >= self.size or self.cursor+offset < 0) then
        return false;
    end

    return self.data[self.cursor+offset];
end

-- get 8 bits, and advance the cursor
function octetstream.readOctet(self)
    --print("self.cursor: ", self.cursor, self.size)
    if (self.cursor >= self.size) then
       return false, "EOF";
    end

    self.cursor = self.cursor + 1;
    
    return self.data[self.cursor-1]
 end

-- BUGBUG, do error checking against end of stream
function octetstream.readBytes(self, n, bytes)
    if n < 1 then 
        return false, "must specify more then 0 bytes" 
    end

    -- see how many bytes are remaining to be read
    local nActual = min(n, self:remaining())

    -- read the minimum between remaining and 'n'
    bytes = bytes or ffi.new("uint8_t[?]", nActual)
    ffi.copy(bytes, self.data+self.cursor, nActual)
    self:skip(nActual)

    -- if minimum is less than n, return false, and the number
    -- actually read
    if nActual < n then
        return false, nActual;
    end

    return bytes, nActual;
end





return octetstream