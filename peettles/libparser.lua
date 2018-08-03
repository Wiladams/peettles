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
-- traverse the buffer backwards looking for nulls or whitespace
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
    res.DateTime = readTrimmedString(bs, 12); 
    res.OwnerID = readTrimmedString(bs, 6); 
    res.GroupID = readTrimmedString(bs, 6);
    res.Mode = readTrimmedString(bs, 8);
    res.Size = tonumber(readTrimmedString(bs, 10));
    res.EndChar = bs:readBytes(2);

--[[
print("Name: ", res.Identifier)
print("  Header Offset: ", res.HeaderOffset)
--print("  DateTime: ", res.DateTime)
print("  Size: ", res.Size)
print(string.format("  End: 0x%x,0x%x", res.EndChar[0], res.EndChar[1]))
--]]

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
    local member, err = readArchiveMemberHeader(bs, res);

    -- create binstream that's bigendian
    bs.bigend = true;
    res.NumberOfSymbols = bs:readUInt32();
    res.Offsets = {};
    res.Symbols = {};
    for counter=1,res.NumberOfSymbols do
        local offset = bs:readUInt32();
        table.insert(res.Offsets, offset)
    end

    for counter=1, res.NumberOfSymbols do
        table.insert(res.Symbols, bs:readString())
    end

    return res;
end

--[[
    0   4       Number Of Members in the archive
    4   m*4     Array of Offsets to member headers
    *   4       Number of symbols
    *   n*2     Indices
    *   *       String Table, Array of null terminated strings

    Unlike FirstLinkMember, the integer values in the SecondLinkMember
    are in little-endian format, NOT bigendian
]]
local function readSecondLinkMember(bs, res)
    res = res or {}
    bs:skipToEven();
    local member, err = readArchiveMemberHeader(bs, res);


    res.MemberOffsets = {}
    res.Indices = {}
    res.Symbols = {}
    bs.bigend = false;
    res.NumberOfMembers = bs:readUInt32();
--print("SL: NumberOfMembers: ", string.format("0x%08X", res.NumberOfMembers))

    for counter=1, res.NumberOfMembers do 
        table.insert(res.MemberOffsets, bs:readUInt32())
    end

    res.NumberOfSymbols = bs:readUInt32();
    for counter=1, res.NumberOfSymbols do 
        table.insert(res.Indices, bs:readUInt16())
    end

    for counter=1, res.NumberOfSymbols do
        table.insert(res.Symbols, bs:readString())
    end

    return res;
end

local function readImportHeader(bs, res)
    res = res or {}
    res.Sig1 = bs:readUInt16();
    res.Sig2 = bs:readUInt16();
    res.Version = bs:readUInt16();
    res.Machine = bs:readUInt16();
    res.TimeDateStamp = bs:readUInt32();
    res.SizeOfData = bs:readUInt32();
    res.OrdHint = bs:readUInt16();
    res.NameType = bs:readUInt16();

--[[
print("= ImportHeader =")
print(string.format("  Sig1: %04x", res.Sig1))
print(string.format("  Sig2: %04X", res.Sig2))
print(string.format("Version: ", res.Version))
print(string.format("Machine: 0x%04X", res.Machine))
--]]

    return res;
end


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
    self.FirstLinkMember = readFirstLinkMember(bs);
    self.SecondLinkMember = readSecondLinkMember(bs);

    bs.bigend = false;
    for counter=1, self.SecondLinkMember.NumberOfMembers do
        -- All members start on a two byte boundary, so 
        -- We make sure we're properly aligned before reading
        bs:seek(self.SecondLinkMember.MemberOffsets[counter])
        local member, err = readArchiveMemberHeader(bs);
        if not member then
            break;
        end

        -- It should be a COFF section, so read that next
        --local iheader = readImportHeader(bs)

        parse_COFF(bs, member)
        
        table.insert(self.Members, member);
    end

    return self
end


return parser