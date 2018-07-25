--[[
    Reference from libcpu.org project

    This stuff is used to decode an instruction stream
    just another approach.

    I like this approach because it breaks things down into 
    component parts, where you can still see explicitly 
    the addressing modes, and whatnot
]]
package.path = "../?.lua;"..package.path

-- create a namespace
-- so we can make the enums appear to be global
-- without polluting actual _G table
local x86_ns = {}
setmetatable(x86_ns, {__index= _G})
setfenv(1, x86_ns)
---------------------

local ffi = require("ffi")
local bit = require("bit")
local lshift, rshift = bit.lshift, bit.rshift
local bor, band = bit.bor, bit.band

local enum = require("peettles.enum")


local x86_operand_type = enum {
	OP_IMM = 0,
	OP_MEM = 1,
	OP_MEM_DISP = 2,
	OP_REG = 3,
	OP_SEG_REG = 4,
	OP_REL = 5,
};
enum.inject(x86_operand_type, x86_ns)

local x86_seg_override = enum {
	NO_OVERRIDE=0,
	ES_OVERRIDE=1,
	CS_OVERRIDE=2,
	SS_OVERRIDE=3,
	DS_OVERRIDE=4,
};
enum.inject(x86_seg_override, x86_ns)

local x86_rep_prefix = enum {
	NO_PREFIX = 0,
	REPNZ_PREFIX = 1,
	REPZ_PREFIX = 2,
};
enum.inject(x86_rep_prefix, x86_ns)


