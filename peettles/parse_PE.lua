local ffi = require("ffi")
local COFF = require("peettles.parse_COFF")

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

-- The stream should now be located at the 'PE' signature
-- we assume we can only read Portable Executable
-- anything else is an error
-- res.Signature
-- res.ImageFileHeader
-- res.OptionalHeader
--
local function parse_PE(bs, res)
    local res = res or {}


    -- We expect to see 'PE' as an indicator that what is
    -- to follow is in fact a PE file.  If not, we quit early
    local sig = bs:readBytes(4);

    res.Signature = sig;

    if not IsPEFormatImageFile(sig) then
        return false, "unparsable Image Format: "..sig, res
    end

    -- Read the PE Image File Header
    res.COFFHeader = {}
    local success, err = COFF.readCOFFHeader(bs, res.COFFHeader);

    if not success then
        return false, err, res
    end

    -- Read the PE Optional Header
    res.OptionalHeader = {}
    local success, err = COFF.readOptionalHeader(bs, res.OptionalHeader);

    if not success then
        return false, err, res
    end

    -- Read PE Sections
    -- at this point, the offset in the stream should be positioned 
    -- at the beginning of the section table
    res.Sections = {}
    success, err = COFF.readSectionHeaders(bs, res.Sections, res.COFFHeader.NumberOfSections)
    

    -- Now that we have sections, we should be able to read the section data
    res.Content = {}
    success, err = COFF.readContentData(bs, res, res.Content)

    return res;
end


return parse_PE
