--[[
    This file contains various structures that facilitate access to low 
    level Windows data structures without relying on Windows headers.
]]
local ffi = require("ffi")

-- IMAGE_DOS_HEADER is at the beginning of a Windows
-- executable file.
ffi.cdef[[
	struct IMAGE_DOS_HEADER {
		uint16_t e_magic;
		uint16_t e_cblp;
		uint16_t e_cp;
		uint16_t e_crlc;
		uint16_t e_cparhdr;		// size of header in paragraphs
		uint16_t e_minalloc;	// minimum extra paragraphs needed
		uint16_t e_maxalloc;	// maximum extra paragraphs needed
		uint16_t e_ss;			// initial (relative) SS value
		uint16_t e_sp;			// initial SP value
		uint16_t e_csum;		// checksum
		uint16_t e_ip;			// initial IP value
		uint16_t e_cs;			// initial (relative) CS value
		uint16_t e_lfarlc;		// file address of relocation table
		uint16_t e_ovno;		// overlay number
		uint16_t e_res[4];		// reserved words
		uint16_t e_oemid;		// OEM identifier (for e_oeminfo)
		uint16_t e_oeminfo;		// OEM information; e_oemid specific
		uint16_t e_res2[10];	// reserved words
		int32_t e_lfanew;		// file address of new exe header
	  };
]]