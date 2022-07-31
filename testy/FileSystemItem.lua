
local ffi = require("ffi");
local bit = require("bit");
local band = bit.band;

local Collections = require("Collections");

local w32 = require("peettles.w32")
local enum = require("peettles.enum")



local FileAttributes = enum {
	FILE_ATTRIBUTE_READONLY             = 0x00000001;  
	FILE_ATTRIBUTE_HIDDEN               = 0x00000002;  
	FILE_ATTRIBUTE_SYSTEM               = 0x00000004;  
	FILE_ATTRIBUTE_DIRECTORY            = 0x00000010;  
	FILE_ATTRIBUTE_ARCHIVE              = 0x00000020;  
	FILE_ATTRIBUTE_DEVICE               = 0x00000040;  
	FILE_ATTRIBUTE_NORMAL               = 0x00000080;  
	FILE_ATTRIBUTE_TEMPORARY            = 0x00000100;  
	FILE_ATTRIBUTE_SPARSE_FILE          = 0x00000200;  
	FILE_ATTRIBUTE_REPARSE_POINT        = 0x00000400;  
	FILE_ATTRIBUTE_COMPRESSED           = 0x00000800;  
	FILE_ATTRIBUTE_OFFLINE              = 0x00001000;  
	FILE_ATTRIBUTE_NOT_CONTENT_INDEXED  = 0x00002000;  
	FILE_ATTRIBUTE_ENCRYPTED            = 0x00004000;  
	FILE_ATTRIBUTE_VIRTUAL              = 0x00010000;  
	
}


local k32Lib = ffi.load("kernel32");

-- Create a convenient handle type for Find Handles
ffi.cdef[[
typedef struct {
	HANDLE Handle;
} FsFindFileHandle;
]]


local FsFindFileHandle = ffi.typeof("FsFindFileHandle");
local FsFindFileHandle_mt = {
	__gc = function(self)
		k32Lib.FindClose(self.Handle);
	end,

	__index = {
		isValid = function(self)
			return self.Handle ~= INVALID_HANDLE_VALUE;
		end,
	},
};
ffi.metatype(FsFindFileHandle, FsFindFileHandle_mt);


--[[
	File System File Iterator
--]]

local FileSystemItem = {
	FsFindFileHandle = FsFindFileHandle;
	FileAttributes= FileAttributes;
}
setmetatable(FileSystemItem, {
	__call = function(self, ...)
		return self:new(...);
	end,
});

local FileSystemItem_mt = {
	__index = FileSystemItem;
}


FileSystemItem.new = function(self, params)
	params = params or {}
	params.BasePath = params.BasePath or ".";

	setmetatable(params, FileSystemItem_mt);

	return params;
end

function FileSystemItem.getFullPath(self)
	local fullpath = self.BasePath;

	if self.Parent then
		fullpath = self.Parent:getFullPath().."\\"..fullpath;
	end

	return fullpath;
end

function FileSystemItem.getPath(self)
	local fullpath = self.BasePath;

	if self.Parent and self.Parent.Name:find(":") == nil then
		fullpath = self.Parent:getFullPath().."\\"..fullpath;
	end

	return fullpath;
end

function FileSystemItem.attributeString(self)
	return enum.bitValues(FileAttributes, self.Attributes, 32)
end

FileSystemItem.isArchive = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_ARCHIVE) > 0; 
end

FileSystemItem.isCompressed = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_COMPRESSED) > 0; 
end

FileSystemItem.isDevice = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_DEVICE) > 0; 
end

FileSystemItem.isDirectory = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_DIRECTORY) > 0; 
end

FileSystemItem.isEncrypted = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_ENCRYPTED) > 0; 
end

FileSystemItem.isHidden = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_HIDDEN) > 0; 
end

FileSystemItem.isNormal = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_NORMAL) > 0; 
end

FileSystemItem.isNotContentIndexed = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_NOT_CONTENT_INDEXED) > 0; 
end

FileSystemItem.isOffline = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_OFFLINE) > 0; 
end

FileSystemItem.isReadOnly = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_READONLY) > 0; 
end

FileSystemItem.isReparsePoint = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_REPARSE_POINT) > 0; 
end

FileSystemItem.isSparse = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_SPARSE_FILE) > 0; 
end

FileSystemItem.isSystem = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_SYSTEM) > 0; 
end

FileSystemItem.isTemporary = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_TEMPORARY) > 0; 
end

FileSystemItem.isVirtual = function(self)
	return band(self.Attributes, FileAttributes.FILE_ATTRIBUTE_VIRTUAL) > 0; 
end





-- Iterate over the subitems this item might contain
function FileSystemItem.items(self, pattern)
	pattern = pattern or self:getFullPath().."\\*";
	local lpFileName = w32.toUnicode(pattern);
	--local fInfoLevelId = ffi.C.FindExInfoStandard;
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

	local handle = FsFindFileHandle(rawHandle);
	local firstone = true;

	local closure = function()
		if not handle:isValid() then 
			return nil;
		end

		if firstone then
			firstone = false;
			return FileSystemItem({
				Parent = self;
				Attributes = lpFindFileData.dwFileAttributes;
				Name = w32.toAnsi(lpFindFileData.cFileName);
				Size = (lpFindFileData.nFileSizeHigh * (MAXDWORD+1)) + lpFindFileData.nFileSizeLow;
				});
		end

		local status = k32Lib.FindNextFileW(handle.Handle, lpFindFileData);

		if status == 0 then
			return nil;
		end

		return FileSystemItem({
				Parent = self;
				Attributes = lpFindFileData.dwFileAttributes;
				Name = w32.toAnsi(lpFindFileData.cFileName);
				});

	end
	
	return closure;
end

function FileSystemItem.itemsRecursive(self)
	local stack = Collections.Stack();
	local itemIter = self:items();

	local closure = function()
		while true do
			local anItem = itemIter();
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


function FileSystemItem.streams(self)
	local lpFileName = w32.toUnicode(self:getFullPath());
	local InfoLevel = ffi.C.FindStreamInfoStandard;
	local lpFindStreamData = ffi.new("WIN32_FIND_STREAM_DATA");
	local dwFlags = 0;

	local rawHandle = k32Lib.FindFirstStreamW(lpFileName,
		InfoLevel,
		lpFindStreamData,
		dwFlags);
	local firstone = true;
	local fsHandle = FsHandles.FsFindFileHandle(rawHandle);

	local closure = function()
		if not fsHandle:isValid() then return nil; end

		if firstone then
			firstone = false;
			return w32.toAnsi(lpFindStreamData.cStreamName);
		end
		 
		local status = k32Lib.FindNextStreamW(fsHandle.Handle, lpFindStreamData);
		if status == 0 then
			local err = errorhandling.GetLastError();
			--print("Status: ", err);
			-- if not more streams found, then GetLastError() will return
			-- ERROR_HANDLE_EOF (38)
			return nil;
		end

		return w32.toAnsi(lpFindStreamData.cStreamName);
	end

	return closure;
end

return FileSystemItem;
