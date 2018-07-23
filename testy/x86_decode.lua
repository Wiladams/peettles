--[[
    Reference from libcpu.org project

    This stuff is used to decode an instruction stream
    just another approach.

    I like this approach because it breaks things down into 
    component parts, where you can still see explicitly 
    the addressing modes, and whatnot
]]
package.path = "../?.lua;"..package.path

local ffi = require("ffi")
local enum = require("peettles.enum")


local x86_operand_type = enum {
	OP_IMM,
	OP_MEM,
	OP_MEM_DISP,
	OP_REG,
	OP_SEG_REG,
	OP_REL,
};

local x86_seg_override = enum {
	NO_OVERRIDE,
	ES_OVERRIDE,
	CS_OVERRIDE,
	SS_OVERRIDE,
	DS_OVERRIDE,
};

local x86_rep_prefix = enum {
	NO_PREFIX,
	REPNZ_PREFIX,
	REPZ_PREFIX,
};

--[[
struct x86_operand {
	enum x86_operand_type	type;
	uint8_t			reg;
	int32_t			disp;		// address displacement can be negative 
	union {
		uint32_t		imm;
		int32_t			rel;
	};
};
--]]
local function x86_operand()
    return {
        type = 0;
        reg = 0;
        disp = 0;   -- address displacement can be negative
        imm = 0;
        rel = 0;
    }
end



ffi.cdef[[
enum x86_instr_flags {
	MOD_RM			= (1U << 8),
	DIR_REVERSED	= (1U << 9),

	// Operand sizes 
	WIDTH_BYTE		= (1U << 10),	// 8 bits 
	WIDTH_FULL		= (1U << 11),	// 16 bits or 32 bits 
	WIDTH_MASK		= WIDTH_BYTE|WIDTH_FULL,

	// Source operand 
	SRC_NONE		= (1U << 12),

	SRC_IMM			= (1U << 13),
	SRC_IMM8		= (1U << 14),
	IMM_MASK		= SRC_IMM|SRC_IMM8,

	SRC_REL			= (1U << 15),
	REL_MASK		= SRC_REL,

	SRC_REG			= (1U << 16),
	SRC_SEG_REG		= (1U << 17),
	SRC_ACC			= (1U << 18),
	SRC_MEM			= (1U << 19),
	SRC_MOFFSET		= (1U << 20),
	SRC_MEM_DISP_BYTE	= (1U << 21),
	SRC_MEM_DISP_FULL	= (1U << 22),
	SRC_MASK		= SRC_NONE|IMM_MASK|REL_MASK|SRC_REG|SRC_SEG_REG|SRC_ACC|SRC_MEM|SRC_MOFFSET|SRC_MEM_DISP_BYTE|SRC_MEM_DISP_FULL,

	// Destination operand 
	DST_NONE		= (1U << 23),
	DST_REG			= (1U << 24),
	DST_ACC			= (1U << 25),	// AL/AX
	DST_MEM			= (1U << 26),
	DST_MOFFSET		= (1U << 27),
	DST_MEM_DISP_BYTE	= (1U << 28),	// 8 bits 
	DST_MEM_DISP_FULL	= (1U << 29),	// 16 bits or 32 bits 
	DST_MASK		= DST_NONE|DST_REG|DST_ACC|DST_MOFFSET|DST_MEM|DST_MEM_DISP_BYTE|DST_MEM_DISP_FULL,

	MEM_DISP_MASK		= SRC_MEM|SRC_MEM_DISP_BYTE|SRC_MEM_DISP_FULL|DST_MEM|DST_MEM_DISP_BYTE|DST_MEM_DISP_FULL,

	MOFFSET_MASK		= SRC_MOFFSET|DST_MOFFSET,

	GROUP_2			= (1U << 30),

	GROUP_MASK		= GROUP_2,
};


//	Addressing modes.
enum x86_addmode {
	ADDMODE_ACC_MOFFSET	= SRC_ACC|DST_MOFFSET,		// AL/AX -> moffset 
	ADDMODE_ACC_REG		= SRC_ACC|DST_REG,		// AL/AX -> reg 
	ADDMODE_IMM		= SRC_IMM|DST_NONE,		// immediate operand 
	ADDMODE_IMM8_RM		= SRC_IMM8|MOD_RM|DIR_REVERSED,	// immediate -> register/memory 
	ADDMODE_IMM_ACC		= SRC_IMM|DST_ACC,		// immediate -> AL/AX 
	ADDMODE_IMM_REG		= SRC_IMM|DST_REG,		// immediate -> register 
	ADDMODE_IMPLIED		= SRC_NONE|DST_NONE,		// no operands 
	ADDMODE_MOFFSET_ACC	= SRC_MOFFSET|DST_ACC,		// moffset -> AL/AX 
	ADDMODE_REG		= SRC_REG|DST_NONE,		// register 
	ADDMODE_SEG_REG		= SRC_SEG_REG|DST_NONE,		// segment register 
	ADDMODE_REG_RM		= SRC_REG|MOD_RM|DIR_REVERSED,	// register -> register/memory 
	ADDMODE_REL		= SRC_REL|DST_NONE,		// relative 
	ADDMODE_RM_REG		= DST_REG|MOD_RM,		// register/memory -> register 
};

struct x86_instr {
	unsigned long		nr_bytes;

	uint8_t			opcode;		// Opcode byte 
	uint8_t			width;
	uint8_t			mod;		// Mod 
	uint8_t			rm;		// R/M 
	uint8_t			reg_opc;	// Reg/Opcode 
	uint32_t		disp;		// Address displacement 
	union {
		uint32_t		imm_data;	// Immediate data 
		int32_t			rel_data;	// Relative address data 
	};

	unsigned long		type;		// See enum x86_instr_types 
	unsigned long		flags;		// See enum x86_instr_flags 
	enum x86_seg_override	seg_override;
	enum x86_rep_prefix	rep_prefix;
	unsigned char		lock_prefix;
	struct x86_operand	src;
	struct x86_operand	dst;
};
]]


