--[[
    Various Win32 definitions
    This is meant to be a minimal set required by functions used in peettles
    This should allow the creation of minimally usable Win32 API calls
]]

local ffi = require("ffi")

local _WIN64 = (ffi.os == "Windows") and ffi.abi("64bit");

ffi.cdef[[
typedef char          	CHAR;
typedef unsigned char	UCHAR;
typedef uint8_t         BYTE;
typedef wchar_t	        WCHAR;
typedef int16_t     	SHORT;
typedef uint16_t        USHORT;
typedef uint16_t		WORD;
typedef int         	INT;
typedef unsigned int	UINT;
typedef int32_t        	LONG;
typedef uint32_t        ULONG;
typedef uint32_t        DWORD;
typedef int64_t     	LONGLONG;
typedef uint64_t		ULONGLONG;
typedef uint64_t    	DWORDLONG;
]]

ffi.cdef[[
	typedef long		BOOL;
    typedef BYTE		BOOLEAN;
]]

ffi.cdef[[
    typedef void *		PVOID;
    typedef PVOID          HANDLE;
    typedef void *			LPVOID;
    typedef const void *	LPCVOID;
    typedef WORD *			LPWORD;
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
// Update Sequence Number

typedef LONGLONG USN;


typedef union _LARGE_INTEGER {
	struct {
		DWORD LowPart;
		LONG HighPart;
	};
	struct {
		DWORD LowPart;
		LONG HighPart;
	} u;
	LONGLONG QuadPart;
} LARGE_INTEGER,  *PLARGE_INTEGER;

typedef struct _ULARGE_INTEGER
{
    ULONGLONG QuadPart;
} 	ULARGE_INTEGER;

typedef ULARGE_INTEGER *PULARGE_INTEGER;

]]

ffi.cdef[[


//typedef DWORD *			LPCOLORREF;

typedef BOOL *			LPBOOL;
//typedef BYTE *      LPBYTE;
typedef char *			LPSTR;
typedef short *			LPWSTR;
//typedef short *			PWSTR;
typedef const WCHAR *	LPCWSTR;
//typedef const WCHAR *	PCWSTR;
//typedef PWSTR *PZPWSTR;
//typedef LPSTR			LPTSTR;





typedef const char *	LPCSTR;
//typedef const char *	PCSTR;
//typedef LPCSTR			LPCTSTR;
//typedef const void *	LPCVOID;


//typedef LONG_PTR		LRESULT;

//typedef LONG_PTR		LPARAM;
//typedef UINT_PTR		WPARAM;


//typedef unsigned char	TBYTE;
//typedef char			TCHAR;

//typedef USHORT			COLOR16;
//typedef DWORD			COLORREF;

// Special types
//typedef WORD			ATOM;
//typedef DWORD			LCID;
//typedef USHORT			LANGID;
]]

ffi.cdef[[
typedef struct {
    unsigned long 	Data1;
    unsigned short	Data2;
    unsigned short	Data3;
    unsigned char	Data4[8];
} GUID, UUID, *LPGUID;
]]

local function readGUID(bs, res)
	res = res or {}

	res.Data1 = bs:readUInt32();
	res.Data2 = bs:readUInt16();
	res.Data3 = bs:readUInt16();
	res.Data4 = bs:readBytes(8);

	return res;
end

local function GUIDToString(guid)
	local res = string.format("%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x",
		guid.Data1, guid.Data2, guid.Data3,
		guid.Data4[0], guid.Data4[1],
		guid.Data4[2], guid.Data4[3], guid.Data4[4],
		guid.Data4[5], guid.Data4[6], guid.Data4[7])

	return res
end


INVALID_HANDLE_VALUE = ffi.cast("HANDLE",ffi.cast("LONG_PTR",-1));
MAXDWORD   = 0xffffffff;  

ffi.cdef[[
typedef struct _FILETIME
{
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} 	FILETIME;

typedef struct _FILETIME *PFILETIME;

typedef struct _FILETIME *LPFILETIME;
]]

--[[
    String handling routines
]]
local k32Lib = ffi.load("kernel32")

ffi.cdef[[
static const int CP_ACP 		= 0;	// default to ANSI code page
static const int CP_OEMCP		= 1;	// default to OEM code page
static const int CP_MACCP		= 2;	// default to MAC code page
static const int CP_THREAD_ACP	= 3;	// current thread's ANSI code page
static const int CP_SYMBOL		= 42;	// SYMBOL translations
]]

-- Desired Access
local GENERIC_READ  = 0x80000000;
local GENERIC_WRITE = 0x40000000;

-- Creation Disposition
local CREATE_NEW = 1;
local CREATE_ALWAYS = 2;
local OPEN_EXISTING = 3;
local OPEN_ALWAYS   = 4;
local TRUNCATE_EXISTING = 5;


