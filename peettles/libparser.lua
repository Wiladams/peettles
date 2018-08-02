--[[
    .lib file format reader.

    References
    https://docs.microsoft.com/en-us/windows/desktop/Debug/pe-format#archive-library-file-format
]]
local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")
local parse_COFF = require("peettles.parse_COFF")

local isspace = putils.isspace;


local function trim(s)
    return s:match "^%s*(.-)%s*$"
end

local parser = {}
setmetatable(parser, {
    __call = function(self, ...)
        return self:create(...)
    end;
})
local parser_mt = {
    __index = parser;
}

function parser.init(self, obj)
    obj = obj or {}

    setmetatable(obj, parser_mt)

    return obj;
end

function parser.create(self, obj)
    return self:init(obj)
end

function parser.fromData(self, data, size)
    local bs = binstream(data, size, 0, true);
    local obj = self:create()
    return obj:parse(bs)
end

local LibrarySignature = "!<arch>"
local DefaultTerminator = '\n'

local function readLibrarySignature(bs, res)
    res = res or {}

    -- read signature
    local sigbytes = bs:readBytes(8);
    local sig = ffi.string(sigbytes,7)
    if sig ~= LibrarySignature then
        return false, sig
    end
    res.Signature = sig;

    return res;
end


-- This will need to deal with both null
-- terminated, as well as space appended strings
-- first traverse the buffer backwards looking for nulls
-- then remove whitespace
local function readTrimmedString(bs, size)
    local truelen = size
    local bytes = bs:readBytes(size)

	for i=size-1,0,-1 do
		if bytes[i] == 0 or isspace(bytes[i]) then
		    truelen = i;
		end
	end
    local str = ffi.string(bytes, truelen);

    return str;
end

local function readArchiveMemberHeader(bs, res)
    if bs:remaining() < 60 then return false, "EOF" end

    res = res or {}
    -- This header part should be 60 bytes long
    -- for all archive members
    res.HeaderOffset = bs:tell();
    res.Identifier = readTrimmedString(bs, 16);
    res.DateTime = readTrimmedString(bs, 12); -- trim(ffi.string(bs:readBytes(12),12));
    res.OwnerID = readTrimmedString(bs, 6); -- ffi.string(bs:readBytes(6),6);
    res.GroupID = readTrimmedString(bs, 6); -- ffi.string(bs:readBytes(6),6);
    res.Mode = readTrimmedString(bs, 8);  -- ffi.string(bs:readBytes(8),8);
    res.Size = tonumber(readTrimmedString(bs, 10));
--print("      Size: ", res.Size)
    res.EndChar = bs:readBytes(2);

--print("Name: ", res.Name)
--print("  DateTime: ", res.DateTime)
    -- If the archive member name ~= '/' or '//' or something else
    -- then it's probably a COFF section

    return res;
end

--[[
    0   4           Number Of Symbols, unsigned long bigendian
    4   4 * n       Offsets, unsigned long bigendian
    *   *           String Table.  Series of null terminated strings
]]
local function readFirstLinkMember(bs, res)
    res = res or {}
    bs:skipToEven();
    local member, err = readArchiveMember(bs, res);

    return res;
end

local function readSecondLinkMember(bs, res)
    res = res or {}
    bs:skipToEven();
    local member, err = readArchiveMember(bs, res);

    return res;
end



    -- [8]  file signature
    -- PACKAGE
    -- [16] file identifier
    -- [12] file modification timestamp
    -- [6] owner ID
    -- [6] group ID
    -- [8] file mode
    -- [10] file size in bytes
    -- [2]  end char
    -- [4]  version
    -- CONTROL
    -- [16] file identifier
    -- [12] file modification timestamp
    -- [6] owner ID
    -- [6] group ID
    -- [8] file mode
    -- [10] file size in bytes
    -- [2]  end char
    -- [file size] DATA
    -- DATA

function parser.parse(self, bs)
    local libsig, err = readLibrarySignature(bs, self)
    if not libsig then
        return false, err
    end

    self.Members = {}

        -- At this point, need to decide which of the 'ar' archive formats
    -- we're dealing with, Sys V/FreeBSD, or BSD
    -- there may be a long name right after the header
    --res.Data = bs:readBytes(res.Size);
    -- Read First Link Member
    -- Read Second Link Member
    self.Members.FirstLinkMember = readFirstLinkMember(bs);
    self.Members.SecondLinkMember = readSecondLinkMember(bs);

    while true do
        -- All members start on a two byte boundary, so 
        -- We make sure we're properly aligned before reading
        bs:skipToEven();
        local member, err = readArchiveMember(bs);
        if not member then
            break;
        end
        table.insert(self.Members, member);
    end

    return self
end


return parser