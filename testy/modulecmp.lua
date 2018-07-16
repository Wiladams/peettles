--[[
    Utility to show when an exported module name is different
    than the name of the file it lives in.
]]
package.path = "../?.lua;"..package.path

local FileSystem = require("FileSystem");

local argv = {...}
local basepath = argv[1] or ".";
local wfs = FileSystem(basepath);

local function main()
    for entry in wfs:getItems(basepath) do
        print(entry.Name, entry:getFullPath());
    end
end

main()