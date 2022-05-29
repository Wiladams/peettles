package.path = "../?.lua;"..package.path


local fileiterator = require("fileiterator")
local funk = require("funk")()

local argv = {...}

local basepath = argv[1] or ".";
local filter = argv[2]

local pathfilter = basepath..'\\'..filter

if not pathfilter then
    print("Usage: luajit listFiles.lua <basepath> <filter>")
    return
end

function printTable(t)
    print("--------------")
    for k,v in pairs(t) do
        print(k,v)
    end
end

--each(printTable, fileiterator(basepath, filter))
each(print, map(function(x)return x.FullPath end, fileiterator(basepath, filter)))
