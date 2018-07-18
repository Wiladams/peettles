local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")


local function isValidDOS(bytes)
    return bytes[0] == string.byte('M') and
        bytes[1] == string.byte('Z')
end

local function readDOSHeader(ms, res)

    local res = res or {}
    
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
    res.DOSStubSize = res.DOSHeader.e_lfanew - ms:tell();
    res.DOSStub =  ms:readBytes(res.DOSStubSize);   -- should be a Valid DOS stub program

    return res;
end


return parse_DOS;