--[[
struct x86_operand {
	enum x86_operand_type	type;
	uint8_t			reg;
	int32_t			disp;
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

local  x86_instr_flags = enum {
	MOD_RM			= lshift(1, 8);
	DIR_REVERSED	= lshift(1, 9);

	-- Operand sizes 
	WIDTH_BYTE		= lshift(1, 10);	-- 8 bits 
	WIDTH_FULL		= lshift(1, 11);	-- 16 bits or 32 bits 

	-- Source operand 
	SRC_NONE		= lshift(1, 12);
	SRC_IMM			= lshift(1, 13);
	SRC_IMM8		= lshift(1, 14);
	SRC_REL			= lshift(1, 15);
	SRC_REG			= lshift(1, 16);
	SRC_SEG_REG		= lshift(1, 17);
	SRC_ACC			= lshift(1, 18);
	SRC_MEM			= lshift(1, 19);
	SRC_MOFFSET		= lshift(1, 20);
	SRC_MEM_DISP_BYTE	= lshift(1, 21);
	SRC_MEM_DISP_FULL	= lshift(1, 22);

	-- Destination operand 
	DST_NONE		= lshift(1, 23);
	DST_REG			= lshift(1, 24);
	DST_ACC			= lshift(1, 25);	-- AL/AX
	DST_MEM			= lshift(1, 26);
	DST_MOFFSET		= lshift(1, 27);
	DST_MEM_DISP_BYTE	= lshift(1, 28);	-- 8 bits 
	DST_MEM_DISP_FULL	= lshift(1, 29);	-- 16 bits or 32 bits 

	GROUP_2			= lshift(1, 30);
};
enum.inject(x86_instr_flags, x86_ns)

local WIDTH_MASK	= bor(WIDTH_BYTE,WIDTH_FULL);
local IMM_MASK		= bor(SRC_IMM,SRC_IMM8);
local REL_MASK		= SRC_REL;
local SRC_MASK		= bor(SRC_NONE,IMM_MASK,REL_MASK,SRC_REG,SRC_SEG_REG,SRC_ACC,SRC_MEM,SRC_MOFFSET,SRC_MEM_DISP_BYTE,SRC_MEM_DISP_FULL);

local DST_MASK		= bor(DST_NONE,DST_REG,DST_ACC,DST_MOFFSET,DST_MEM,DST_MEM_DISP_BYTE,DST_MEM_DISP_FULL);

local MEM_DISP_MASK	= bor(SRC_MEM,SRC_MEM_DISP_BYTE,SRC_MEM_DISP_FULL,DST_MEM,DST_MEM_DISP_BYTE,DST_MEM_DISP_FULL);

local MOFFSET_MASK	= bor(SRC_MOFFSET,DST_MOFFSET);
local GROUP_MASK	= GROUP_2;

--	Addressing modes.
local x86_addmode = enum {
	ADDMODE_ACC_MOFFSET	= bor(SRC_ACC,DST_MOFFSET);		-- AL/AX . moffset 
	ADDMODE_ACC_REG		= bor(SRC_ACC,DST_REG);		-- AL/AX . reg 
	ADDMODE_IMM			= bor(SRC_IMM,DST_NONE);		-- immediate operand 
	ADDMODE_IMM8_RM		= bor(SRC_IMM8,MOD_RM,DIR_REVERSED);	-- immediate . register/memory 
	ADDMODE_IMM_ACC		= bor(SRC_IMM,DST_ACC);		-- immediate . AL/AX 
	ADDMODE_IMM_REG		= bor(SRC_IMM,DST_REG);		-- immediate . register 
	ADDMODE_IMPLIED		= bor(SRC_NONE,DST_NONE);		-- no operands 
	ADDMODE_MOFFSET_ACC	= bor(SRC_MOFFSET,DST_ACC);		-- moffset . AL/AX 
	ADDMODE_REG			= bor(SRC_REG,DST_NONE);		-- register 
	ADDMODE_SEG_REG		= bor(SRC_SEG_REG,DST_NONE);		-- segment register 
	ADDMODE_REG_RM		= bor(SRC_REG,MOD_RM,DIR_REVERSED);	-- register . register/memory 
	ADDMODE_REL			= bor(SRC_REL,DST_NONE);		-- relative 
	ADDMODE_RM_REG		= bor(DST_REG,MOD_RM);		-- register/memory . register 
};
enum.inject(x86_addmode, x86_ns)

--[[
struct x86_instr {
	unsigned long		nr_bytes;

	uint8_t			opcode;		-- Opcode byte 
	uint8_t			width;
	uint8_t			mod;		-- Mod 
	uint8_t			rm;		-- R/M 
	uint8_t			reg_opc;	-- Reg/Opcode 
	uint32_t		disp;		-- Address displacement 
	union {
		uint32_t		imm_data;	-- Immediate data 
		int32_t			rel_data;	-- Relative address data 
	};

	unsigned long		type;		-- See enum x86_instr_types 
	unsigned long		flags;		-- See enum x86_instr_flags 
	enum x86_seg_override	seg_override;
	enum x86_rep_prefix	rep_prefix;
	unsigned char		lock_prefix;
	struct x86_operand	src;
	struct x86_operand	dst;
};
]]
 
local function x86_instr()
	return {

	}
end


-- Instruction decoding
-- First byte of an element in 'decode_table' is the instruction type.
--[[
	PUT THE INSTRUCTION TABLE HERE
]]

local X86_INSTR_TYPE_MASK	= 0xff;

local INSTR_UNDEFINED		= 0;

local Jb = bor(ADDMODE_REL , WIDTH_BYTE)
local Jv = bor(ADDMODE_REL , WIDTH_FULL)

local decode_table = ffi.new("static const uint32_t[256]", {
	bor(INSTR_ADD , ADDMODE_REG_RM , WIDTH_BYTE);
	bor(INSTR_ADD , ADDMODE_REG_RM , WIDTH_FULL);
	bor(INSTR_ADD , ADDMODE_RM_REG , WIDTH_BYTE);
	bor(INSTR_ADD , ADDMODE_RM_REG , WIDTH_FULL);
	bor(INSTR_ADD , ADDMODE_IMM_ACC , WIDTH_BYTE);
	bor(INSTR_ADD , ADDMODE_IMM_ACC , WIDTH_FULL);
	bor(INSTR_PUSH , ADDMODE_SEG_REG  , WIDTH_FULL);				-- ES 
	bor(INSTR_POP , ADDMODE_SEG_REG  , WIDTH_FULL);				-- ES 
	bor(INSTR_OR , ADDMODE_REG_RM , WIDTH_BYTE);
	bor(INSTR_OR , ADDMODE_REG_RM , WIDTH_FULL);
	bor(INSTR_OR , ADDMODE_RM_REG , WIDTH_BYTE);
	bor(INSTR_OR , ADDMODE_RM_REG , WIDTH_FULL);
	bor(INSTR_OR , ADDMODE_IMM_ACC , WIDTH_BYTE);
	bor(INSTR_OR , ADDMODE_IMM_ACC , WIDTH_FULL);
	bor(INSTR_PUSH , ADDMODE_SEG_REG  , WIDTH_FULL);				-- CS 
	INSTR_UNDEFINED;
		bor(INSTR_ADC , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_ADC , ADDMODE_REG_RM , WIDTH_FULL);
		bor(INSTR_ADC , ADDMODE_RM_REG , WIDTH_BYTE);
		bor(INSTR_ADC , ADDMODE_RM_REG , WIDTH_FULL);
		bor(INSTR_ADC , ADDMODE_IMM_ACC , WIDTH_BYTE);
		bor(INSTR_ADC , ADDMODE_IMM_ACC , WIDTH_FULL);
		bor(INSTR_PUSH , ADDMODE_SEG_REG  , WIDTH_FULL);				-- SS 
		bor(INSTR_POP , ADDMODE_SEG_REG  , WIDTH_FULL);				-- SS 
		bor(INSTR_SBB , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_SBB , ADDMODE_REG_RM , WIDTH_FULL);
		bor(INSTR_SBB , ADDMODE_RM_REG , WIDTH_BYTE);
		bor(INSTR_SBB , ADDMODE_RM_REG , WIDTH_FULL);
		bor(INSTR_SBB , ADDMODE_IMM_ACC , WIDTH_BYTE);
		bor(INSTR_SBB , ADDMODE_IMM_ACC , WIDTH_FULL);
		bor(INSTR_PUSH , ADDMODE_SEG_REG  , WIDTH_FULL);				-- DS 
		bor(INSTR_POP , ADDMODE_SEG_REG  , WIDTH_FULL);				-- DS 
		bor(INSTR_AND , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_AND , ADDMODE_REG_RM , WIDTH_FULL);
		bor(INSTR_AND , ADDMODE_RM_REG , WIDTH_BYTE);
		bor(INSTR_AND , ADDMODE_RM_REG , WIDTH_FULL);
		bor(INSTR_AND , ADDMODE_IMM_ACC , WIDTH_BYTE);
		bor(INSTR_AND , ADDMODE_IMM_ACC , WIDTH_FULL);
		0 -- ES_OVERRIDE );
		bor(INSTR_DAA , ADDMODE_IMPLIED);
		bor(INSTR_SUB , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_SUB , ADDMODE_REG_RM , WIDTH_FULL);
		bor(INSTR_SUB , ADDMODE_RM_REG , WIDTH_BYTE);
		bor(INSTR_SUB , ADDMODE_RM_REG , WIDTH_FULL);
		bor(INSTR_SUB , ADDMODE_IMM_ACC , WIDTH_BYTE);
		bor(INSTR_SUB , ADDMODE_IMM_ACC , WIDTH_FULL);
		0 -- CS_OVERRIDE );
		bor(INSTR_DAS , ADDMODE_IMPLIED);
		bor(INSTR_XOR , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_XOR , ADDMODE_REG_RM , WIDTH_FULL);
		bor(INSTR_XOR , ADDMODE_RM_REG , WIDTH_BYTE);
		bor(INSTR_XOR , ADDMODE_RM_REG , WIDTH_FULL);
		bor(INSTR_XOR , ADDMODE_IMM_ACC , WIDTH_BYTE);
		bor(INSTR_XOR , ADDMODE_IMM_ACC , WIDTH_FULL);
		0 -- SS_OVERRIDE );
		bor(INSTR_AAA , ADDMODE_IMPLIED);
		bor(INSTR_CMP , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_CMP , ADDMODE_REG_RM , WIDTH_FULL);
		bor(INSTR_CMP , ADDMODE_RM_REG , WIDTH_BYTE);
		bor(INSTR_CMP , ADDMODE_RM_REG , WIDTH_FULL);
		bor(INSTR_CMP , ADDMODE_IMM_ACC , WIDTH_BYTE);
		bor(INSTR_CMP , ADDMODE_IMM_ACC , WIDTH_FULL);
		0 -- DS_OVERRIDE );
		bor(INSTR_AAS , ADDMODE_IMPLIED);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_INC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_DEC , ADDMODE_REG , WIDTH_FULL);
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- AX 
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- CX 
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- DX 
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- BX 
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- SP 
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- BP 
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- SI 
		bor(INSTR_PUSH , ADDMODE_REG  , WIDTH_FULL);					-- DI 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- AX 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- CX 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- DX 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- BX 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- SP 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- BP 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- SI 
		bor(INSTR_POP , ADDMODE_REG   , WIDTH_FULL);					-- DI 
		bor(INSTR_PUSHA , ADDMODE_IMPLIED);		-- 80186 
		bor(INSTR_POPA , ADDMODE_IMPLIED);		-- 80186 
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		bor(INSTR_JO  , Jb);
		bor(INSTR_JNO , Jb);
		bor(INSTR_JB  , Jb);
		bor(INSTR_JNB , Jb);
		bor(INSTR_JZ  , Jb);
		bor(INSTR_JNE , Jb);
		bor(INSTR_JBE , Jb);
		bor(INSTR_JA  , Jb);
		bor(INSTR_JS  , Jb);
		bor(INSTR_JNS , Jb);
		bor(INSTR_JPE , Jb);
		bor(INSTR_JPO , Jb);
		bor(INSTR_JL  , Jb);
		bor(INSTR_JGE , Jb);
		bor(INSTR_JLE , Jb);
		bor(INSTR_JG  , Jb);
		0);
		0);
		0);
		0);
		bor(INSTR_TEST , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_TEST , ADDMODE_REG_RM , WIDTH_FULL);
		0);
		0);
		bor(INSTR_MOV , ADDMODE_REG_RM , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_REG_RM , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_RM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_RM_REG , WIDTH_FULL);
		0);
		bor(INSTR_LEA , ADDMODE_RM_REG , WIDTH_FULL);
		0);
		0);
		bor(INSTR_NOP , ADDMODE_IMPLIED);	-- xchg ax); ax 
		bor(INSTR_XCHG , ADDMODE_ACC_REG , WIDTH_FULL);
		bor(INSTR_XCHG , ADDMODE_ACC_REG , WIDTH_FULL);
		bor(INSTR_XCHG , ADDMODE_ACC_REG , WIDTH_FULL);
		bor(INSTR_XCHG , ADDMODE_ACC_REG , WIDTH_FULL);
		bor(INSTR_XCHG , ADDMODE_ACC_REG , WIDTH_FULL);
		bor(INSTR_XCHG , ADDMODE_ACC_REG , WIDTH_FULL);
		bor(INSTR_XCHG , ADDMODE_ACC_REG , WIDTH_FULL);
		bor(INSTR_CBW , ADDMODE_IMPLIED);
		bor(INSTR_CWD , ADDMODE_IMPLIED);
		0);
		0);
		bor(INSTR_PUSHF , ADDMODE_IMPLIED);
		bor(INSTR_POPF , ADDMODE_IMPLIED);
		bor(INSTR_SAHF , ADDMODE_IMPLIED);
		bor(INSTR_LAHF , ADDMODE_IMPLIED);
		bor(INSTR_MOV , ADDMODE_MOFFSET_ACC , WIDTH_BYTE); -- load 
		bor(INSTR_MOV , ADDMODE_MOFFSET_ACC , WIDTH_FULL); -- load 
		bor(INSTR_MOV , ADDMODE_ACC_MOFFSET , WIDTH_BYTE); -- store 
		bor(INSTR_MOV , ADDMODE_ACC_MOFFSET , WIDTH_FULL); -- store 
		bor(INSTR_MOVSB , ADDMODE_IMPLIED , WIDTH_BYTE);
		bor(INSTR_MOVSW , ADDMODE_IMPLIED , WIDTH_FULL);
		bor(INSTR_CMPSB , ADDMODE_IMPLIED , WIDTH_BYTE);
		bor(INSTR_CMPSW , ADDMODE_IMPLIED , WIDTH_FULL);
		0);
		0);
		bor(INSTR_STOSB , ADDMODE_IMPLIED , WIDTH_BYTE);
		bor(INSTR_STOSW , ADDMODE_IMPLIED , WIDTH_FULL);
		bor(INSTR_LODSB , ADDMODE_IMPLIED , WIDTH_BYTE);
		bor(INSTR_LODSW , ADDMODE_IMPLIED , WIDTH_FULL);
		bor(INSTR_SCASB , ADDMODE_IMPLIED , WIDTH_BYTE);
		bor(INSTR_SCASW , ADDMODE_IMPLIED , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_BYTE);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(INSTR_MOV , ADDMODE_IMM_REG , WIDTH_FULL);
		bor(GROUP_2 , ADDMODE_IMM8_RM , WIDTH_BYTE);
		BOR(GROUP_2 , ADDMODE_IMM8_RM , WIDTH_FULL);
		0;
		bor(INSTR_RET , ADDMODE_IMPLIED);
		0;
		0;
		bor(INSTR_MOV , ADDMODE_IMM8_RM , WIDTH_BYTE);
		0;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		0;
		bor(INSTR_RETF , ADDMODE_IMPLIED);
		0;
		bor(INSTR_INT , ADDMODE_IMM , WIDTH_BYTE);
		bor(INSTR_INTO , ADDMODE_IMPLIED);
		bor(INSTR_IRET , ADDMODE_IMPLIED);
		0;
		0;
		0;
		0;
		0;
		0;
		INSTR_UNDEFINED;
		bor(INSTR_XLATB , ADDMODE_IMPLIED , WIDTH_BYTE);
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
		INSTR_UNDEFINED;
	INSTR_UNDEFINED;
	INSTR_UNDEFINED;
	INSTR_UNDEFINED;
	INSTR_UNDEFINED;
	INSTR_UNDEFINED;
	0;
	0;
	0;
	0;
	0;
	0;
	0;
	0;
	bor(INSTR_CALL , Jv);
	bor(INSTR_JMP  , Jv);
	0;
	bor(INSTR_JMP  , Jb);
	0;
	0;
	0;
	0;
	0 -- LOCK
	INSTR_UNDEFINED;
	0; -- REPNZ_PREFIX
	0; -- REPZ_PREFIX
	bor(INSTR_HLT , ADDMODE_IMPLIED);
	bor(INSTR_CMC , ADDMODE_IMPLIED);
	0;
	0;
	bor(INSTR_CLC , ADDMODE_IMPLIED);
	bor(INSTR_STC , ADDMODE_IMPLIED);
	bor(INSTR_CLI , ADDMODE_IMPLIED);
	bor(INSTR_STI , ADDMODE_IMPLIED);
	bor(INSTR_CLD , ADDMODE_IMPLIED);
	bor(INSTR_STD , ADDMODE_IMPLIED);
	0;
	0;
};

