--[[
    Parse the imports directory table
    This is one of the more complicated directories to 
    parse.  There are a number of options and oddities
    which are handled here.
]]

local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")
local coff_utils = require("peettles.coff_utils")

--[[
    We need the stream that represents the data, but
    we don't need to be positioned anywhere in particular
    to start.

    I can't remember exactly which spec I read to figure
    this all out, but I remember that it was very 
    involved.
]]

local IMAGE_ORDINAL_FLAG32 = 0x80000000
local IMAGE_ORDINAL_FLAG64 = 0x8000000000000000ULL;

local function parse_imports(bs, peinfo, res)
    --print("==== parse_imports ====")
    res = res or {}

    --printTable(peinfo)
    -- Look for the ImportTable entry in the directory to start
    local dirTable = peinfo.OptionalHeader.Directory.ImportTable
    if not dirTable then return false end

    -- Figure out which section the import directory 
    -- is in
    --local importsStartRVA = dirTable.VirtualAddress
	--local importsSize = dirTable.Size
	local importdescripptr = coff_utils.fileOffsetFromRVA(peinfo.Sections, dirTable.VirtualAddress)

	if not importdescripptr then
		return false, "No section found for import directory"
    end
    
	--print("parse_imports, file offset: ", string.format("0x%x",importdescripptr));

     -- Setup a binstream and start reading
     local ImageImportDescriptorStream = bs:range(dirTable.Size, importdescripptr)

     local ns = bs:clone(0)                             -- used for reading name strings
     local ThunkArrayStream = bs:clone(thunkRVAOffset)  -- used for reading thunk_data
     local HintNameStream = bs:clone(ThunkDataOffset);

	while true do
            OriginalFirstThunk  = ImageImportDescriptorStream:readUInt32();   -- RVA to IMAGE_THUNK_DATA array
            TimeDateStamp       = ImageImportDescriptorStream:readUInt32();
            ForwarderChain      = ImageImportDescriptorStream:readUInt32();
            Name1               = ImageImportDescriptorStream:readUInt32();   -- RVA, Name of the .dll or .exe
            FirstThunk          = ImageImportDescriptorStream:readUInt32();


        -- We keep looping until we run into all null values
        if (Name1 == 0 and OriginalFirstThunk == 0 and FirstThunk == 0) then 
            break;
        end

        
--[[
    -- for debugging
        print("== IMPORT ==")
        print(string.format("OriginalFirstThunk: 0x%08x (0x%08x)", OriginalFirstThunk, coff_utils.fileOffsetFromRVA(peinfo.Sections,OriginalFirstThunk)))
        print(string.format("     TimeDateStamp: 0x%08x", TimeDateStamp))
        print(string.format("    ForwarderChain: 0x%08x", ForwarderChain))
        print(string.format("             Name1: 0x%08x (0x%08x)", Name1, coff_utils.fileOffsetFromRVA(peinfo.Sections,Name1)))
        print(string.format("        FirstThunk: 0x%08x", FirstThunk))
--]]
        -- The .Name1 field contains an RVA which points to
        -- the actual string name of the .dll we've got an export from
        -- .Name1 is an RVA for a file offset
        -- So, get the file offset, and read the string from there
        local DllName = nil
        local Name1Offset = coff_utils.fileOffsetFromRVA(peinfo.Sections, Name1)
        if Name1Offset then
            -- use a separate stream to read the string so we don't
            -- upset the positioning on the one that's reading
            -- the import descriptors
            ns:seek(Name1Offset)

            DllName = ns:readString();
            --print("DllName: ", DllName)
            res[DllName] = {};
        end 

        -- Iterate over the invividual import entries
        -- The thunk points to an array of IMAGE_THUNK_DATA structures
        -- which is comprised of a single uint32_t
		local thunkRVA = OriginalFirstThunk
		local thunkIATRVA = FirstThunk
        if thunkRVA == 0 then
            thunkRVA = thunkIATRVA
        end

		if (thunkRVA ~= 0) then
            local thunkRVAOffset = coff_utils.fileOffsetFromRVA(peinfo.Sections,thunkRVA);

            -- this will point to an array of IMAGE_THUNK_DATA objects
            ThunkArrayStream:seek(thunkRVAOffset)

            -- Read individual Import names or ordinals
            while (true) do
                local ThunkDataRVA = 0ULL;
                if peinfo.OptionalHeader.isPE32Plus then
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

                local ThunkDataOffset = coff_utils.fileOffsetFromRVA(peinfo.Sections,ThunkDataRVA)

                local asOrdinal = false;
                local ordinal = 0;
                -- ordinal is indicated if high order bit is set
                -- then the ordinal itself is in the lower 16 bits
                if peinfo.OptionalHeader.isPE32Plus then
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
                    table.insert(res[DllName], ordinal)
                else
                    -- Read the entries in the nametable
                    HintNameStream:seek(ThunkDataOffset)

                    local hint = HintNameStream:readUInt16();
                    local actualName = HintNameStream:readString();

                    --print(string.format("\t0x%04x %s", hint, actualName))
                    --print(DllName, actualName)
                    table.insert(res[DllName], actualName);
                end
            end
        end
    end

    return res;
end

return parse_imports;
