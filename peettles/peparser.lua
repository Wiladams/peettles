--[[
    PE file format reader.
    This reader will essentially 'decompress' all the information
    in the PE file, and make all relevant content available
    through a standard Lua table.

    Typical usage on a Windows platform would be:

    local mfile = mmap(filename);
	local peinfo = peparser:fromData(mfile:getPointer(), mfile.size);

    or
    local bs = binstream(mfile:getPointer(), mfile.size, 0, true);
    local peinfo = peparser:fromStream(bs);


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
local parse_PE = require("peettles.parse_PE")


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

function peparser.fromStream(self, bs)
    local obj = self:create();

    return obj:parse(bs);
end

function peparser.fromData(self, data, size)
    local ms = binstream(data, size, 0, true);
    return self:fromStream(ms);
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

function peparser.parse(self, ms, res)
    local res = res or {}
    res.SourceStream = ms;
    res._data = ms.data;
    res._size = ms.size;

    local err = false;
    res.DOS = {}
    local success, err = parse_DOS(ms, res.DOS);

    -- If we did not find a DOS header, then we are not a PE file.
    if not success then 
        return false, err, res;
    end

    -- seek to the PE signature
    ms:seek(res.DOS.DOSHeader.e_lfanew)
    
    res.PE = {}
    success, err = parse_PE(ms, res.PE);

    -- If we did not successfully parse the PE file
    -- return error, and whatever we did manage to parse
    if not success then 
        return false, err, res;
    end


    return res
end


return peparser