local shift_grp2_decode_table = {
	[0] = 	INSTR_ROL,
		INSTR_ROR,
		INSTR_RCL,
		INSTR_RCR,
		INSTR_SHL,
		INSTR_SHR,
		0,
		INSTR_SAR,
};


local function decode_dst_reg(instr)

	if (band(instr.flags, MOD_RM) == 0) then
		return instr.opcode & 0x07;
	end

	if band (instr.flags, DIR_REVERSED) ~= 0 then
		return instr.rm;
	end

	return instr.reg_opc;
end

local function decode_dst_operand(instr)

	struct x86_operand *operand = &instr.dst;

	switch (instr.flags & DST_MASK) {
	case DST_NONE:
		break;
	case DST_REG:
		operand.type	= OP_REG;
		operand.reg	= decode_dst_reg(instr);
		break;
	case DST_ACC:
		operand.type	= OP_REG;
		operand.reg	= 0; -- AL/AX 
		break;
	case DST_MOFFSET:
	case DST_MEM:
		operand.type	= OP_MEM;
		operand.disp	= instr.disp;
		break;
	case DST_MEM_DISP_BYTE:
	case DST_MEM_DISP_FULL:
		operand.type	= OP_MEM_DISP;
		operand.reg	= instr.rm;
		operand.disp	= instr.disp;
		break;
	}