/*
 * libcpu: x86_decode.cpp
 *
 * instruction decoding
 */

#include "libcpu.h"
#include "x86_isa.h"



-- First byte of an element in 'decode_table' is the instruction type.

local X86_INSTR_TYPE_MASK	= 0xff;

local INSTR_UNDEFINED		= 0;

local Jb = (ADDMODE_REL | WIDTH_BYTE)
local Jv = (ADDMODE_REL | WIDTH_FULL)

local decode_table = ffi.new("static const uint32_t[256]", {
	/*[0x0]*/	INSTR_ADD | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x1]*/	INSTR_ADD | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x2]*/	INSTR_ADD | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x3]*/	INSTR_ADD | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x4]*/	INSTR_ADD | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0x5]*/	INSTR_ADD | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0x6]*/	INSTR_PUSH | ADDMODE_SEG_REG /* ES */ | WIDTH_FULL,
	/*[0x7]*/	INSTR_POP | ADDMODE_SEG_REG /* ES */ | WIDTH_FULL,
	/*[0x8]*/	INSTR_OR | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x9]*/	INSTR_OR | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0xA]*/	INSTR_OR | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0xB]*/	INSTR_OR | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0xC]*/	INSTR_OR | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0xD]*/	INSTR_OR | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0xE]*/	INSTR_PUSH | ADDMODE_SEG_REG /* CS */ | WIDTH_FULL,
	/*[0xF]*/	INSTR_UNDEFINED,
	/*[0x10]*/	INSTR_ADC | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x11]*/	INSTR_ADC | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x12]*/	INSTR_ADC | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x13]*/	INSTR_ADC | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x14]*/	INSTR_ADC | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0x15]*/	INSTR_ADC | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0x16]*/	INSTR_PUSH | ADDMODE_SEG_REG /* SS */ | WIDTH_FULL,
	/*[0x17]*/	INSTR_POP | ADDMODE_SEG_REG /* SS */ | WIDTH_FULL,
	/*[0x18]*/	INSTR_SBB | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x19]*/	INSTR_SBB | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x1A]*/	INSTR_SBB | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x1B]*/	INSTR_SBB | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x1C]*/	INSTR_SBB | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0x1D]*/	INSTR_SBB | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0x1E]*/	INSTR_PUSH | ADDMODE_SEG_REG /* DS */ | WIDTH_FULL,
	/*[0x1F]*/	INSTR_POP | ADDMODE_SEG_REG /* DS */ | WIDTH_FULL,
	/*[0x20]*/	INSTR_AND | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x21]*/	INSTR_AND | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x22]*/	INSTR_AND | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x23]*/	INSTR_AND | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x24]*/	INSTR_AND | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0x25]*/	INSTR_AND | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0x26]*/	0 /* ES_OVERRIDE */,
	/*[0x27]*/	INSTR_DAA | ADDMODE_IMPLIED,
	/*[0x28]*/	INSTR_SUB | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x29]*/	INSTR_SUB | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x2A]*/	INSTR_SUB | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x2B]*/	INSTR_SUB | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x2C]*/	INSTR_SUB | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0x2D]*/	INSTR_SUB | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0x2E]*/	0 /* CS_OVERRIDE */,
	/*[0x2F]*/	INSTR_DAS | ADDMODE_IMPLIED,
	/*[0x30]*/	INSTR_XOR | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x31]*/	INSTR_XOR | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x32]*/	INSTR_XOR | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x33]*/	INSTR_XOR | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x34]*/	INSTR_XOR | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0x35]*/	INSTR_XOR | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0x36]*/	0 /* SS_OVERRIDE */,
	/*[0x37]*/	INSTR_AAA | ADDMODE_IMPLIED,
	/*[0x38]*/	INSTR_CMP | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x39]*/	INSTR_CMP | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x3A]*/	INSTR_CMP | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x3B]*/	INSTR_CMP | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x3C]*/	INSTR_CMP | ADDMODE_IMM_ACC | WIDTH_BYTE,
	/*[0x3D]*/	INSTR_CMP | ADDMODE_IMM_ACC | WIDTH_FULL,
	/*[0x3E]*/	0 /* DS_OVERRIDE */,
	/*[0x3F]*/	INSTR_AAS | ADDMODE_IMPLIED,
	/*[0x40]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x41]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x42]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x43]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x44]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x45]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x46]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x47]*/	INSTR_INC | ADDMODE_REG | WIDTH_FULL,
	/*[0x48]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x49]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x4A]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x4B]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x4C]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x4D]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x4E]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x4F]*/	INSTR_DEC | ADDMODE_REG | WIDTH_FULL,
	/*[0x50]*/	INSTR_PUSH | ADDMODE_REG /* AX */ | WIDTH_FULL,
	/*[0x51]*/	INSTR_PUSH | ADDMODE_REG /* CX */ | WIDTH_FULL,
	/*[0x52]*/	INSTR_PUSH | ADDMODE_REG /* DX */ | WIDTH_FULL,
	/*[0x53]*/	INSTR_PUSH | ADDMODE_REG /* BX */ | WIDTH_FULL,
	/*[0x54]*/	INSTR_PUSH | ADDMODE_REG /* SP */ | WIDTH_FULL,
	/*[0x55]*/	INSTR_PUSH | ADDMODE_REG /* BP */ | WIDTH_FULL,
	/*[0x56]*/	INSTR_PUSH | ADDMODE_REG /* SI */ | WIDTH_FULL,
	/*[0x57]*/	INSTR_PUSH | ADDMODE_REG /* DI */ | WIDTH_FULL,
	/*[0x58]*/	INSTR_POP | ADDMODE_REG /* AX */  | WIDTH_FULL,
	/*[0x59]*/	INSTR_POP | ADDMODE_REG /* CX */  | WIDTH_FULL,
	/*[0x5A]*/	INSTR_POP | ADDMODE_REG /* DX */  | WIDTH_FULL,
	/*[0x5B]*/	INSTR_POP | ADDMODE_REG /* BX */  | WIDTH_FULL,
	/*[0x5C]*/	INSTR_POP | ADDMODE_REG /* SP */  | WIDTH_FULL,
	/*[0x5D]*/	INSTR_POP | ADDMODE_REG /* BP */  | WIDTH_FULL,
	/*[0x5E]*/	INSTR_POP | ADDMODE_REG /* SI */  | WIDTH_FULL,
	/*[0x5F]*/	INSTR_POP | ADDMODE_REG /* DI */  | WIDTH_FULL,
	/*[0x60]*/	INSTR_PUSHA | ADDMODE_IMPLIED,		/* 80186 */
	/*[0x61]*/	INSTR_POPA | ADDMODE_IMPLIED,		/* 80186 */
	/*[0x62]*/	INSTR_UNDEFINED,
	/*[0x63]*/	INSTR_UNDEFINED,
	/*[0x64]*/	INSTR_UNDEFINED,
	/*[0x65]*/	INSTR_UNDEFINED,
	/*[0x66]*/	INSTR_UNDEFINED,
	/*[0x67]*/	INSTR_UNDEFINED,
	/*[0x68]*/	INSTR_UNDEFINED,
	/*[0x69]*/	INSTR_UNDEFINED,
	/*[0x6A]*/	INSTR_UNDEFINED,
	/*[0x6B]*/	INSTR_UNDEFINED,
	/*[0x6C]*/	INSTR_UNDEFINED,
	/*[0x6D]*/	INSTR_UNDEFINED,
	/*[0x6E]*/	INSTR_UNDEFINED,
	/*[0x6F]*/	INSTR_UNDEFINED,
	/*[0x70]*/	INSTR_JO  | Jb,
	/*[0x71]*/	INSTR_JNO | Jb,
	/*[0x72]*/	INSTR_JB  | Jb,
	/*[0x73]*/	INSTR_JNB | Jb,
	/*[0x74]*/	INSTR_JZ  | Jb,
	/*[0x75]*/	INSTR_JNE | Jb,
	/*[0x76]*/	INSTR_JBE | Jb,
	/*[0x77]*/	INSTR_JA  | Jb,
	/*[0x78]*/	INSTR_JS  | Jb,
	/*[0x79]*/	INSTR_JNS | Jb,
	/*[0x7A]*/	INSTR_JPE | Jb,
	/*[0x7B]*/	INSTR_JPO | Jb,
	/*[0x7C]*/	INSTR_JL  | Jb,
	/*[0x7D]*/	INSTR_JGE | Jb,
	/*[0x7E]*/	INSTR_JLE | Jb,
	/*[0x7F]*/	INSTR_JG  | Jb,
	/*[0x80]*/	0,
	/*[0x81]*/	0,
	/*[0x82]*/	0,
	/*[0x83]*/	0,
	/*[0x84]*/	INSTR_TEST | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x85]*/	INSTR_TEST | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x86]*/	0,
	/*[0x87]*/	0,
	/*[0x88]*/	INSTR_MOV | ADDMODE_REG_RM | WIDTH_BYTE,
	/*[0x89]*/	INSTR_MOV | ADDMODE_REG_RM | WIDTH_FULL,
	/*[0x8A]*/	INSTR_MOV | ADDMODE_RM_REG | WIDTH_BYTE,
	/*[0x8B]*/	INSTR_MOV | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x8C]*/	0,
	/*[0x8D]*/	INSTR_LEA | ADDMODE_RM_REG | WIDTH_FULL,
	/*[0x8E]*/	0,
	/*[0x8F]*/	0,
	/*[0x90]*/	INSTR_NOP | ADDMODE_IMPLIED,	/* xchg ax, ax */
	/*[0x91]*/	INSTR_XCHG | ADDMODE_ACC_REG | WIDTH_FULL,
	/*[0x92]*/	INSTR_XCHG | ADDMODE_ACC_REG | WIDTH_FULL,
	/*[0x93]*/	INSTR_XCHG | ADDMODE_ACC_REG | WIDTH_FULL,
	/*[0x94]*/	INSTR_XCHG | ADDMODE_ACC_REG | WIDTH_FULL,
	/*[0x95]*/	INSTR_XCHG | ADDMODE_ACC_REG | WIDTH_FULL,
	/*[0x96]*/	INSTR_XCHG | ADDMODE_ACC_REG | WIDTH_FULL,
	/*[0x97]*/	INSTR_XCHG | ADDMODE_ACC_REG | WIDTH_FULL,
	/*[0x98]*/	INSTR_CBW | ADDMODE_IMPLIED,
	/*[0x99]*/	INSTR_CWD | ADDMODE_IMPLIED,
	/*[0x9A]*/	0,
	/*[0x9B]*/	0,
	/*[0x9C]*/	INSTR_PUSHF | ADDMODE_IMPLIED,
	/*[0x9D]*/	INSTR_POPF | ADDMODE_IMPLIED,
	/*[0x9E]*/	INSTR_SAHF | ADDMODE_IMPLIED,
	/*[0x9F]*/	INSTR_LAHF | ADDMODE_IMPLIED,
	/*[0xA0]*/	INSTR_MOV | ADDMODE_MOFFSET_ACC | WIDTH_BYTE, /* load */
	/*[0xA1]*/	INSTR_MOV | ADDMODE_MOFFSET_ACC | WIDTH_FULL, /* load */
	/*[0xA2]*/	INSTR_MOV | ADDMODE_ACC_MOFFSET | WIDTH_BYTE, /* store */
	/*[0xA3]*/	INSTR_MOV | ADDMODE_ACC_MOFFSET | WIDTH_FULL, /* store */
	/*[0xA4]*/	INSTR_MOVSB | ADDMODE_IMPLIED | WIDTH_BYTE,
	/*[0xA5]*/	INSTR_MOVSW | ADDMODE_IMPLIED | WIDTH_FULL,
	/*[0xA6]*/	INSTR_CMPSB | ADDMODE_IMPLIED | WIDTH_BYTE,
	/*[0xA7]*/	INSTR_CMPSW | ADDMODE_IMPLIED | WIDTH_FULL,
	/*[0xA8]*/	0,
	/*[0xA9]*/	0,
	/*[0xAA]*/	INSTR_STOSB | ADDMODE_IMPLIED | WIDTH_BYTE,
	/*[0xAB]*/	INSTR_STOSW | ADDMODE_IMPLIED | WIDTH_FULL,
	/*[0xAC]*/	INSTR_LODSB | ADDMODE_IMPLIED | WIDTH_BYTE,
	/*[0xAD]*/	INSTR_LODSW | ADDMODE_IMPLIED | WIDTH_FULL,
	/*[0xAE]*/	INSTR_SCASB | ADDMODE_IMPLIED | WIDTH_BYTE,
	/*[0xAF]*/	INSTR_SCASW | ADDMODE_IMPLIED | WIDTH_FULL,
	/*[0xB0]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB1]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB2]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB3]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB4]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB5]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB6]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB7]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_BYTE,
	/*[0xB8]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xB9]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xBA]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xBB]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xBC]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xBD]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xBE]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xBF]*/	INSTR_MOV | ADDMODE_IMM_REG | WIDTH_FULL,
	/*[0xC0]*/	GROUP_2 | ADDMODE_IMM8_RM | WIDTH_BYTE,
	/*[0xC1]*/	GROUP_2 | ADDMODE_IMM8_RM | WIDTH_FULL,
	/*[0xC2]*/	0,
	/*[0xC3]*/	INSTR_RET | ADDMODE_IMPLIED,
	/*[0xC4]*/	0,
	/*[0xC5]*/	0,
	/*[0xC6]*/	INSTR_MOV | ADDMODE_IMM8_RM | WIDTH_BYTE,
	/*[0xC7]*/	0,
	/*[0xC8]*/	INSTR_UNDEFINED,
	/*[0xC9]*/	INSTR_UNDEFINED,
	/*[0xCA]*/	0,
	/*[0xCB]*/	INSTR_RETF | ADDMODE_IMPLIED,
	/*[0xCC]*/	0,
	/*[0xCD]*/	INSTR_INT | ADDMODE_IMM | WIDTH_BYTE,
	/*[0xCE]*/	INSTR_INTO | ADDMODE_IMPLIED,
	/*[0xCF]*/	INSTR_IRET | ADDMODE_IMPLIED,
	/*[0xD0]*/	0,
	/*[0xD1]*/	0,
	/*[0xD2]*/	0,
	/*[0xD3]*/	0,
	/*[0xD4]*/	0,
	/*[0xD5]*/	0,
	/*[0xD6]*/	INSTR_UNDEFINED,
	/*[0xD7]*/	INSTR_XLATB | ADDMODE_IMPLIED | WIDTH_BYTE,
	/*[0xD8]*/	INSTR_UNDEFINED,
	/*[0xD9]*/	INSTR_UNDEFINED,
	/*[0xDA]*/	INSTR_UNDEFINED,
	/*[0xDB]*/	INSTR_UNDEFINED,
	/*[0xDC]*/	INSTR_UNDEFINED,
	/*[0xDD]*/	INSTR_UNDEFINED,
	/*[0xDE]*/	INSTR_UNDEFINED,
	/*[0xDF]*/	INSTR_UNDEFINED,
	/*[0xE0]*/	0,
	/*[0xE1]*/	0,
	/*[0xE2]*/	0,
	/*[0xE3]*/	0,
	/*[0xE4]*/	0,
	/*[0xE5]*/	0,
	/*[0xE6]*/	0,
	/*[0xE7]*/	0,
	/*[0xE8]*/	INSTR_CALL | Jv,
	/*[0xE9]*/	INSTR_JMP  | Jv,
	/*[0xEA]*/	0,
	/*[0xEB]*/	INSTR_JMP  | Jb,
	/*[0xEC]*/	0,
	/*[0xED]*/	0,
	/*[0xEE]*/	0,
	/*[0xEF]*/	0,
	/*[0xF0]*/	0 /* LOCK */,
	/*[0xF1]*/	INSTR_UNDEFINED,
	/*[0xF2]*/	0 /* REPNZ_PREFIX */,
	/*[0xF3]*/	0 /* REPZ_PREFIX */,
	/*[0xF4]*/	INSTR_HLT | ADDMODE_IMPLIED,
	/*[0xF5]*/	INSTR_CMC | ADDMODE_IMPLIED,
	/*[0xF6]*/	0,
	/*[0xF7]*/	0,
	/*[0xF8]*/	INSTR_CLC | ADDMODE_IMPLIED,
	/*[0xF9]*/	INSTR_STC | ADDMODE_IMPLIED,
	/*[0xFA]*/	INSTR_CLI | ADDMODE_IMPLIED,
	/*[0xFB]*/	INSTR_STI | ADDMODE_IMPLIED,
	/*[0xFC]*/	INSTR_CLD | ADDMODE_IMPLIED,
	/*[0xFD]*/	INSTR_STD | ADDMODE_IMPLIED,
	/*[0xFE]*/	0,
	/*[0xFF]*/	0,
};

