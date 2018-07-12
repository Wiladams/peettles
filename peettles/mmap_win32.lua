--[[
	mmap is the rough equivalent of the mmap() function on Linux
	This basically allows you to memory map a file, which means you 
	can access a pointer to the file's contents without having to 
	go through IO routines.

	Usage:
	local m = mmap(filename)
	local ptr = m:getMap()

	print(ffi.string(ptr, #m))

	reference for win32 constants
	http://doc.pcsoft.fr/en-US/?6510001
--]]

local ffi = require "ffi"
local C = ffi.C
local bit = require "bit"

local _WIN64 = (ffi.os == "Windows") and ffi.abi("64bit");


ffi.cdef[[
	typedef char		CHAR;
	typedef int			BOOL;
	typedef int16_t		SHORT;
	typedef uint32_t	DWORD;
	typedef int32_t		LONG;
	typedef int64_t		LONGLONG;
	typedef void *		PVOID;

    typedef PVOID          HANDLE;
    typedef void *			LPVOID;
    typedef const void *	LPCVOID;
    typedef DWORD *			LPDWORD;
	typedef const char *	LPCSTR;
]]

if _WIN64 then
ffi.cdef[[
	typedef int64_t		INT_PTR;
	typedef int64_t		LONG_PTR, *PLONG_PTR;
	typedef uint64_t	ULONG_PTR, *PULONG_PTR;
]]
else
ffi.cdef[[
	typedef int 			INT_PTR;
	typedef long			LONG_PTR, *PLONG_PTR;
    typedef unsigned long   ULONG_PTR, *PULONG_PTR;
]]
end

ffi.cdef[[
    typedef ULONG_PTR		SIZE_T, *PSIZE_T;
    typedef LONG_PTR        SSIZE_T, *PSSIZE_T;
]]

ffi.cdef[[
    // Basic file handling
    HANDLE CreateFileA(
        LPCSTR lpFileName,
        DWORD dwDesiredAccess,
        DWORD dwShareMode,
        void * lpSecurityAttributes,
        DWORD dwCreationDisposition,
        DWORD dwFlagsAndAttributes,
        HANDLE hTemplateFile
    );

    BOOL DeleteFileA(LPCSTR lpFileName);

    DWORD GetFileSize(HANDLE hFile, LPDWORD lpFileSizeHigh);

    // File mapping
    HANDLE CreateFileMappingA(
		HANDLE hFile,
		void * lpAttributes,
		DWORD flProtect,
		DWORD dwMaximumSizeHigh,
		DWORD dwMaximumSizeLow,
		LPCSTR lpName
    );

    LPVOID MapViewOfFile(
    HANDLE hFileMappingObject,
    DWORD dwDesiredAccess,
    DWORD dwFileOffsetHigh,
    DWORD dwFileOffsetLow,
    SIZE_T dwNumberOfBytesToMap
    );

    BOOL UnmapViewOfFile(LPCVOID lpBaseAddress);

    BOOL CloseHandle(HANDLE hObject);

    DWORD GetLastError(void);
]]

local ERROR_ACCESS_DENIED = 5
local ERROR_ALREADY_EXISTS = 183
local ERROR_INVALID_HANDLE = 6
local ERROR_INVALID_PARAMETER = 87

local GENERIC_READ  = 0x80000000
local GENERIC_WRITE = 0x40000000

local OPEN_EXISTING = 3
local OPEN_ALWAYS   = 4

local FILE_ATTRIBUTE_ARCHIVE = 0x20
local FILE_FLAG_RANDOM_ACCESS = 0x10000000
local FILE_BEGIN            = 0

--local FILE_MAP_EXECUTE	= 0;
local FILE_MAP_READ		= 0x04;
local FILE_MAP_WRITE	= 0x02;
--local FILE_MAP_TARGETS_INVALID = 0
local FILE_MAP_ALL_ACCESS = 0xf001f

local PAGE_READONLY         = 0x02; 
local PAGE_READWRITE        = 0x4




local INVALID_HANDLE_VALUE = ffi.cast("HANDLE",ffi.cast("LONG_PTR",-1));

--print("INVALID_HANDLE_VALUE: ", INVALID_HANDLE_VALUE)

local mmap = {}
mmap.__index = mmap
local new_map


function mmap:__new(filename, newsize)
	newsize = newsize or 0
	local m = ffi.new(self, #filename+1)
	
    -- Open file
    --print("Open File")
    m.filehandle = ffi.C.CreateFileA(filename, 
    --bit.bor(GENERIC_READ, GENERIC_WRITE), 
            bit.bor(GENERIC_READ), 
        0, 
        nil,
        OPEN_EXISTING, 
        bit.bor(FILE_ATTRIBUTE_ARCHIVE, FILE_FLAG_RANDOM_ACCESS), 
        nil)
    
    --print("    File Handle: ", m.filehandle)
    
    if m.filehandle == INVALID_HANDLE_VALUE then
		error("Could not create/open file for mmap: "..tostring(ffi.C.GetLastError()))
	end
	
    -- Set file size if new
    --print("GET File Size")
    local exists = true;
    if exists then
		local fsize = ffi.C.GetFileSize(m.filehandle, nil)
        --print("    Size: ", fsize)
		if fsize == 0 then
			-- Windows will error if mapping a 0-length file, fake a new one
			exists = false
			m.size = newsize
		else
			m.size = fsize
		end
	else
		m.size = newsize
	end
	m.existed = exists
	
	-- Open mapping
    m.maphandle = ffi.C.CreateFileMappingA(m.filehandle, nil, PAGE_READONLY, 0, m.size, nil)
    --print("CREATE File Mapping: ", m.maphandle)
	if m.maphandle == nil then
		error("Could not create file map: "..tostring(ffi.C.GetLastError()))
	end
	
	-- Open view
	m.map = ffi.C.MapViewOfFile(m.maphandle, FILE_MAP_READ, 0, 0, 0)
	--print("MAP VIEW: ", m.map)
	if m.map == nil then
		error("Could not map: "..tostring(ffi.C.GetLastError()))
	end
	
	-- Copy filename (for delete)
	ffi.copy(m.filename, filename)
	
	return m
end

function mmap:getPointer()
	return self.map
end

function mmap:__len()
	return self.size
end

function mmap:close(no_ungc)
	if self.map ~= nil then
		ffi.C.UnmapViewOfFile(self.map)
		self.map = nil
	end
	if self.maphandle ~= nil then
		ffi.C.CloseHandle(self.maphandle)
		self.maphandle = nil
	end
	if self.filehandle ~= nil then
		ffi.C.CloseHandle(self.filehandle)
		self.filehandle = nil
	end
	
	if not no_ungc then ffi.gc(self, nil) end
end

function mmap:__gc()
	self:close(true)
end

function mmap:delete()
	self:close()
	file.DeleteFileA(self.filename)
end

local new_map = ffi.metatype([[struct {
	short existed;
	void* filehandle;
	void* maphandle;
	void* map;
	size_t size;
	char filename[?];
}]], mmap)

return new_map

