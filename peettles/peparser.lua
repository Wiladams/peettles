--[[
    PE file format reader.
    This reader will essentially 'decompress' all the information
    in the PE file, and make all relevant content available
    through a standard Lua table.

    Typical usage on a Windows platform would be:

    local mfile = mmap(filename);
	local peparser = peparser:fromData(mfile:getPointer(), mfile.size);

    Once the peparser object has been constructed, it will already 
    contain the contents in an easily navigable form.
]]
local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")

local parse_DOS = require("peettles.parse_DOS")
local parse_COFF = require("peettles.parse_COFF")



local peparser = {}
setmetatable(peparser, {
    __call = function(self, ...)
        return self:create(...)
    end;
})
local peparser_mt = {
    __index = peparser;
}

function peparser.init(self, obj)
    obj = obj or {}

    setmetatable(obj, peparser_mt)

    return obj;
end

function peparser.create(self, obj)
    return self:init(obj)
end

function peparser.fromData(self, data, size)
    local ms = binstream(data, size, 0, true);
    local obj = self:create()

    return obj:parse(ms)
end

--[[
    PE\0\0 - PE header
    NE\0\0 - 16-bit Windows New Executable
    LE\0\0 - Windows 3.x virtual device driver (VxD)
    LX\0\0 - OS/2 2.0
]]
local function IsPEFormatImageFile(sig)
    return sig[0] == string.byte('P') and
        sig[1] == string.byte('E') and
        sig[2] == 0 and
        sig[3] == 0
end

function peparser.parse(self, ms)
    self.SourceStream = ms;
    self._data = ms.data;
    self._size = ms.size;

    local err = false;
    self.DOS, err = parse_DOS(ms);

    if not self.DOS then 
        return false, err;
    end

    -- seek to the PE signature
    -- The stream should now be located at the 'PE' signature
    -- we assume we can only read Portable Executable
    -- anything else is an error

    ms:seek(self.DOS.DOSHeader.e_lfanew)
    
    -- We expect to see 'PE' as an indicator that what is
    -- to follow is in fact a PE file.  If not, we quit early
    local ntheadertype = ms:readBytes(4);
    if not IsPEFormatImageFile(ntheadertype) then
        return false, "not PE Format Image File"
    end

    self.Signature = ntheadertype;

    self.COFF, err = parse_COFF(ms);


    return self
end


return peparser