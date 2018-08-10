---[[
-- to define resources.  Probably don't really need this
local function MAKEINTRESOURCE(i) 
    return i
    --return (LPSTR)((ULONG_PTR)((WORD)(i)))
end
--]]

local enum = require("peettles.enum")

local DirectoryID = enum {
    IMAGE_DIRECTORY_ENTRY_EXPORT          = 0;   -- Export Directory
    IMAGE_DIRECTORY_ENTRY_IMPORT          = 1;   -- Import Directory
    IMAGE_DIRECTORY_ENTRY_RESOURCE        = 2;   -- Resource Directory
    IMAGE_DIRECTORY_ENTRY_EXCEPTION       = 3;   -- Exception Directory
    IMAGE_DIRECTORY_ENTRY_SECURITY        = 4;   -- Security Directory
    IMAGE_DIRECTORY_ENTRY_BASERELOC       = 5;   -- Base Relocation Table
    IMAGE_DIRECTORY_ENTRY_DEBUG           = 6;   -- Debug Directory
--      IMAGE_DIRECTORY_ENTRY_COPYRIGHT       7;   -- (X86 usage)
    IMAGE_DIRECTORY_ENTRY_ARCHITECTURE    = 7;   -- Architecture Specific Data
    IMAGE_DIRECTORY_ENTRY_GLOBALPTR       = 8;   -- RVA of GP
    IMAGE_DIRECTORY_ENTRY_TLS             = 9;   -- TLS Directory
    IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG    = 10;   -- Load Configuration Directory
    IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT   = 11;   -- Bound Import Directory in headers
    IMAGE_DIRECTORY_ENTRY_IAT            = 12;   -- Import Address Table
    IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT   = 13;   -- Delay Load Import Descriptors
    IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR = 14;   -- COM Runtime descriptor
}

-- Optional Header, DllCharacteristics
local DllCharacteristics = enum {
    IMAGE_DLL_RESERVED1                             = 0x0001,
    IMAGE_DLL_RESERVED2                             = 0x0002,
    IMAGE_DLL_RESERVED3                             = 0x0004,
    IMAGE_DLL_RESERVED4                             = 0x0008,
    IMAGE_DLLCHARACTERISTICS_HIGH_ENTROPY_VA        = 0x0020,
    IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE          = 0x0040,
    IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY       = 0x0080,
    IMAGE_DLL_CHARACTERISTICS_NX_COMPAT             = 0x0100,
    IMAGE_DLLCHARACTERISTICS_NO_ISOLATION           = 0x0200,
    IMAGE_DLLCHARACTERISTICS_NO_SEH                 = 0x0400,
    IMAGE_DLLCHARACTERISTICS_NO_BIND                = 0x0800,
    IMAGE_DLLCHARACTERISTICS_APPCONTAINER           = 0x1000,
    IMAGE_DLLCHARACTERISTICS_WDM_DRIVER             = 0x2000,
    IMAGE_DLLCHARACTERISTICS_GUARD_CF               = 0x4000,
    IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE  = 0x8000,
}

-- Optional Header, Subsystem field of
local Subsystem = enum {
    IMAGE_SUBSYSTEM_UNKNOWN                 = 0,
    IMAGE_SUBSYSTEM_NATIVE                  = 1,
    IMAGE_SUBSYSTEM_WINDOWS_GUI             = 2,
    IMAGE_SUBSYSTEM_WINDOWS_CUI             = 3,
    IMAGE_SUBSYSTEM_OS2_CUI                 = 5,
    IMAGE_SUBSYSTEM_POSIX_CUI               = 7,
    IMAGE_SUBSYSTEM_NATIVE_WINDOWS          = 8,
    IMAGE_SUBSYSTEM_WINDOWS_CE_GUI          = 9,
    IMAGE_SUBSYSTEM_EFI_APPLICATION         = 10,
    IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER = 11,
    IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER      = 12,
    IMAGE_SUBSYSTEM_EFI_ROM                 = 13,
    IMAGE_SUBSYSTEM_XBOX                    = 14,
    IMAGE_SUBSYSTEM_WINDOWS_BOOT_APPLICATION = 16,
}

local OptHeaderMagic = enum {
    IMAGE_MAGIC_HEADER_PE32         = 0x10b,
    IMAGE_MAGIC_HEADER_PE32_PLUS    = 0x20b,
    IMAGE_MAGIC_HEADER_ROM          = 0x107,
}