local FILE_ATTRIBUTE_ARCHIVE = 0x20;
local FILE_ATTRIBUTE_NORMAL = 0x80;

local FILE_FLAG_RANDOM_ACCESS = 0x10000000;
local FILE_BEGIN            = 0;


ffi.cdef[[
int MultiByteToWideChar(UINT CodePage,
    DWORD    dwFlags,
    LPCSTR   lpMultiByteStr, int cbMultiByte,
    LPWSTR  lpWideCharStr, int cchWideChar);


int WideCharToMultiByte(UINT CodePage,
    DWORD    dwFlags,
	LPCWSTR  lpWideCharStr, int cchWideChar,
    LPSTR   lpMultiByteStr, int cbMultiByte,
    LPCSTR   lpDefaultChar,
    LPBOOL  lpUsedDefaultChar);
]]

ffi.cdef[[
	BOOL CreateDirectoryA(LPCSTR lpPathName, void * lpSecurityAttributes);

]]

--[=[
ffi.cdef[[
typedef union _FILE_SEGMENT_ELEMENT {
	PVOID64   Buffer;
	ULONGLONG Alignment;
  } FILE_SEGMENT_ELEMENT, *PFILE_SEGMENT_ELEMENT;
  
BOOL WriteFileGather(
	HANDLE                  hFile,
	FILE_SEGMENT_ELEMENT [] aSegmentArray,
	DWORD                   nNumberOfBytesToWrite,
	LPDWORD                 lpReserved,
	LPOVERLAPPED            lpOverlapped
  );
]]
--]=]



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
	
	BOOL WriteFile(
		HANDLE       hFile,
		LPCVOID      lpBuffer,
		DWORD        nNumberOfBytesToWrite,
		LPDWORD      lpNumberOfBytesWritten,
		void * lpOverlapped
	);
]]

ffi.cdef[[
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


local function toUnicode(in_Src, nsrcBytes)
	if in_Src == nil then
		return false, "no source specified";
	end
	
	nsrcBytes = nsrcBytes or #in_Src

	-- find out how many characters needed
	local charsneeded = k32Lib.MultiByteToWideChar(ffi.C.CP_ACP, 0, ffi.cast("const char *",in_Src), nsrcBytes, nil, 0);

	if charsneeded < 0 then
		return false;
	end


	local buff = ffi.new("uint16_t[?]", charsneeded+1)

	local charswritten = k32Lib.MultiByteToWideChar(ffi.C.CP_ACP, 0, in_Src, nsrcBytes, buff, charsneeded)
	buff[charswritten] = 0


	return buff, charswritten;
end

local function toAnsi(in_Src, nsrcBytes)
	if in_Src == nil then 
		return false, "no in_Src specified";
	end
	
	local cchWideChar = nsrcBytes or -1;

	-- find out how many characters needed
	local bytesneeded = k32Lib.WideCharToMultiByte(
		ffi.C.CP_ACP, 
		0, 
		ffi.cast("const uint16_t *", in_Src), 
		cchWideChar, 
		nil, 
		0, 
		nil, 
		nil);

--print("BN: ", bytesneeded);

	if bytesneeded <= 0 then
		return false;
	end

	-- create a buffer to stuff the converted string into
	local buff = ffi.new("uint8_t[?]", bytesneeded)

	-- do the actual string conversion
	local byteswritten = k32Lib.WideCharToMultiByte(
		ffi.C.CP_ACP, 
		0, 
		ffi.cast("const uint16_t *", in_Src), 
		cchWideChar, 
		buff, 
		bytesneeded, 
		nil, 
		nil);

	if cchWideChar == -1 then
		return ffi.string(buff, byteswritten-1);
	end

	return ffi.string(buff, byteswritten)
end

local function createDirectory(dirname)
	local ret = ffi.C.CreateDirectoryA(dirname, nil);
		
	if ret == 0 then
		ret = ffi.C.GetLastError();
		return false, ret;
	end

	return ret
end

local function createFile(params)
	if not params then 
		return false, "No parameters specified"
	end

	if not params.FileName then
		return false, "No File Name specified"
	end

	local ret = ffi.C.CreateFileA(params.FileName, 
    	bit.bor(GENERIC_READ, GENERIC_WRITE), 
        0, 
        nil,
        CREATE_ALWAYS, 
        FILE_ATTRIBUTE_NORMAL, 
		nil);

	return ret;
end

local function writeFile(hFile, buff, size)
	local bytesWritten_p = ffi.new("DWORD[1]")

	local ret = ffi.C.WriteFile(hFile,buff,size,bytesWritten_p,nil);

	return ret, bytesWritten_p[0] ~= 0
end

local exports = {
    toUnicode = toUnicode,
    toAnsi = toAnsi,

	createDirectory = createDirectory;
	createFile = createFile;
	writeFile = writeFile;

	GUIDToString = GUIDToString;
	readGUID = readGUID;
}

return exports