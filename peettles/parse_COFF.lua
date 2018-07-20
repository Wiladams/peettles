local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")







--
-- Given an RVA, look up the section header that encloses it 
-- return the table that represents that section
--
local function GetEnclosingSectionHeader(sections, rva)
    --print("==== EnclosingSection: ", rva)
    for secname, section in pairs(self.Sections) do
        -- Is the RVA within this section?
        local pos = rva - section.VirtualAddress;
        if pos >= 0 and pos < section.VirtualSize then
            -- return section, and the calculated offset within the section
            return section, pos 
        end
    end

    return false;
end

-- There are many values within the file which are 'RVA' (Relative Virtual Address)
-- In order to translate this RVA into a file offset, we use the following
-- function.
local function fileOffsetFromRVA(sections, rva)
    local section, pos = GetEnclosingSectionHeader(sections, rva);
    if not section then return false, "section not found for rva"; end
    
    local fileOffset = section.PointerToRawData + pos;
    
    return fileOffset
end

-- Windows loader used to limit to 96
-- but now (as of Windows 10), it can be the full 
-- range of 16-bit number (65535)
function readHeader(ms, res)

    res = res or {}

    res.Machine = ms:readWORD();
    res.NumberOfSections = ms:readWORD();     
    res.TimeDateStamp = ms:readDWORD();
    res.PointerToSymbolTable = ms:readDWORD();
    res.NumberOfSymbols = ms:readDWORD();
    res.SizeOfOptionalHeader = ms:readWORD();
    res.Characteristics = ms:readWORD();

    return res;
end

--[[
    Do the work of actually parsing the interesting
    data in the file.
]]
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


local function parse_COFF(ms, res)
    res = res or {}

    -- We expect to see 'PE' as an indicator that what is
    -- to follow is in fact a PE file.  If not, we quit early
    local ntheadertype = bs:readBytes(4);
    if not IsPEFormatImageFile(ntheadertype) then
        return false, "not PE Format Image File"
    end

    res.Signature = ntheadertype;

    local err = false;
    res.COFF, err = readHeader(ms);

    --print("COFF, sizeOfOptionalHeader: ", self.COFF.SizeOfOptionalHeader)
    if res.COFF.sizeOfOptionalHeader < 1 then
        return res;
    end


    readPEOptionalHeader(ms, res.PEHeader);


    -- Now offset should be positioned at the section table
    res.Sections = readSectionHeaders(ms)

    -- Now that we have section information, we should
    -- be able to read detailed directory information
    res.Directory = readDirectoryData(ms)
end

return parse_COFF;
