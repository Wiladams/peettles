-- An iterator of files
local ffi = require("ffi")
local w32 = require("peettles.w32")
local FileSystemItem = require("FileSystemItem");

local k32Lib = ffi.load("kernel32");

local function file_iter_gen(param, status)
	if status == 0 then 
        -- close the handle
        if (param.RawHandle ~= INVALID_HANDLE_VALUE) then
            k32Lib.CloseHandle(param.RawHandle);
        end
		return nil;
	end

    local value = {
        BasePath = param.BasePath;
        Attributes = param.FileData.dwFileAttributes;
        Name = w32.toAnsi(param.FileData.cFileName);
        Size = (param.FileData.nFileSizeHigh * (MAXDWORD+1)) + param.FileData.nFileSizeLow;
        };
        value.FullPath = value.BasePath..'\\'..value.Name;
        
    -- move to the next one before we return 
    local status = k32Lib.FindNextFileW(param.RawHandle, param.FileData);

    return status, value;
end

local function fileiterator(basepath, filter)
    local pattern = basepath..'\\'..filter
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

return fileiterator