static const uint32_t shift_grp2_decode_table[8] = {
	/*[0x00]*/	INSTR_ROL,
	/*[0x01]*/	INSTR_ROR,
	/*[0x02]*/	INSTR_RCL,
	/*[0x03]*/	INSTR_RCR,
	/*[0x04]*/	INSTR_SHL,
	/*[0x05]*/	INSTR_SHR,
	/*[0x06]*/	0,
	/*[0x07]*/	INSTR_SAR,
};

static uint8_t
decode_dst_reg(struct x86_instr *instr)
{
	uint8_t ret;

	if (!(instr->flags & MOD_RM))
		return instr->opcode & 0x07;

	if (instr->flags & DIR_REVERSED)
		return instr->rm;

	return instr->reg_opc;
}

static void
decode_dst_operand(struct x86_instr *instr)
{
	struct x86_operand *operand = &instr->dst;

	switch (instr->flags & DST_MASK) {
	case DST_NONE:
		break;
	case DST_REG:
		operand->type	= OP_REG;
		operand->reg	= decode_dst_reg(instr);
		break;
	case DST_ACC:
		operand->type	= OP_REG;
		operand->reg	= 0; /* AL/AX */
		break;
	case DST_MOFFSET:
	case DST_MEM:
		operand->type	= OP_MEM;
		operand->disp	= instr->disp;
		break;
	case DST_MEM_DISP_BYTE:
	case DST_MEM_DISP_FULL:
		operand->type	= OP_MEM_DISP;
		operand->reg	= instr->rm;
		operand->disp	= instr->disp;
		break;
	}
}

