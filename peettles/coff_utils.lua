local ffi = require("ffi")

--
-- Given a list of sections, and an RVA, lookup the section 
-- that contains the specified relative virtual address
-- Return the found section, or nil if none found.
--
local function getEnclosingSection(sections, rva)
    --print("==== getEnclosingSection: ", rva)
    for secname, section in pairs(sections) do
        -- Is the RVA within this section?
        local pos = rva - section.VirtualAddress;
        if pos >= 0 and pos < section.VirtualSize then
            -- return section, and the calculated offset within the section
            return section, pos 
        end
    end

    return false, "RVA not in a section";
end

-- There are many values within the file which are 'RVA' (Relative Virtual Address)
-- In order to translate this RVA into a file offset, we use the following
-- function.
local function fileOffsetFromRVA(sections, rva)
    local section, pos = getEnclosingSection(sections, rva);
    if not section then 
        return false, "section not found for rva"; 
    end
    
    local fileOffset = section.PointerToRawData + pos;
    
    return fileOffset
end

--[[
    Utility function for section object creation
]]
--
-- stringFromBuffer()
-- given a buffer and a length, return a lua string
-- the lua string will not include trailing null bytes
local function stringFromBuff(buff, size)
	local truelen = size
	for i=size-1,0,-1 do
		if buff[i] == 0 then
		    truelen = truelen - 1
		end
	end
	return ffi.string(buff, truelen)
end

local exports = {
    getEnclosingSection = getEnclosingSection,
    fileOffsetFromRVA = fileOffsetFromRVA,
    stringFromBuff = stringFromBuff,
}

return exports


--[[
    Definition of a section object.  This is meant as a
    simple convenience for sections within the PE file.
]]
--[[
local section_t = {}
local section_mt = {
    __index = section_t;
}

function section_t.GetEnclosingSection(sections, rva)
    --print("==== EnclosingSection: ", rva)
    for secname, section in pairs(sections) do
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
function section_t.fileOffsetFromRVA(self, rva)
    local section, pos = self:GetEnclosingSection(rva);
    if not section then 
        return false, "section not found for rva"; 
    end
    
    local fileOffset = section.PointerToRawData + pos;
    
    return fileOffset
end
--]]