end

local function decode_src_reg(instr)
	if (band(instr.flags, MOD_RM) == 0) then
		return instr.opcode & 0x07;
	end

	if band(instr.flags, DIR_REVERSED) ~= 0 then
		return instr.reg_opc;
	end

	return instr.rm;
end


local function decode_src_operand(struct x86_instr *instr)

	struct x86_operand *operand = &instr.src;

	switch (instr.flags & SRC_MASK) {
	case SRC_NONE:
		break;
	case SRC_REL:
		operand.type	= OP_REL;
		operand.rel	= instr.rel_data;
		break;
	case SRC_IMM:
	case SRC_IMM8:
		operand.type	= OP_IMM;
		operand.imm	= instr.imm_data;
		break;
	case SRC_REG:
		operand.type	= OP_REG;
		operand.reg	= decode_src_reg(instr);
		break;
	case SRC_SEG_REG:
		operand.type	= OP_SEG_REG;
		operand.reg	= instr.opcode >> 3;
		break;
	case SRC_ACC:
		operand.type	= OP_REG;
		operand.reg	= 0; -- AL/AX 
		break;
	case SRC_MOFFSET:
	case SRC_MEM:
		operand.type	= OP_MEM;
		operand.disp	= instr.disp;
		break;
	case SRC_MEM_DISP_BYTE:
	case SRC_MEM_DISP_FULL:
		operand.type	= OP_MEM_DISP;
		operand.reg	= instr.rm;
		operand.disp	= instr.disp;
	}