static uint8_t
decode_src_reg(struct x86_instr *instr)
{
	if (!(instr->flags & MOD_RM))
		return instr->opcode & 0x07;

	if (instr->flags & DIR_REVERSED)
		return instr->reg_opc;

	return instr->rm;
}

static void
decode_src_operand(struct x86_instr *instr)
{
	struct x86_operand *operand = &instr->src;

	switch (instr->flags & SRC_MASK) {
	case SRC_NONE:
		break;
	case SRC_REL:
		operand->type	= OP_REL;
		operand->rel	= instr->rel_data;
		break;
	case SRC_IMM:
	case SRC_IMM8:
		operand->type	= OP_IMM;
		operand->imm	= instr->imm_data;
		break;
	case SRC_REG:
		operand->type	= OP_REG;
		operand->reg	= decode_src_reg(instr);
		break;
	case SRC_SEG_REG:
		operand->type	= OP_SEG_REG;
		operand->reg	= instr->opcode >> 3;
		break;
	case SRC_ACC:
		operand->type	= OP_REG;
		operand->reg	= 0; /* AL/AX */
		break;
	case SRC_MOFFSET:
	case SRC_MEM:
		operand->type	= OP_MEM;
		operand->disp	= instr->disp;
		break;
	case SRC_MEM_DISP_BYTE:
	case SRC_MEM_DISP_FULL:
		operand->type	= OP_MEM_DISP;
		operand->reg	= instr->rm;
		operand->disp	= instr->disp;
	}
}