-- COFF Header, Characteristics field
local Characteristics = enum {
    IMAGE_FILE_RELOCS_STRIPPED          = 0x0001,
    IMAGE_FILE_EXECUTABLE_IMAGE         = 0x0002,
    IMAGE_FILE_LINE_NUMS_STRIPPED       = 0x0004,
    IMAGE_FILE_LOCAL_SYMS_STRIPPED      = 0x0008,
    IMAGE_FILE_AGGRESSIVE_WS_TRIM       = 0x0010,
    IMAGE_FILE_LARGE_ADDRESS_AWARE      = 0x0020,
    IMAGE_FILE_RESERVED                 = 0x0040,
    IMAGE_FILE_BYTES_REVERSED_LO        = 0x0080,
    IMAGE_FILE_32BIT_MACHINE            = 0x0100,
    IMAGE_FILE_DEBUG_STRIPPED           = 0x0200,
    IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP  = 0x0400,
    IMAGE_FILE_NET_RUN_FROM_SWAP        = 0x0800,
    IMAGE_FILE_SYSTEM                   = 0x1000,
    IMAGE_FILE_DLL                      = 0x2000,
    IMAGE_FILE_UP_SYSTEM_ONLY           = 0x4000,
    IMAGE_FILE_BYTES_REVERSED_HI        = 0x8000,
}

-- COFF Header, MachineType field
local MachineType = enum {
    IMAGE_FILE_MACHINE_UNKNOWN      = 0x0,
    IMAGE_FILE_MACHINE_I386         = 0x14c,
    IMAGE_FILE_MACHINE_R4000        = 0x166,
    IMAGE_FILE_MACHINE_WCEMIPSV2    = 0x169,
    IMAGE_FILE_MACHINE_SH3          = 0x1a2,
    IMAGE_FILE_MACHINE_SH3D         = 0x1a3,
    IMAGE_FILE_MACHINE_SH4          = 0x1a6,
    IMAGE_FILE_MACHINE_SH5          = 0x1a8,
    IMAGE_FILE_MACHINE_ARM          = 0x1c0,
    IMAGE_FILE_MACHINE_THUMB        = 0x1c2,
    IMAGE_FILE_MACHINE_ARMNT        = 0x1c4,
    IMAGE_FILE_MACHINE_AM33         = 0x1d3,
    IMAGE_FILE_MACHINE_POWERPC      = 0x1f0,
    IMAGE_FILE_MACHINE_POWERPCFP    = 0x1f1,
    IMAGE_FILE_MACHINE_IA64         = 0x200,
    IMAGE_FILE_MACHINE_MIPS1        = 0x266,
    IMAGE_FILE_MACHINE_MIPSF        = 0x366,
    IMAGE_FILE_MACHINE_MIPSF        = 0x466,
    IMAGE_FILE_MACHINE_EBC          = 0xebc,
    IMAGE_FILE_MACHINE_RISCV32      = 0x5032,
    IMAGE_FILE_MACHINE_RISCV64      = 0x5064,
    IMAGE_FILE_MACHINE_RISCV128     = 0x5128,
    IMAGE_FILE_MACHINE_AMD64        = 0x8664,
    IMAGE_FILE_MACHINE_M32R         = 0x9041,
    IMAGE_FILE_MACHINE_ARM64        = 0xaa64,
}

