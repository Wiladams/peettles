-- An iterator of files
local ffi = require("ffi")
local w32 = require("peettles.w32")
local FileSystemItem = require("FileSystemItem");
local Collections = require("Collections");

local k32Lib = ffi.load("kernel32");


local function isDirectory(entry)
	return band(entry.Attributes, ffi.C.FILE_ATTRIBUTE_DIRECTORY) > 0; 
end

--[[
    This iterator follows the generator, param, state pattern
    the fileiterator() function returns a generator and initial state, which
    the lua iterator machinery can use to iterate over the files in the directory.

    We're using the FindFirstFileExW(), FindNextFileW() functions of Windows
    to do the actual iteration.
]]
local function file_iter_gen(param, status)
	if status == 0 then 
        -- close the handle
        if (param.RawHandle ~= INVALID_HANDLE_VALUE) then
            k32Lib.CloseHandle(param.RawHandle);
        end
		return nil;
	end

    -- create the entry we'll pass along
    local value = {
        BasePath = param.BasePath;
        Attributes = param.FileData.dwFileAttributes;
        Name = w32.toAnsi(param.FileData.cFileName);
        Size = (param.FileData.nFileSizeHigh * (MAXDWORD+1)) + param.FileData.nFileSizeLow;
        };
        value.FullPath = value.BasePath..'\\'..value.Name;
        local fsitem = FileSystemItem(value);

    -- move to the next one before we return 
    local status = k32Lib.FindNextFileW(param.RawHandle, param.FileData);

    return status, fsitem;
end

--[[
    You start the iteration by giving a base path and a filter.
    The filter is used as a kind of simple wildcard that is applied
    to the basepath directory.

    Ex:
        local it = fileiterator("C:\\", "*.lua");
        for entry in it do
            print(entry.FullPath);
        end
]]
local function directoryIterator(basepath, wildcard)
    local pattern = basepath
    if wildcard then
        pattern = pattern..'\\'..wildcard
    end

    local lpFileName = w32.toUnicode(pattern);
    local fInfoLevelId = ffi.C.FindExInfoBasic;
    local lpFindFileData = ffi.new("WIN32_FIND_DATAW");
	local fSearchOp = ffi.C.FindExSearchNameMatch;
    local lpSearchFilter = nil;
    local dwAdditionalFlags = 0;

    local rawHandle = k32Lib.FindFirstFileExW(lpFileName,
        fInfoLevelId,
        lpFindFileData,
        fSearchOp,
    lpSearchFilter,
    dwAdditionalFlags);

    --print("rawHandle: ", rawHandle)

    local status = 1
    if (rawHandle == INVALID_HANDLE_VALUE) then
        status = 0
    end

    return file_iter_gen, {FileData = lpFindFileData, RawHandle = rawHandle, BasePath = basepath, Filter = filter}, status
end


--[[
    Generator for recursive directory iteration.
    start by getting the first entry in the directory
    for each entry, if it's a directory,
    return a generator for that directory
]]
local function recursive_iter_gen(param, status)
    if status == 0 then
        return nil;
    end
end

--[[

]]
function recursiveIterator(basepath, wildcard)
	local stack = Collections.Stack();
	local gen, param, state = self:directoryIterator(basepath, wildcard);
    local itemIter = {gen=gen, param=param, state=state}
    
	local closure = function()
		while true do
			local anItem = gen();
			if anItem then
				if (anItem.Name ~= ".") and (anItem.Name ~= "..") then
					if anItem:isDirectory() then
						stack:push(itemIter);
						itemIter = anItem:items();
					end

					return anItem;
				end
			else
				itemIter = stack:pop();
				if not itemIter then
					return nil;
				end 
			end
		end 
	end

	return closure;
end


return {
    generator = file_iter_gen;
    iterator = directoryIterator;
    depthIterator = fileiterator;
}