static uint8_t read_u8(uint8_t* RAM, addr_t *pc)
{
	addr_t new_pc = *pc;

	uint8_t ret = (uint8_t)RAM[new_pc++];

	*pc = new_pc;

	return ret;
}

static int8_t read_s8(uint8_t* RAM, addr_t *pc)
{
	addr_t new_pc = *pc;

	int8_t ret = (int8_t)RAM[new_pc++];

	*pc = new_pc;

	return ret;
}

static uint16_t read_u16(uint8_t* RAM, addr_t *pc)
{
	addr_t new_pc = *pc;

	uint8_t lo = RAM[new_pc++];
	uint8_t hi = RAM[new_pc++];

	uint16_t ret = (uint16_t)((hi << 8) | lo);

	*pc = new_pc;

	return ret;
}

static int16_t read_s16(uint8_t* RAM, addr_t *pc)
{
	addr_t new_pc = *pc;

	uint8_t lo = RAM[new_pc++];
	uint8_t hi = RAM[new_pc++];

	int16_t ret = (int16_t)((hi << 8) | lo);

	*pc = new_pc;

	return ret;
}

static void
decode_imm(struct x86_instr *instr, uint8_t* RAM, addr_t *pc)
{
	if (instr->flags & SRC_IMM8) {
		instr->imm_data = read_u8(RAM, pc);
		instr->nr_bytes += 1;
		return;
	}

	switch (instr->flags & WIDTH_MASK) {
	case WIDTH_FULL:
		instr->imm_data = read_u16(RAM, pc);
		instr->nr_bytes += 2;
		break;
	case WIDTH_BYTE:
		instr->imm_data = read_u8(RAM, pc);
		instr->nr_bytes += 1;
		break;
	}
}

