-- Read the resource directory

local ffi = require("ffi")
local bit = require("bit")
local band = bit.band;

local binstream = require("peettles.binstream")
local peenums = require("peettles.penums")
local putils = require("peettles.print_utils")




local function parseResources(self, restbl)
    -- lookup the entry for the resource directory
    local dirTable = self.PEHeader.Directories.ResourceTable
    if not dirTable then 
        return false, "ResourceTable directory not found" 
    end
    
    restbl = restbl or {}
    
    -- find the associated section
    local resourcedirectoryOffset = self:fileOffsetFromRVA(dirTable.VirtualAddress)
    local bs = self.SourceStream:range(dirTable.Size, resourcedirectoryOffset)


    -- Reading the resource hierarchy is recursive
    -- so , we define a function that will be called
    -- recursively to traverse the entire hierarchy
    -- Each time through, we keep track of the level, in case
    -- we want to do something with that information.
    local function readResourceDirectory(bs, res, level, tab)
    
        level = level or 1
        res = res or {}
        
        print(tab, "-- READ RESOURCE DIRECTORY")
        print(tab, "LEVEL: ", level)


        res.isDirectory = true;
        res.Characteristics = bs:readUInt32();          
        res.TimeDateStamp = bs:readUInt32();            
        res.MajorVersion = bs:readUInt16();             
        res.MinorVersion = bs:readUInt16();            
        res.NumberOfNamedEntries = bs:readUInt16();     
        res.NumberOfIdEntries = bs:readUInt16();        

        res.Entries = {}


        local cnt = 0;
        while (cnt < res.NumberOfNamedEntries + res.NumberOfIdEntries) do
            local entry = {
                level = level;
                Name = bs:readUInt32();
                OffsetToData = bs:readUInt32();
            }
            table.insert(res.Entries, entry)
            cnt = cnt + 1;
        end


        -- Now that we have all the entries (IMAGE_RESOURCE_DIRECTORY_ENTRY)
        -- go through them and perform a specific action for each based on what it is
        for i, entry in ipairs(res.Entries) do
            print(tab, "ENTRY")
            -- check to see if it's a string or an ID
            if band(entry.Name, 0x80000000) ~= 0 then
                -- bits 0-30 are an RVA to a UNICODE string
                -- get RVA offset, not really RVA, but offset 
                -- from start of current section?
                local unirva = band(entry.Name, 0x7fffffff)

                --local unilen = ns:readUInt16();
                --local uniname = readUNICODEString(unilen)
                -- convert unicode to ASCII
                --entry.ID = asciiname;
                entry.ID = unirva
                --print(tab, "NAMED ID: ", entry.ID)
            else
                --print(tab, "  ID: ", string.format("0x%x", entry.Name))
                entry.ID = entry.Name;
            end

            -- It is Microsoft convention to used the 
            -- first three levels to indicate: resource type, ID, language ID
            if level == 1 then
                entry.Kind = entry.ID;
            elseif level == 2 then
                entry.ItemID = entry.ID;
            elseif level == 3 then
                entry.LanguageID = entry.ID;
            end

            -- entry.OffsetToData determines whether we're going after
            -- a leaf node, or just another directory
            --print(tab, "  OffsetToData: ", string.format("0x%x", entry.OffsetToData), band(entry.OffsetToData, 0x80000000))
            if band(entry.OffsetToData, 0x80000000) ~= 0 then
                print(tab, "  DIRECTORY")
                local offset = band(entry.OffsetToData, 0x7fffffff)
                -- pointer to another image directory
                bs:seek(offset)
                readResourceDirectory(bs, entry, level+1, tab.."    " )
            else
                print(tab, "  LEAF: ", entry.OffsetToData)
                -- we finally have actual data, so read the data entry
                -- entry.OffsetToData is an offset from start of root directory
                -- seek to the offset, and start reading
                bs:seek(entry.OffsetToData)

                entry.isData = true;
                entry.DataRVA = bs:readUInt32();
                entry.Size = bs:readUInt32();
                entry.CodePage = bs:readUInt32();
                entry.Reserved = bs:readUInt32();

--[[
                print(tab, "    DataRVA: ", string.format("0x%08X", entry.DataRVA));
                print(tab, "       Size: ",entry.Size);
                print(tab, "  Code Page: ", entry.CodePage);
                print(tab, "   Reserved: ", entry.Reserved);
--]]
                -- The DataRVA points to the actual data
                -- it is supposed to be an offset from the start
                -- of the resource stream
                bs:seek(entry.DataRVA)
                entry.Data = bs:readBytes(entry.Size)
            end
        end

        return res;
    end

    readResourceDirectory(bs, restbl, 1, "");

    return restbl;
end

return parseResources
