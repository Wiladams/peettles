package.path = "../?.lua;"..package.path

-- test_filelist.lua
local FileSystem = require("FileSystem");


local argv = {...}

local basepath = argv[1] or ".";
local filename = argv[2];

print("Basepath: ", basepath)
print("Filename: ", filename)

local wfs = FileSystem(basepath);

local function test_single()
	local item = wfs:getItem(filename);

	if item then
		print("     Item: ", item.Name);
		print("Directory: ", item:isDirectory());
		print("Full Path: ", item:getFullPath());
	else
		print("Item not found: ", basepath..'\\'..filename);
	end
end

local function test_multiple()
	for entry in wfs:getItems(basepath) do
		print(entry.Name);
	end
end

local function list_directories()
	for entry in wfs:getItems(filename) do
		if entry:isDirectory() then
			print(entry.Name);
		end
	end
end

--test_single();
test_multiple();
--list_directories();
