local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")


local MEMORY_PARAGRAPH_SIZE = 16;


--[[
    The 'DOS' part of the file is comprised of a couple of sections.
    The first part, beginning the 'MZ', distinguishes the file as PECOFF.
    Most usually, the only part of this header section a PECOFF parser is interested
    in is the 'e_lfanew' field, which points to the beginning of the 'PE' portion of the file.

    Instead of ignoring the other fields in this header, we actually read them all in, 
    and use what we can for other purposes.  We are interested in the DOS Stub program 
    which is typically located right after the DOS header.  While reading the file as 
    a stream, you might be tempted to just start reading the stub right after the DOS
    header, but that would be incorrect.  The field 'e_cparhdr' tells you how big the 
    header is (in 16-byte pages).  You use this value, multiplied out, to find the actual
    location of the DOS Stub.

    We then read the DOS stub, as some consumer of this library might like to disassemble
    or otherwise play with this data.
]]
local function isValidDOS(bytes)
    return bytes[0] == string.byte('M') and
        bytes[1] == string.byte('Z')
end

local function readDOSHeader(ms, res)

    local res = res or {}
    
    local sentinel = ms:tell();
    res.e_magic = ms:readBytes(2);    -- Magic number, must be 'MZ'

    if not isValidDOS(res.e_magic) then
        return false, "'MZ' signature not found", res.e_magic
    end

    res.e_cblp = ms:readWORD();               -- Bytes on last page of file
    res.e_cp = ms:readWORD();                 -- Pages in file
    res.e_crlc = ms:readWORD();               -- Relocations
    res.e_cparhdr = ms:readWORD();            -- Size of header in paragraphs
    res.e_minalloc = ms:readWORD();           -- Minimum extra paragraphs needed
    res.e_maxalloc = ms:readWORD();           -- Maximum extra paragraphs needed
    res.e_ss = ms:readWORD();                 -- Initial (relative) SS value
    res.e_sp = ms:readWORD();                 -- Initial SP value
    res.e_csum = ms:readWORD();               -- Checksum
    res.e_ip = ms:readWORD();                 -- Initial IP value
    res.e_cs = ms:readWORD();                 -- Initial (relative) CS value
    res.e_lfarlc = ms:readWORD();             -- File address of relocation table
    res.e_ovno = ms:readWORD();               -- Overlay number
        ms:skip(4*2);                           -- e_res, basetype="uint16_t", repeating=4},    -- Reserved s
    res.e_oemid = ms:readWORD();              -- OEM identifier (for e_oeminfo)
    res.e_oeminfo = ms:readWORD();            -- OEM information; e_oemid specific
        ms:skip(10*2);                        -- e_res2, basetype="uint16_t", repeating=10},  -- Reserved s
    res.e_lfanew = ms:readWORD();             -- File address of new exe header
    
    res.HeaderSizeCalculated = res.e_cparhdr * MEMORY_PARAGRAPH_SIZE;
    res.HeaderSizeActual = ms:tell() - sentinel;
    res.StreamOffset = ms:tell();

    return res;
end



local function parse_DOS(ms, res)
    res = res or {}

    local DOSHeader, err = readDOSHeader(ms);
    if not DOSHeader then 
        return false, err;
    end

    res.DOSHeader = DOSHeader;
    -- figure out how big the DOS stub is, if there is one
    -- seek to where the DOS Stub should be.  It's located after the 
    -- DOS header, calculated as 'Size of header in paragraphs' * 16 (size of a paragraph)
    -- this is typically going to be 0x40, which is 2 bytes short of where the stream would be after 
    -- reading the header.
    local StubOffset = res.DOSHeader.e_cparhdr * MEMORY_PARAGRAPH_SIZE;
    local StubSize = res.DOSHeader.e_lfanew - StubOffset;
    ms:seek(StubOffset);
    local Data = ms:readBytes(StubSize);

    res.DOSStub = {
        Offset = StubOffset;
        Size = StubSize;
        Data = Data;
    }


    return res;
end


return parse_DOS;