end



local function decode_imm(struct x86_instr *instr, uint8_t* RAM, addr_t *pc)

	if (instr.flags & SRC_IMM8) {
		instr.imm_data = read_u8(RAM, pc);
		instr.nr_bytes += 1;
		return;
	}

	switch (instr.flags & WIDTH_MASK) {
	case WIDTH_FULL:
		instr.imm_data = read_u16(RAM, pc);
		instr.nr_bytes += 2;
		break;
	case WIDTH_BYTE:
		instr.imm_data = read_u8(RAM, pc);
		instr.nr_bytes += 1;
		break;
	}
end


local function decode_rel(instr, bs)
	local flags = band(instr.flags & WIDTH_MASK)
	if flags == WIDTH_FULL then
		instr.rel_data = bs:readInt16();
		instr.nr_bytes = instr.nr_bytes + 2;
	elseif flags == WIDTH_BYTE then
		instr.rel_data = bs:readInt8();
		instr.nr_bytes = instr.nr_bytes + 1;
	end
end

local function decode_moffset(instr, bs)
	instr.disp = bs:readUInt16();
	instr.nr_bytes = instr.nr_bytes + 2;
end


local function decode_disp(instr, bs)

	switch (instr.flags & MEM_DISP_MASK) {
	case SRC_MEM_DISP_FULL:
	case DST_MEM_DISP_FULL:
	case SRC_MEM:
	case DST_MEM: {
		instr.disp	= bs:readInt16();
		instr.nr_bytes	= instr.nr_bytes+2;
		break;
	}
	case SRC_MEM_DISP_BYTE:
	case DST_MEM_DISP_BYTE:
		instr.disp	= bs:readInt8();
		instr.nr_bytes	= instr.nr_bytes + 1;
		break;
	}