static void
decode_rel(struct x86_instr *instr, uint8_t* RAM, addr_t *pc)
{
	switch (instr->flags & WIDTH_MASK) {
	case WIDTH_FULL:
		instr->rel_data = read_s16(RAM, pc);
		instr->nr_bytes += 2;
		break;
	case WIDTH_BYTE:
		instr->rel_data = read_s8(RAM, pc);
		instr->nr_bytes += 1;
		break;
	}
}

static void
decode_moffset(struct x86_instr *instr, uint8_t* RAM, addr_t *pc)
{
	instr->disp = read_u16(RAM, pc);
	instr->nr_bytes += 2;
}

static void
decode_disp(struct x86_instr *instr, uint8_t* RAM, addr_t *pc)
{
	switch (instr->flags & MEM_DISP_MASK) {
	case SRC_MEM_DISP_FULL:
	case DST_MEM_DISP_FULL:
	case SRC_MEM:
	case DST_MEM: {
		instr->disp	= read_s16(RAM, pc);
		instr->nr_bytes	+= 2;
		break;
	}
	case SRC_MEM_DISP_BYTE:
	case DST_MEM_DISP_BYTE:
		instr->disp	= read_s8(RAM, pc);
		instr->nr_bytes	+= 1;
		break;
	}
}

static const uint32_t mod_dst_decode[] = {
	/*[0x00]*/	DST_MEM,
	/*[0x01]*/	DST_MEM_DISP_BYTE,
	/*[0x02]*/	DST_MEM_DISP_FULL,
	/*[0x03]*/	DST_REG,
};

