--[[
    Parse the imports directory table
]]

local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")



local function parse_imports(self, res)
    --print("==== readDirectory_Import ====")
    local IMAGE_ORDINAL_FLAG32 = 0x80000000
    local IMAGE_ORDINAL_FLAG64 = 0x8000000000000000ULL;
    
    
    local dirTable = self.PEHeader.Directories.ImportTable
    if not dirTable then return false end

    res = res or {}

    -- Get section import directory is in
    local importsStartRVA = dirTable.VirtualAddress
	local importsSize = dirTable.Size
	local importdescripptr = self:fileOffsetFromRVA(dirTable.VirtualAddress)

	if not importdescripptr then
		return false, "No section found for import directory"
    end
    

	--print("file offset: ", string.format("0x%x",importdescripptr));

     -- Setup a binstream and start reading
    local ImageImportDescriptorStream = binstream(self._data, self._size, 0, true)
    ImageImportDescriptorStream:seek(importdescripptr);
	while true do
        local entry = {
            OriginalFirstThunk  = ImageImportDescriptorStream:readUInt32();   -- RVA to IMAGE_THUNK_DATA array
            TimeDateStamp       = ImageImportDescriptorStream:readUInt32();
            ForwarderChain      = ImageImportDescriptorStream:readUInt32();
            Name1               = ImageImportDescriptorStream:readUInt32();   -- RVA, Name of the .dll or .exe
            FirstThunk          = ImageImportDescriptorStream:readUInt32();
        }

        if (entry.Name1 == 0 and entry.OriginalFirstThunk == 0 and entry.FirstThunk == 0) then 
            break;
        end

--[[
        print("== IMPORT ==")
        print(string.format("OriginalFirstThunk: 0x%08x (0x%08x)", entry.OriginalFirstThunk, self:fileOffsetFromRVA(entry.OriginalFirstThunk)))
        print(string.format("     TimeDateStamp: 0x%08x", entry.TimeDateStamp))
        print(string.format("    ForwarderChain: 0x%08x", entry.ForwarderChain))
        print(string.format("             Name1: 0x%08x (0x%08x)", entry.Name1, self:fileOffsetFromRVA(entry.Name1)))
        print(string.format("        FirstThunk: 0x%08x", entry.FirstThunk))
--]]
        -- The .Name1 field contains an RVA which points to
        -- the actual string name of the .dll
        -- So, get the file offset, and read the string
        local Name1Offset = self:fileOffsetFromRVA(entry.Name1)
        if Name1Offset then
            -- use a separate stream to read the string so we don't
            -- upset the positioning on the one that's reading
            -- the import descriptors
            local ns = binstream(self._data, self._size, Name1Offset, true)

            entry.DllName = ns:readString();
            --print("DllName: ", entry.DllName)
            res[entry.DllName] = {};
        end 

        -- Iterate over the invividual import entries
        -- The thunk points to an array of IMAGE_THUNK_DATA structures
        -- which is comprised of a single uint32_t
		local thunkRVA = entry.OriginalFirstThunk
		local thunkIATRVA = entry.FirstThunk
        if thunkRVA == 0 then
            thunkRVA = thunkIATRVA
        end

		if (thunkRVA ~= 0) then
            local thunkRVAOffset = self:fileOffsetFromRVA(thunkRVA);

            -- this will point to an array of IMAGE_THUNK_DATA objects
            -- so create a separate stream to read them
            local ThunkArrayStream = binstream(self._data, self._size, thunkRVAOffset, true)

            -- Read individual Import names or ordinals
            while (true) do
                local ThunkDataRVA = 0ULL;
                if self.isPE32Plus then
                        --print("PE32Plus")
                    ThunkDataRVA = ThunkArrayStream:readUInt64();
                        --print("ThunkDataRVA(64): ", ThunkDataRVA)
                else
                    ThunkDataRVA = ThunkArrayStream:readUInt32();
                    --print("ThunkDataRVA(32): ", ThunkDataRVA)
                end

                --print(string.format("ThunkDataRVA: 0x%08X (0x%08X)", ThunkDataRVA, self:fileOffsetFromRVA(ThunkDataRVA)))
                if ThunkDataRVA == 0 then
                    break;
                end

                local ThunkDataOffset = self:fileOffsetFromRVA(ThunkDataRVA)

                local asOrdinal = false;
                local ordinal = 0;
                -- ordinal is indicated if high order bit is set
                -- then the ordinal itself is in the lower 16 bits
                if self.isPE32Plus then
                    if band(ThunkDataRVA, IMAGE_ORDINAL_FLAG64) ~= 0 then
                        asOrdinal = true;
                        ordinal = tonumber(band(0xffff, ThunkDataRVA))
                    end
                else
                    if band(ThunkDataRVA, IMAGE_ORDINAL_FLAG32) ~= 0 then
                        asOrdinal = true;
                        ordinal = tonumber(band(0xffff, ThunkDataRVA))
                    end
                end 

                -- Check for Ordinal only import
                -- must be mindful of 32/64-bit
                if (asOrdinal) then
                    --print("** IMPORT ORDINAL!! **")
                    table.insert(res[entry.DllName], ordinal)
                else
                    -- Read the entries in the nametable
                    local HintNameStream = binstream(self._data, self._size, ThunkDataOffset, true);

                    local hint = HintNameStream:readUInt16();
                    local actualName = HintNameStream:readString();

                    --print(string.format("\t0x%04x %s", hint, actualName))
                    table.insert(res[entry.DllName], actualName);
                end
            end
        end
    end

    return res;
end

return parse_imports;
