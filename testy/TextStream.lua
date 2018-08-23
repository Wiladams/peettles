--[[

-- A string class that does not own its contents.
-- This class provides a few utility functions for string manipulations.
class String {

  std::string str() const { return {p, p + len}; }

  bool empty() const { return len == 0; }

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
    __index = TextStream
}

function TextStream.init(self, data, len)
    local obj = {
        Stream = OctetStream(data, len);
    }
    setmetatable(obj, TextStream_mt);

    return obj
end

function TextStream.new(self, ...)
    return self:init(...)
end

function TextStream.startsWithDigit(self)
    return self.OStream.size > 0 and
        self.OStream.data[0] >= string.byte('0') and
        self.OStream.data[0] <= string.byte('9')
end

function TextStream.startsWithChar(self, ch)
    return self.OStream.size>0 and self.OStream.data[0] == string.byte(ch)
end

function TextStream.startsWithString(self, str)
    -- compare character by character
    local strPtr = ffi.cast("const char *", str)
    local len = #str

    return false;
end

function TextStream.get(self)
    if self.OStream:isEOF() then
        return false, "EOF";
    end

    return self.OStream:readOctet();
end

function TextStream.unget(self)
    return self.OStream:seek(self.OStream:tell()-1)
end

function TextStream.trim(self, n)
    return self.OStream:skip(n)
end

return TextStream