static const uint32_t mod_src_decode[] = {
	/*[0x00]*/	SRC_MEM,
	/*[0x01]*/	SRC_MEM_DISP_BYTE,
	/*[0x02]*/	SRC_MEM_DISP_FULL,
	/*[0x03]*/	SRC_REG,
};

static void
decode_modrm_byte(struct x86_instr *instr, uint8_t modrm)
{
	instr->mod	= (modrm & 0xc0) >> 6;
	instr->reg_opc	= (modrm & 0x38) >> 3;
	instr->rm	= (modrm & 0x07);

	if (instr->flags & DIR_REVERSED)
		instr->flags	|= mod_dst_decode[instr->mod];
	else
		instr->flags	|= mod_src_decode[instr->mod];

	instr->nr_bytes++;
}


local function arch_8086_decode_instr(struct x86_instr *instr, uint8_t* RAM, addr_t pc)

	uint32_t decode;
	uint8_t opcode;

	instr.nr_bytes = 1;

	-- Prefixes
	instr.seg_override	= NO_OVERRIDE;
	instr.rep_prefix	= NO_PREFIX;
	instr.lock_prefix	= 0;

	for (;;) {
		switch (opcode = RAM[pc++]) {
		case 0x26:
			instr->seg_override	= ES_OVERRIDE;
			break;
		case 0x2e:
			instr->seg_override	= CS_OVERRIDE;
			break;
		case 0x36:
			instr->seg_override	= SS_OVERRIDE;
			break;
		case 0x3e:
			instr->seg_override	= DS_OVERRIDE;
			break;
		case 0xf0:	/* LOCK */
			instr->lock_prefix	= 1;
			break;
		case 0xf2:	/* REPNE/REPNZ */
			instr->rep_prefix	= REPNZ_PREFIX;
			break;
		case 0xf3:	/* REP/REPE/REPZ */
			instr->rep_prefix	= REPZ_PREFIX;
			break;
		default:
			goto done_prefixes;
		}
		instr->nr_bytes++;
	}

