--[[
    parse the exports directory table
]]
local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")

local function parse(bs, peinfo, res)

    --print("==== readDirectory_Export ====")
    local dirTable = peinfo.OptionalHeader.Directory.ExportTable
    if not dirTable then 
        return false , "NO EXPORT TABLE FOUND"
    end

    -- If the virtual address is zero, then we don't actually
    -- have any exports
    if dirTable.VirtualAddress == 0 then
        return false, "  No Virtual Address";
    end




    -- We use the directory entry to lookup the actual export table.
    -- We need to turn the VirtualAddress into an actual file offset
    -- We also want to know what section the export table is in for 
    -- forwarding comparisons
    local sections = peinfo.Sections;
    local exportSection = sections:GetEnclosingSectionHeader(dirTable.VirtualAddress)
    local exportSectionName = exportSection.Name;

    local fileOffset = sections:fileOffsetFromRVA(dirTable.VirtualAddress)

    -- We now know where the actual export table exists, so 
    -- create a binary stream, and position it at the offset
    local ms = bs:range(dirTable.Size, fileOffset)

    -- We are now in position to read the actual export table data
    -- The data consists of various bits and pieces of information, including
    -- pointers to the actual export information.
    res = res or {}
    res.Characteristics = ms:readUInt32();
    res.TimeDateStamp = ms:readUInt32();
    res.MajorVersion = ms:readUInt16();
    res.MinorVersion = ms:readUInt16();
    res.nName = ms:readUInt32();                -- Relative to image base
    res.nBase = ms:readUInt32();
    res.NumberOfFunctions = ms:readUInt32();
    res.NumberOfNames = ms:readUInt32();
    res.AddressOfFunctions = ms:readUInt32();
    res.AddressOfNames = ms:readUInt32();
    res.AddressOfNameOrdinals = ms:readUInt32();

    -- Get the internal name of the module
    local nNameOffset = sections:fileOffsetFromRVA(res.nName)
    if nNameOffset then
        -- use a separate stream to read the string so we don't
        -- upset the positioning on the one that's reading
        -- the import descriptors
        local ns = binstream(self._data, self._size, nNameOffset, true)
        res.ModuleName = ns:readString();
    end 

    -- Get the function pointers
    res.AllFunctions = {};
    if res.NumberOfFunctions > 0 then
        local EATOffset = self:fileOffsetFromRVA(res.AddressOfFunctions);
        local EATStream = binstream(self._data, self._size, EATOffset, true);

        --print("EATOffset: ", string.format("0x%08X", EATOffset))

        -- Get array of function pointers
        -- EATable represents a '0' based array of these function RVAs
        for i=0, res.NumberOfFunctions-1 do 
            local AddressRVA = EATStream:readUInt32()

            if AddressRVA ~= 0 then
                local section = self:GetEnclosingSectionHeader(AddressRVA)
                local ExportOffset = self:fileOffsetFromRVA(AddressRVA)

                -- We use the AddressRVA to figure out which section the function
                -- body is located in.  If that section is not a code section, then
                -- the RVA is actually a pointer to a string, which is a forward
                -- reference to a function in another .dll
                
                -- To figure out whether the section pointed to has code or not, 
                -- we can use the name '.text', or '.code'
                -- but, a better approach is to use the peenums.SectionCharacteristics
                -- and look for IMAGE_SCN_MEM_EXECUTE, IMAGE_SCN_MEM_READ and IMAGE_SCN_CNT_CODE
                if section then
                    --print("EXPORT INDEX: ", i, string.format("0x%08X",AddressRVA), section.Name)

                    -- Check to see if the section the RVA points to is actually
                    -- a code section.  If it is, then save the Address
                    if band(section.Characteristics, peenums.SectionCharacteristics.IMAGE_SCN_MEM_EXECUTE) ~= 0 and
                        band(section.Characteristics, peenums.SectionCharacteristics.IMAGE_SCN_MEM_READ)~=0  and
                        band(section.Characteristics, peenums.SectionCharacteristics.IMAGE_SCN_CNT_CODE)~=0 then

                        res.AllFunctions[i] = AddressRVA;
                    elseif section.Name == exportSectionName then 
                        -- If not a code section, then it could possibly be a forwarder
                        -- these are typically pointing into the exports section itself
                        local ForwardStream = binstream(self._data, self._size, ExportOffset, true)
                        local forwardName = ForwardStream:readString();
                        res.AllFunctions[i] = forwardName;

                        --ForwardStream:seek(ExportOffset);
                        --putils.printHex({stream = ForwardStream, iterations = 1})
                    else
                        -- otherwise, it's possibly a reference to a global variable
                        -- so, we'll just record the RVA like we'd record a function symbol
                        res.AllFunctions[i] = AddressRVA;
                    end
                else
                    print("NO SECTION FOUND for AdressRVA:  ", i)
                end
            else
                --EATable[i] = false;
            end
        end
    end

    -- Get the names if the Names array exists
    res.NamedFunctions = {}
    if res.NumberOfNames > 0 then
        local ENTOffset = self:fileOffsetFromRVA(res.AddressOfNames)
        local ENTStream = binstream(self._data, self._size, ENTOffset, true);

        -- Setup a stream for the AddressOfNameOrdinals (EOT) table
        local EOTOffset = self:fileOffsetFromRVA(res.AddressOfNameOrdinals);
        local EOTStream = binstream(self._data, self._size, EOTOffset, true);

        -- create a stream we'll use repeatedly to read name values
        local nameStream = binstream(self._data, self._size, 0, true);
        
        for i=1, res.NumberOfNames do
            -- create a stream pointing at the specific name
            local nameRVA = ENTStream:readUInt32();
            local nameOffset = self:fileOffsetFromRVA(nameRVA)
            nameStream:seek(nameOffset)

            local name = nameStream:readString();
            local hint = EOTStream:readUInt16();
            local ordinal = hint + res.nBase;
            local index = hint;
            --local funcptr = self.Export.AllFunctions[ordinal];
            local funcptr = res.AllFunctions[index];

            --print("  name: ", ordinal, name)
            table.insert(res.NamedFunctions, {name = name, hint=hint, ordinal = ordinal , index = index, funcptr=funcptr})
        end
    end

    -- Last list, functions exported by ordinal only
    local function nameByIndex(index)
        for i, entry in ipairs(res.NamedFunctions) do
            if entry.index == index then
                return entry;
            end
        end
        return false;
    end

    res.OrdinalOnly = {}
    for index, value in pairs(res.AllFunctions) do
        if not nameByIndex(index) then
            res.OrdinalOnly[index] = value;
        end
	end

    return res;
end

return parse;