-- Section Flags, of Characteristics field, of Section Header
local SectionCharacteristics = enum {
    IMAGE_SCN_RESERVED_1        = 0x00000000;
    IMAGE_SCN_RESERVED_2        = 0x00000001;
    IMAGE_SCN_RESERVED_3        = 0x00000002;
    IMAGE_SCN_RESERVED_4        = 0x00000004;
    IMAGE_SCN_TYPE_NO_PAD       = 0x00000008;
    IMAGE_SCN_RESERVED_5            = 0x00000010;
    IMAGE_SCN_CNT_CODE              = 0x00000020 ;
    IMAGE_SCN_CNT_INITIALIZED_DATA  = 0x00000040 ;
    IMAGE_SCN_CNT_UNINITIALIZED_DATA= 0x00000080 ;
    IMAGE_SCN_LNK_OTHER         = 0x00000100 ;
    IMAGE_SCN_LNK_INFO          = 0x00000200 ;
    IMAGE_SCN_RESERVED_6        = 0x00000400;
    IMAGE_SCN_LNK_REMOVE        = 0x00000800 ;
    IMAGE_SCN_LNK_COMDAT        = 0x00001000 ;
    IMAGE_SCN_GPREL             = 0x00008000 ;
    IMAGE_SCN_MEM_PURGEABLE     = 0x00020000 ;
    --IMAGE_SCN_MEM_16BIT         = 0x00020000 ;
    IMAGE_SCN_MEM_LOCKED        = 0x00040000 ;
    IMAGE_SCN_MEM_PRELOAD       = 0x00080000 ;
    -- Alignment values pulled out into SectionAlignment
    IMAGE_SCN_LNK_NRELOC_OVFL   = 0x01000000 ;
    IMAGE_SCN_MEM_DISCARDABLE   = 0x02000000 ;
    IMAGE_SCN_MEM_NOT_CACHED    = 0x04000000 ;
    IMAGE_SCN_MEM_NOT_PAGED     = 0x08000000 ;
    IMAGE_SCN_MEM_SHARED        = 0x10000000 ;
    IMAGE_SCN_MEM_EXECUTE       = 0x20000000 ;
    IMAGE_SCN_MEM_READ          = 0x40000000 ;
    IMAGE_SCN_MEM_WRITE         = 0x80000000 ;
}

local SectionAlignment = enum {
IMAGE_SCN_ALIGN_1BYTES      = 0x00100000 ;
IMAGE_SCN_ALIGN_2BYTES      = 0x00200000 ;
IMAGE_SCN_ALIGN_4BYTES      = 0x00300000 ;
IMAGE_SCN_ALIGN_8BYTES      = 0x00400000 ;
IMAGE_SCN_ALIGN_16BYTES     = 0x00500000 ;
IMAGE_SCN_ALIGN_32BYTES     = 0x00600000 ;
IMAGE_SCN_ALIGN_64BYTES     = 0x00700000 ;
IMAGE_SCN_ALIGN_128BYTES    = 0x00800000 ;
IMAGE_SCN_ALIGN_256BYTES    = 0x00900000 ;
IMAGE_SCN_ALIGN_512BYTES    = 0x00A00000 ;
IMAGE_SCN_ALIGN_1024BYTES   = 0x00B00000 ;
IMAGE_SCN_ALIGN_2048BYTES   = 0x00C00000 ;
IMAGE_SCN_ALIGN_4096BYTES   = 0x00D00000 ;
IMAGE_SCN_ALIGN_8192BYTES   = 0x00E00000 ;
};

-- Related to COFF files
-- Import Type
local ImportType = enum {
    [0] = "IMPORT_CODE";
    "IMPORT_DATA";
    "IMPORT_CONST";
}

local ImportNameType = enum {
    [0] = "IMPORT_ORDINAL";
    "IMPORT_NAME";
    "IMPORT_NAME_NOPREFIX";
    "IMPORT_NAME_UNDECORATE";
}

-- Symbol related enums
local SymBaseType = enum {
    [0] = "IMAGE_SYM_TYPE_NULL";
    "IMAGE_SYM_TYPE_VOID";
    "IMAGE_SYM_TYPE_CHAR";
    "IMAGE_SYM_TYPE_SHORT";
    "IMAGE_SYM_TYPE_INT";
    "IMAGE_SYM_TYPE_LONG";
    "IMAGE_SYM_TYPE_FLOAT";
    "IMAGE_SYM_TYPE_DOUBLE";
    "IMAGE_SYM_TYPE_STRUCT";
    "IMAGE_SYM_TYPE_UNION";
    "IMAGE_SYM_TYPE_ENUM";
    "IMAGE_SYM_TYPE_MOE";
    "IMAGE_SYM_TYPE_BYTE";
    "IMAGE_SYM_TYPE_WORD";
    "IMAGE_SYM_TYPE_UINT";
    "IMAGE_SYM_TYPE_DWORD";
}

local SymComplexType = enum {
    [0] = "IMAGE_SYM_DTYPE_NULL";
    "IMAGE_SYM_DTYPE_POINTER";
    "IMAGE_SYM_DTYPE_FUNCTION";
    "IMAGE_SYM_DTYPE_ARRAY";
};

