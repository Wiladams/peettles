--[[
    Here we are interested in dependencies.
    We want to be able to answer questions such as
      "what functions are called the most"
      "what is the dependency tree of a module"

    We can do this by first gathering some dependency information
    then we can stitch together complex processing pipelines
    using the funk module, which gives us some functional programming
    tools.

    The individual functions are created in such a way that they
    can be used in a pipeline.
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

local fileiterator = require("fileiterator")
local funk = require("funk")()
local Demangler = require("peettles.demangler")


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
-- Essentially, run the pe parser on the file
local function pathToPEInfo(fullpath)
    local mfile = mmap(fullpath);
    if mfile then 
        local bs = binstream(mfile:getPointer(), mfile.size, 0, true);
        local info, err = peparser:fromStream(bs);
        info.FullPath = fullpath
        return info
    else
        return {}
    end
end


-- The input should be a file system item.
-- forward only the FullPath entry
local function projectFullPath(entry) return entry.FullPath end

-- forward only the Imports table from the PE info to whomever is interested
-- The input should be a table with PE info in it
local function projectImports(entry) 
    if not entry.PE then 
        return {}
    else 
        return entry.PE.Content.Imports 
    end
end

    -- iterate all files (take for convenience)
    -- project just the full path (path+filename)
    -- project each file as a PE info structure
    -- project only the structure's imports table
    -- and add the import to the combos dictionary
local function gatherHistogram(basepath, filter)

    local combos = {}

    local function handleImports(imports)
        addImports(imports, combos)
    end

    each(handleImports,  map(projectImports, map(pathToPEInfo, map(projectFullPath, fileiterator(basepath, filter)))))

    local hist = prepareHistogram(combos, hist)

    return hist
end


--[[
    These routines are used in a pipeline to print items
    sort tables, and the like.
]]
local function printByName(combo)
    print(string.format("%s, %4d", combo.key, combo.value))
end

    -- split the name into the dll and function name
    -- based on where the ':' is
    -- If the function name contains '?', then it is a mangled name 
    -- so demangle it
local function printByValue(combo)
    local easyName = combo.key
    local funcName = combo.key
    local dllName = combo.keys
    local signature = combo.key


    local start, len = easyName:find(':')
    if start then
        dllName = easyName:sub(1, start-1)
        funcName = easyName:sub(start+1)
        signature = funcName

        if funcName:find("%?") then
            signature = Demangler.demangle(funcName)
        end
    end

    print(string.format("%4d, %-48s, %-32s, %s", combo.value, dllName, signature, funcName))
end

local function sortAscendingByName(hist)
    table.sort(hist, function(a,b) return a.key < b.key end)
    return hist
end
    
local function sortDescendingByVolume(hist)
    table.sort(hist, function(a,b) return a.value > b.value end)
    return hist
end

--[[
    Here are a couple of processing chains.
]]


-- We want to see which functions are being called, alphabetically
-- you can either method of starting from the source on the left
-- or build outward from the right
--iter(sortAscendingByName(gatherHistogram(basepath, filter))):each(printByName)
--each(printByName, sortAscendingByName(gatherHistogram(basepath, filter)))

-- we want to see which functions are being called the most first
iter(sortDescendingByVolume(gatherHistogram(basepath, filter))):each(printByValue)
-- take the top 50
--iter(sortDescendingByVolume(gatherHistogram(basepath, filter))):take(50):each(printByValue)