end

local mod_dst_decode = {
		[0] = DST_MEM,
		DST_MEM_DISP_BYTE,
		DST_MEM_DISP_FULL,
		DST_REG,
};

local  mod_src_decode = {
		[0] = SRC_MEM,
		SRC_MEM_DISP_BYTE,
		SRC_MEM_DISP_FULL,
		SRC_REG,
};


local function decode_modrm_byte(instr, modrm)

	instr.mod		= rshift(band(modrm, 0xc0) , 6);
	instr.reg_opc	= rshift(band(modrm, 0x38) , 3);
	instr.rm		= band(modrm, 0x07);

	if band(instr.flags, DIR_REVERSED) ~= 0 then
		instr.flags	= bor(instr.flags, mod_dst_decode[instr.mod]);
	else
		instr.flags	|= bor(instr.flags, mod_src_decode[instr.mod]);
	end 

	instr.nr_bytes = instr.nr_bytes + 1;
end


local function arch_8086_decode_instr(instr, bs)
	instr.nr_bytes = 1;

	-- Prefixes
	instr.seg_override	= NO_OVERRIDE;
	instr.rep_prefix	= NO_PREFIX;
	instr.lock_prefix	= 0;

	while true do
		local opcode = bs:readOctet();

		if opcode == 0x26:
			instr.seg_override	= ES_OVERRIDE;
		elseif opcode == 0x2e:
			instr.seg_override	= CS_OVERRIDE;
		elseif opcode == 0x36:
			instr.seg_override	= SS_OVERRIDE;
		elseif opcode == 0x3e:
			instr.seg_override	= DS_OVERRIDE;
		elseif opcode == 0xf0:	-- LOCK 
			instr.lock_prefix	= 1;
		elseif opcode == 0xf2:	-- REPNE/REPNZ 
			instr.rep_prefix	= REPNZ_PREFIX;
		elseif opcode == 0xf3:	-- REP/REPE/REPZ 
			instr.rep_prefix	= REPZ_PREFIX;
		else
			goto done_prefixes;
		end
		instr.nr_bytes = instr.nr_bytes + 1;
	end

