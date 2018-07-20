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
    'A' = "Direct Address";
    'C' = " The reg field of the ModR/M byte selects the control register";
    'D' = "";
    'E' = "";
    'F' = "EFLAGS register";
    'G' = "The reg field of ModR/M byte selects a general purpose register";
    'I' = "Immediate data";
    'J' = "The instruction contains relative offset to be added to the instruction pointer register";
    'M' = " The ModR/M may refer to only memory";
    'O' = " The instruction has no ModR/M byte. The offset of the operand is             coded as word or double word in the instruction. No base register,             Index register, or Scale factor can be applied";
    'P' = " The reg field of the ModR/M byte selects a packed quadword ";
    'Q' = "";
    'R' = "";
    'S' = "";
    'T' = "";
    'V' = "";
    'W' = "";
    'X' = "";
    'Y' = "";
}