local SymStorageClass = enum {
    [0XFF] = "IMAGE_SYM_CLASS_END_OF_FUNCTION";
    [0] = "IMAGE_SYM_CLASS_NULL";
    "IMAGE_SYM_CLASS_AUTOMATIC";
    "IMAGE_SYM_CLASS_EXTERNAL";
    "IMAGE_SYM_CLASS_STATIC";
    "IMAGE_SYM_CLASS_REGISTER";
    "IMAGE_SYM_CLASS_EXTERNAL_DEF";
    "IMAGE_SYM_CLASS_LABEL";
    "IMAGE_SYM_CLASS_UNDEFINED_LABEL";
    "IMAGE_SYM_CLASS_MEMBER_OF_STRUCT";
    "IMAGE_SYM_CLASS_ARGUMENT";
    "IMAGE_SYM_CLASS_STRUCT_TAG";
    "IMAGE_SYM_CLASS_MEMBER_OF_UNION";
    "IMAGE_SYM_CLASS_UNION_TAG";
    "IMAGE_SYM_CLASS_TYPE_DEFINITION";
    "IMAGE_SYM_CLASS_UNDEFINED_STATIC";
    "IMAGE_SYM_CLASS_ENUM_TAG";
    "IMAGE_SYM_CLASS_MEMBER_OF_ENUM";
    "IMAGE_SYM_CLASS_REGISTER_PARAM";
    "IMAGE_SYM_CLASS_BIT_FIELD";
    [100] = "IMAGE_SYM_CLASS_BLOCK";
    "IMAGE_SYM_CLASS_FUNCTION";
    "IMAGE_SYM_CLASS_END_OF_STRUCT";
    "IMAGE_SYM_CLASS_FILE";
    "IMAGE_SYM_CLASS_SECTION";
    "IMAGE_SYM_CLASS_WEAK_EXTERNAL";
    [107] = "IMAGE_SYM_CLASS_CLR_TOKEN";
};


-- Resource Types
local DIFFERENCE   =  11
local ResourceTypes = enum {
    RT_CURSOR          = MAKEINTRESOURCE(1);
    RT_BITMAP          = MAKEINTRESOURCE(2);
    RT_ICON            = MAKEINTRESOURCE(3);
    RT_MENU            = MAKEINTRESOURCE(4);
    RT_DIALOG          = MAKEINTRESOURCE(5);
    RT_STRING          = MAKEINTRESOURCE(6);
    RT_FONTDIR         = MAKEINTRESOURCE(7);
    RT_FONT            = MAKEINTRESOURCE(8);
    RT_ACCELERATOR     = MAKEINTRESOURCE(9);
    RT_RCDATA          = MAKEINTRESOURCE(10);
    RT_MESSAGETABLE    = MAKEINTRESOURCE(11);


    RT_GROUP_CURSOR     = 1 + 11;         -- MAKEINTRESOURCE((ULONG_PTR)RT_CURSOR + DIFFERENCE);
    RT_GROUP_ICON       = 3 + 11;       -- MAKEINTRESOURCE((ULONG_PTR)RT_ICON + DIFFERENCE);
    RT_VERSION          = MAKEINTRESOURCE(16);
    RT_DLGINCLUDE       = MAKEINTRESOURCE(17);

    RT_PLUGPLAY         = MAKEINTRESOURCE(19);
    RT_VXD              = MAKEINTRESOURCE(20);
    RT_ANICURSOR        = MAKEINTRESOURCE(21);
    RT_ANIICON          = MAKEINTRESOURCE(22);

    RT_HTML             = MAKEINTRESOURCE(23);

    RT_MANIFEST                             = 24;
}


--[[
    Manifest related
CREATEPROCESS_MANIFEST_RESOURCE_ID      = 1;
ISOLATIONAWARE_MANIFEST_RESOURCE_ID     = 2;
ISOLATIONAWARE_NOSTATICIMPORT_MANIFEST_RESOURCE_ID = 3;
MINIMUM_RESERVED_MANIFEST_RESOURCE_ID   = 1;   
MAXIMUM_RESERVED_MANIFEST_RESOURCE_ID   = 16;  
--]]



local exports = {
    DirectoryID         = DirectoryID;
    DllCharacteristics  = DllCharacteristics,
    Subsystem           = Subsystem,
    OptHeaderMagic      = OptHeaderMagic,
    Characteristics     = Characteristics,
    MachineType         = MachineType,
    ResourceTypes       = ResourceTypes,
    SectionCharacteristics = SectionCharacteristics;

    SymStorageClass = SymStorageClass;
    SymBaseType = SymBaseType;
    SymComplexType = SymComplexType;
}

setmetatable(exports, {
    __call = function(self, ...)
        for k,v in pairs(exports) do
            rawset(_G, k, v);
        end
    end,
    })


return exports
