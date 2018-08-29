--[[

-- A string class that does not own its contents.
-- This class provides a few utility functions for string manipulations.
class String {
  String substr(size_t off) const { return {p + off, len - off}; }
  String substr(size_t off, size_t length) const { return {p + off, length}; }

  bool operator==(const String s) const {
    return len == s.len && memcmp(p, s.p, len) == 0;
  }

};

std::ostream &operator<<(std::ostream &os, const String s) {
  os.write(s.p, s.len);
  return os;
}
--]]
local ffi = require("ffi")
local OctetStream = require("peettles.octetstream")

local t_0 = string.byte('0')
local t_9 = string.byte('9')

local function isdigit(c)
	return c >= t_0 and c <= t_9
end


local TextStream = {}
setmetatable(TextStream, {
    __call = function(self, ...)
    return self:new(...)
end,
})

local TextStream_mt = {
    __index = TextStream;

    __len = function(self) return self:length() end;
}

function TextStream.init(self, data, len)
    local obj = {
        Stream = OctetStream(data, len);
    }
    setmetatable(obj, TextStream_mt);

    return obj
end

function TextStream.new(self, str)
    return self:init(str, #str)
end

function TextStream.isEqual(self, rhs)
    return self:startsWith(rhs)
end

function TextStream.length(self)
    return self.Stream:remaining();
end

-- Create an unassociated copy of this stream
-- Like a copy constructor from current position
function TextStream.clone(self)
    return TextStream(self:str())
end

-- turn the whole stream into a string
function TextStream.str(self)
    if self.Stream:remaining() == 0 then
        return nil;
    end

    return ffi.string(self.Stream:getPositionPointer(), self.Stream:remaining());
end




function TextStream.peek(self, offset)
    return self.Stream:peekOctet(offset);
end

function TextStream.peekDigit(self, office)
    local abyte, err = self.Stream:peekOctet(offset)
    if abyte then
        return abyte - string.byte('0');
    end

    return false, "character not peek'd"
end

function TextStream.get(self)
    if self.Stream:isEOF() then
        return false, "EOF";
    end

    return self.Stream:readOctet();
end

function TextStream.unget(self, achar)
    return self.Stream:seek(self.Stream:tell()-1)
end

function TextStream.trim(self, n)
    return self.Stream:skip(n)
end

function TextStream.substr(self, offset, len)
    return ffi.string(self.Stream:getPositionPointer()+offset, len);
end

function TextStream.startsWithDigit(self)
    if self.Stream:isEOF() then return false end

    return isdigit(self.Stream:peekOctet())
end

function TextStream.startsWithChar(self, ch)
    if self.Stream:isEOF() then return false end

    return self.Stream:peekOctet() == string.byte(ch)
end

function TextStream.startsWith(self, str)

    if self.Stream:isEOF() then return false end
    if self.Stream:remaining() < #str then return false; end

    -- compare character by character
    local len = #str
    local strPtr = ffi.cast("const char *", str)
    
    local dstPtr = self.Stream:getPositionPointer();

    for i=0, len-1 do 
        if dstPtr[i] ~= strPtr[i] then 
            return false;
        end
    end

    return true;
end


return TextStream
