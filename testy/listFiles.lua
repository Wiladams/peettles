package.path = "../?.lua;"..package.path

local ffi = require("ffi")

local fileiterator = require("fileiterator").iterator
local funk = require("funk")()
local FileSystemItem = require("FileSystemItem")
local enum = require("peettles.enum")

local argv = {...}

local basepath = argv[1] or ".";
local wildcard = argv[2]

local pathfilter = basepath..'\\'..wildcard

if not pathfilter then
    print("Usage: luajit listFiles.lua <basepath> <wildcard>")
    return
end

local function isDirectory(entry)
    return bit.band(entry.Attributes, ffi.C.FILE_ATTRIBUTE_DIRECTORY) ~= 0
end

local function isHidden(entry)
    return bit.band(entry.Attributes, ffi.C.FILE_ATTRIBUTE_HIDDEN) ~= 0
end

local function isHiddenDirectory(entry)
    return isDirectory(entry) and isHidden(entry)
end

--[[
    Print routines
]]
function printFileInfo(entry)
    print(string.format("%d, %s, '%s'", entry.Size, entry.Name, enum.bitValues(FileSystemItem.FileAttributes, entry.Attributes, 32)))
end

function printTable(t)
    print("--------------")
    for k,v in pairs(t) do
        print(k,v)
    end
end

--each(printTable, fileiterator(basepath, wildcard))
-- All files that match wildcard
--each(printFileInfo, fileiterator(basepath, wildcard))

-- All directories that match wildcard
--each(printFileInfo, filter(isDirectory, fileiterator(basepath, wildcard)))

-- All hidden directories
--each(printFileInfo, filter(isHiddenDirectory, fileiterator(basepath, wildcard)))
iter(fileiterator(basepath, wildcard)):filter(isHiddenDirectory):each(printFileInfo)