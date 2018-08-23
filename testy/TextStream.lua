--[[

-- A string class that does not own its contents.
-- This class provides a few utility functions for string manipulations.
class String {

  std::string str() const { return {p, p + len}; }

  bool startswith(const std::string &s) const {
    return s.size() <= len && strncmp(p, s.data(), s.size()) == 0;
  }


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

local OctetStream = require("peettles.octetstream")

local TextStream = {}
setmetatable(TextStream, {
    __call = function(self, ...)
    return self:new(...)
end,
})

local TextStream_mt = {

    __index = TextStream;
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

function TextStream.toString(self)
    if self.size == 0 then
        return nil;
    end

    return ffi.string(self.data, self.size);
end

function TextStream.empty(self)
    return self.size == 0;
end

function TextStream.startsWithDigit(self)
    return self.Stream.size > 0 and
        self.Stream.data[0] >= string.byte('0') and
        self.Stream.data[0] <= string.byte('9')
end

function TextStream.startsWithChar(self, ch)
    return self.Stream.size>0 and self.Stream.data[0] == string.byte(ch)
end

function TextStream.startsWithString(self, str)
    -- compare character by character
    local strPtr = ffi.cast("const char *", str)
    local len = #str

    return false;
end

function TextStream.get(self)
    if self.Stream:isEOF() then
        return false, "EOF";
    end

    return string.char(self.Stream:readOctet());
end

function TextStream.unget(self, achar)
    return self.Stream:seek(self.Stream:tell()-1)
end

function TextStream.trim(self, n)
    return self.Stream:skip(n)
end

return TextStream
