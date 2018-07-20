--[[
    intel instruction architecture disassembly

    Plenty of stuff to go in here.  For now, just a
    dumping ground of ideas, bits and bobbles
--]]

--[[
       +-----------------------------------------------------------------------+    
       ¦                 ¦                 ¦     * * *       ¦                 ¦    
       ¦ 7 6 5 4 3 2 1 0 ¦ 7 6 5 4 3 2 1 0 ¦ 7 6 5 4 3 2 1 0 ¦ 7 6 5 4 3 2 1 0 ¦    
       +-+-+-+-+-+-+-+-+---+-+-+-+-+-+-+-+---+-+-+-+-+-+-+-+---+-+-+-+-+-+-+-+-+      
       ¦ ¦ ¦ ¦ ¦ ¦ ¦ ¦   ¦ ¦ ¦ ¦ ¦ ¦ ¦ ¦   ¦ ¦ ¦ ¦ ¦ ¦ ¦ ¦   ¦ ¦ ¦ ¦ ¦ ¦ ¦ ¦      
       +-------------------------------+   +-------------+   +-------------+                     
                         ¦                          ¦                 ¦           
                         ¦                          ¦                 ¦ 
 
                       Opcode                    ModR/M Byte        SIB Byte                
                       1 or 2 Bytes           
--]]

--[[
    All operands are specified in two-character of the form Zz. Where the   
    Uppercase letter 'Z' indicates addressing mode and the Lowercase letter  
    'z' indicates the type of operand.
--]]

local AddressingMode = {
    A = "Direct Address";
    C = " The reg field of the ModR/M byte selects the control register";
    D = "";
    E = "";
    F = "EFLAGS register";
    G = "The reg field of ModR/M byte selects a general purpose register";
    I = "Immediate data";
    J = "The instruction contains relative offset to be added to the instruction pointer register";
    M = " The ModR/M may refer to only memory";
    O = " The instruction has no ModR/M byte. The offset of the operand is             coded as word or double word in the instruction. No base register,             Index register, or Scale factor can be applied";
    P = " The reg field of the ModR/M byte selects a packed quadword ";
    Q = "";
    R = "";
    S = "";
    T = "";
    V = "";
    W = "";
    X = "";
    Y = "";
}

