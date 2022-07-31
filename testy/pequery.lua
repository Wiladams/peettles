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
local lshift = bit.lshift


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
local wildcard = argv[2]

local pathfilter = basepath..'\\'..wildcard

-- Convert a path to a PE info structure
-- Essentially, run the pe parser on the file
local function pathToPEInfo(fullpath)
    local mfile = mmap(fullpath);
    if mfile then 
        local bs = binstream(mfile:getPointer(), mfile.size, 0, true);
        local info, err = peparser:fromStream(bs);
        if not info then
            info =  {}
        end
        info.FullPath = fullpath;

        return info
    else
        return {}
    end
end

local function pathToSignature(fullpath)
    local mfile = mmap(fullpath);
    if mfile then 
        local bs = binstream(mfile:getPointer(), mfile.size, 0, true);
        local sig = bs:readBytes(2);    -- Magic number
        local signum = 0;
        if bs:tell()==2 then
            signum = sig[0] + lshift(sig[1],8)
        end

        if (signum ~= 0x4947) and (signum ~= 0) then
            return string.format("%c%c, 0x%04x, %s", sig[0], sig[1], sig[0] + lshift(sig[1],8), fullpath)
        end
    end
    return ""
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

local function printTable(t)
    for k,v in pairs(t) do
        print(k,v)
    end
end


--[[
    Some interesting predicates
]]
-- true, if file ends with '.dll'
local function onlyDlls(entry)
    return entry.FullPath:match(".*%.dll$")
end

local function onlyGreaterThanMb(entry)
        return entry.Size > 14*1024*1024
end

--[[
    Some Print routines
]]
local function printInfo(entry)
    if entry.DOS then
    print(entry.DOS.Signature)
    end

end

local function printFileInfo(entry)
    print("-----")
    printTable(entry)
end

local function printFileCSV(entry)
    print(string.format("%d,%s", entry.Size, entry.Name))
end


--[[
    Write some query logic here
]]



-- Print each file to be iterated
--each(printFileCSV,fileiterator(basepath, wildcard))
each(printFileCSV,fileiterator(basepath, wildcard))

--each(printFile, filter(onlyDlls, fileiterator(basepath, wildcard)))
-- size greater than 1mb
--each(printFileCSV, filter(onlyGreaterThanMb, fileiterator(basepath, wildcard)))

-- print each PE info structure
--each(print, map(pathToSignature, map(projectFullPath, fileiterator(basepath, filter))))

-- let's print out the files that are 'MV'
--each(printInfoPath, map(pathToPEInfo, map(projectFullPath, take(5,fileiterator(basepath, wildcard)))))