::done_prefixes::

	-- Opcode byte 
	local decode = decode_table[opcode];

	instr.opcode	= opcode;
	instr.type	= band(decode, X86_INSTR_TYPE_MASK);
	instr.flags	= band(decode, bnot(X86_INSTR_TYPE_MASK));

	if (instr.flags == 0) then -- Unrecognized? 
		return false;
	end

	local modrm = bs:readOctet();
	if band(instr.flags, MOD_RM) ~= 0 then
		decode_modrm_byte(instr, modrm);
	end

	-- Opcode groups 
	local group = band(instr.flags, GROUP_MASK)
	
	if group == GROUP_2 then
		instr.type	= shift_grp2_decode_table[instr.reg_opc];
	end

	if band(instr.flags, MEM_DISP_MASK) ~= 0 then
		decode_disp(instr, bs);
	end

	if band(instr.flags, MOFFSET_MASK) ~= 0 then
		decode_moffset(instr, bs);
	end

	if band(instr.flags, IMM_MASK) ~= 0 then
		decode_imm(instr, bs);
	end

	if band(instr.flags, REL_MASK) ~= 0 then
		decode_rel(instr, bs);
	end

	decode_src_operand(instr);

	decode_dst_operand(instr);

	return true;
end

local function arch_8086_instr_length(instr)
	return instr.nr_bytes;
end

return {
    decodeInstruction = arch_8086_decode_instr;
    instructionLength = arch_8086_instr_length;
}

