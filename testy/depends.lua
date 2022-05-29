--[[
    Here we are interested in dependencies.
    We want to be able to answer questions such as
      "what functions are called the most"
      "what is the dependency tree of a module"

    We can do this by first gathering some dependency information
    then we can stitch together complex processing pipelines
    using the funk module, which gives us some functional programming
    tools.

]]

package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local bit = require("bit")



local enum = require("peettles.enum")
local peparser = require("peettles.peparser")
local peenums = require("peettles.penums")
local mmap = require("peettles.mmap_win32")
local binstream = require("peettles.binstream")
local putils = require("peettles.print_utils")
local COFF = require("peettles.parse_COFF")
local coff_utils = require("peettles.coff_utils")

local FileSystem = require("FileSystem");
local fileiterator = require("fileiterator")
local funk = require("funk")()

local argv = {...}

local basepath = argv[1] or ".";
local filter = argv[2]

local pathfilter = basepath..'\\'..filter




--[[
    gatherHistogram()
    This does the initial work to gather the histogram of dependencies
]]
local function addImports(imports, res)
    if not imports then return end

    for k,v in pairs(imports) do

        for i, name in ipairs(v) do
            local funcname = k..':'..name
            if not res[funcname] then 
               res[funcname] = 1; 
            else 
                res[funcname] = tonumber(res[funcname] + 1); 
            end
        end
    end
end

-- We do the following so that we can sort the keys later
-- The combos are a simple dictionary of name, count
-- we want to turn this into a list of table entries where
-- each entry is {name = functioname, count = count}
-- This will make it easier to sort later
local function prepareHistogram(combos)
    local res = {}

    each(function(k,v) res[#res+1] = {key = k, value = v} end, combos)

    return res
end

-- Convert a path to a PE info structure
local function pathToPEInfo(fullpath)
    local mfile = mmap(fullpath);
    if mfile then 
        local bs = binstream(mfile:getPointer(), mfile.size, 0, true);
        local info, err = peparser:fromStream(bs);
        return info
    else
        return {}
    end
end

local function gatherHistogram(basepath, filter)

    local combos = {}

    local wfs = FileSystem(basepath);
    local pathfilter = basepath..'\\'..filter

    for entry in wfs:getItems(pathfilter) do
        local filename = basepath..'\\'..entry.Name
        local mfile = mmap(filename);
        if mfile then 
            local bs = binstream(mfile:getPointer(), mfile.size, 0, true);
            local info, err = peparser:fromStream(bs);

            addImports(info.PE.Content.Imports, combos)
        else
            print("Could not mmap file: ", filename)
        end
	end

    local hist = prepareHistogram(combos, hist)

    return hist
end


local function projectFullPath(entry) return entry.FullPath end
local function projectImports(entry) return entry.PE.Content.Imports end

    -- iterate all files (take for convenience)
    -- project just the full path (path+filename)
    -- project each file as a PE info structure
    -- project only the structure's imports table
    -- and add the import to the combos dictionary
local function gatherHistory(basepath, filter)

    local combos = {}

    local function handleImports(imports)
        addImports(imports, combos)
    end

    each(handleImports,  map(projectImports, map(pathToPEInfo, map(projectFullPath, fileiterator(basepath, filter)))))

    local hist = prepareHistogram(combos, hist)

    return hist
end

local function printByName(combo)
    print(string.format("%s, %4d", combo.key, combo.value))
end

local function printByValue(combo)
    print(string.format("%4d, %s", combo.value, combo.key))
end

local function sortAscendingByName(hist)
    table.sort(hist, function(a,b) return a.key < b.key end)
    return hist
end
    
local function sortDescendingByVolume(hist)
    table.sort(hist, function(a,b) return a.value > b.value end)
    return hist
end


-- A couple of processing chains
-- We want to see which functions are being called, alphabetically
--iter(sortAscendingByName(gatherHistogram(basepath, filter))):each(printByName)
iter(sortAscendingByName(gatherHistory(basepath, filter))):each(printByName)

-- we want to see which functions are being called the most first
-- take the top 50
--iter(sortDescendingByVolume(gatherHistogram(basepath, filter))):take(50):each(printByValue)
--iter(sortDescendingByVolume(gatherHistogram(basepath, filter))):each(printByValue)