--[[
    This is the list of one byte opcodes
    The 'name' is the mnemonic you typically see in assembly
    The op1, and op2 indicate what the operands are in terms of 
    addressing mode and type of data

    This table will be used in various ways, either for direct 
    lookups, or to create more specialized tables.
--]]
local OneByteOpCodes = {
    [0x00] = {name = "ADD", op1 = 'Eb', op2 = 'Gb'};
    [0x01] = {name = 'ADD', op1 = 'Ev', op2 = 'Gv'};
    [0x02] = {name = 'ADD', op1 = 'Gb', op2 = 'Eb'};
    [0x03] = {name = 'ADD', op1 = 'Gv', op2 = 'Ev'};
    [0x04] = {name = 'ADD', op1 = 'AL', op2 = 'Ib'};
    [0x05] = {name = 'ADD', op1 = 'eAX', op2 = 'Iv'};
    [0x06] = {name = 'PUSH', op1 = 'ES'};
    [0x07] = {name = 'POP', op1 = 'ES'};

    [0x10] = {name = 'ADC', op1 = 'Eb', op2='Gb'};
    [0x11] = {name = 'ADC', op1 = 'Ev', op2='Gv'};
    [0x12] = {name = 'ADC', op1 = 'Gb', op2='Eb'};
    [0x13] = {name = 'ADC', op1 = 'Gv', op2='Ev'};
    [0x14] = {name = 'ADC', op1 = 'AL', op2='Ib'};
    [0x15] = {name = 'ADC', op1 = 'eAX', op2='IV'};
    [0x16] = {name = 'PUSH', op1 = 'SS'};
    [0x17] = {name = 'POP', op1 = 'SS'};

    [0x20] = {name = 'AND', op1 = 'Eb', op2='Gb'};
    [0x21] = {name = 'AND', op1 = 'Ev', op2='Gv'};
    [0x22] = {name = 'AND', op1 = 'Gb', op2='Eb'};
    [0x23] = {name = 'AND', op1 = 'Gv', op2='Ev'};
    [0x24] = {name = 'AND', op1 = 'AL', op2='Ib'};
    [0x25] = {name = 'AND', op1 = 'eAX', op2='IV'};
    [0x26] = {name = 'SEG', op1 = '=ES'};
    [0x27] = {name = 'DAA'};

    [0x30] = {name = 'XOR', op1 = 'Eb', op2='Gb'};
    [0x31] = {name = 'XOR', op1 = 'Ev', op2='Gv'};
    [0x32] = {name = 'XOR', op1 = 'Gb', op2='Eb'};
    [0x33] = {name = 'XOR', op1 = 'Gv', op2='Ev'};
    [0x34] = {name = 'XOR', op1 = 'AL', op2='Ib'};
    [0x35] = {name = 'XOR', op1 = 'eAX', op2='IV'};
    [0x36] = {name = 'SEG', op1 = '=SS'};
    [0x37] = {name = 'AAA'};

    -- increment general registers
    [0x40] = {name = 'INC', op1 = 'eAX'};
    [0x41] = {name = 'INC', op1 = 'eCX'};
    [0x42] = {name = 'INC', op1 = 'eDX'};
    [0x43] = {name = 'INC', op1 = 'eBX'};
    [0x44] = {name = 'INC', op1 = 'eSP'};
    [0x45] = {name = 'INC', op1 = 'eBP'};
    [0x46] = {name = 'INC', op1 = 'eSI'};
    [0x47] = {name = 'INC', op1 = 'eDI'};

    -- push general register
    [0x50] = {name = 'PUSH', op1 = 'eAX'};
    [0x51] = {name = 'PUSH', op1 = 'eCX'};
    [0x52] = {name = 'PUSH', op1 = 'eDX'};
    [0x53] = {name = 'PUSH', op1 = 'eBX'};
    [0x54] = {name = 'PUSH', op1 = 'eSP'};
    [0x55] = {name = 'PUSH', op1 = 'eBP'};
    [0x56] = {name = 'PUSH', op1 = 'eSI'};
    [0x57] = {name = 'PUSH', op1 = 'eDI'};

    [0x60] = {name = 'PUSHA'};
    [0x61] = {name = 'POPA'};
    [0x62] = {name = 'BOUND', op1 = 'Gv', op2 = 'Ma'};
    [0x63] = {name = 'ARPL', op1 = 'Ew', op2 = 'Rw'};
    [0x64] = {name = 'SEG', op1 = '=FS'};
    [0x65] = {name = 'SEG', op1 = '=GS'};
    [0x66] = {name = 'Operand', op1 = 'Size'};
    [0x67] = {name = 'Address', op1 = 'Size'};

    -- short displacement jump on condition
    [0x70] = {name = 'JO'};
    [0x71] = {name = 'JNO'};
    [0x72] = {name = 'JB'};
    [0x73] = {name = 'JNB'};
    [0x74] = {name = 'JZ'};
    [0x75] = {name = 'JNZ'};
    [0x76] = {name = 'JBE'};
    [0x77] = {name = 'JNBE'};

    [0X80] = {name = "Immediate Grp1", op1='Eb', op2 = 'Ib'};
    [0X81] = {name = "Immediate Grp1", op1='Ev', op2 = 'Iv'};
    -- [0x82] = Not Defined
    [0x83] = {name = "Grp1", op1 = 'Ev', op2='Iv'};
    [0x84] = {name = 'TEST', op1='Eb', op2='Gb'};
    [0x85] = {name = 'TEST', op1='Ev', op2='Gv'};
    [0x86] = {name = 'XCHG', op1='Eb', op2='Gb'};
    [0x87] = {name = 'XCHG', op1='Ev', op2='Gv'};
    
    -- Exchange word or double-word register with eAX
    [0x90] = {name = 'NOP'};
    [0x91] = {name = 'XCHG', op1='eCX'};
    [0x92] = {name = 'XCHG', op1='eDX'};
    [0x93] = {name = 'XCHG', op1='eBX'};
    [0x94] = {name = 'XCHG', op1='eSP'};
    [0x95] = {name = 'XCHG', op1='eBP'};
    [0x96] = {name = 'XCHG', op1='eSI'};
    [0x97] = {name = 'XCHG', op1='eDI'};

    [0xA0] = {name = 'MOV', op1='AL', op2='Ob'};
    [0xA1] = {name = 'MOV', op1='eAX', op2='Ov'};
    [0xA2] = {name = 'MOV', op1='Ob', op2='AL'};
    [0xA3] = {name = 'MOV', op1='Ov', op2='eAX'};
    [0xA4] = {name = 'MOVSB', op1='Xb', op2='Yb'};
    [0xA5] = {name = 'MOVSW', op1='Xv', op2='Yv'};
    [0xA6] = {name = 'CMPSB', op1='Xb', op2='Yb'};
    [0xA7] = {name = 'CMPSW', op1='Xv', op2='Yv'};
    
    -- move immediate byte into byte register
    [0xB0] = {name = 'MOV', op1='AL', op2='Ib'};
    [0xB1] = {name = 'MOV', op1='CL', op2='Ib'};
    [0xB2] = {name = 'MOV', op1='DL', op2='Ib'};
    [0xB3] = {name = 'MOV', op1='BL', op2='Ib'};
    [0xB4] = {name = 'MOV', op1='AH', op2='Ib'};
    [0xB5] = {name = 'MOV', op1='CH', op2='Ib'};
    [0xB6] = {name = 'MOV', op1='DH', op2='Ib'};
    [0xB7] = {name = 'MOV', op1='BH', op2='Ib'};

    [0xC0] = {name = 'Shift Grp2', op1='Eb', op2='Ib'};
    [0xC1] = {name = 'Shift Grp2', op1='Ev', op2='Iv'};
    [0xC2] = {name = 'RET', op1='Iw'};  -- return near
    [0xC3] = {name = 'RET'};
    [0xC4] = {name = 'LES', op1='Gv', op2='Mp'};
    [0xC5] = {name = 'LDS', op1='Gv', op2='Mp'};
    [0xC6] = {name = 'MOV', op1='Eb', op2='Ib'};
    [0xC7] = {name = 'MOV', op1='Ev', op2='Iv'};

    [0xD0] = {name = "Shift Grp2", op1='Eb', op2='1'};
    [0xD1] = {name = "Shift Grp2", op1='Ev', op2='1'};
    [0xD2] = {name = "Shift Grp2", op1='Eb', op2='CL'};
    [0xD3] = {name = "Shift Grp2", op1='Ev', op2='CL'};
    [0xD4] = {name = 'AAM'};
    [0xD5] = {name = 'AAD'};
    -- [0xD6] = {name = ''};
    [0xD7] = {name = 'XLAT'};

    [0xE0] = {name = 'LOOPNE', op1='Jb'};
    [0xE1] = {name = 'LOOPE', op1='Jb'};
    [0xE2] = {name = 'LOOP', op1='Jb'};
    [0xE3] = {name = 'JCXZ', op1='Jb'};
    [0xE4] = {name = 'IN', op1='AL', op2="Ib"};
    [0xE5] = {name = 'IN', op1='eAX', op2="Ib"};
    [0xE6] = {name = 'OUT', op1='Ib', op2='AL'};
    [0xE7] = {name = 'OUT', op1='Ib', op2='eAX'};
    

    [0xF0] = {name = "LOCK"};
    --[0xF1] - not defined
    [0xF2] = {name = 'REPNE'};
    [0xF3] = {name = 'REP'};
    [0xF4] = {name = 'HLT'};
    [0xF5] = {name = 'CMC'};
    [0xF6] = {name = 'Unary Grp3', op1='Eb'};
    [0xF7] = {name = 'Unary Grp3', op2='Ev'};
    
}

