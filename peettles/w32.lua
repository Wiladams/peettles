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


local exports = {
    toUnicode = toUnicode,
    toAnsi = toAnsi,

}

return exports