done_prefixes:

	/* Opcode byte */
	decode		= decode_table[opcode];

	instr->opcode	= opcode;
	instr->type	= decode & X86_INSTR_TYPE_MASK;
	instr->flags	= decode & ~X86_INSTR_TYPE_MASK;

	if (instr->flags == 0) /* Unrecognized? */
		return -1;

	if (instr->flags & MOD_RM)
		decode_modrm_byte(instr, RAM[pc++]);

	/* Opcode groups */
	switch (instr->flags & GROUP_MASK) {
	case GROUP_2:
		instr->type	= shift_grp2_decode_table[instr->reg_opc];
		break;
	default:
		break;
	}

	if (instr->flags & MEM_DISP_MASK)
		decode_disp(instr, RAM, &pc);

	if (instr->flags & MOFFSET_MASK)
		decode_moffset(instr, RAM, &pc);

	if (instr->flags & IMM_MASK)
		decode_imm(instr, RAM, &pc);

	if (instr->flags & REL_MASK)
		decode_rel(instr, RAM, &pc);

	decode_src_operand(instr);

	decode_dst_operand(instr);

	return 0;
end

local function arch_8086_instr_length(instr)
	return instr.nr_bytes;
end

return {
    decodeInstruction = arch_8086_decode_instr;
    instructionLength = arch_8086_instr_length;
}

