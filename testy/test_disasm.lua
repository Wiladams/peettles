-- Use the in-built disassembler
local ffi = require("ffi")
--local disasm = require("dis_x86")
local disasm = require("dis_x64")

local codeLength = 25;
local code =[[\x51\x8D\x45\xFF\x50\xFF\x75\x0C\xFF\x75\x08\xFF\x15\xA0\xA5\x48\x76\x85\xC0\x0F\x88\xFC\xDA\x02\x00]];
code=code:gsub("\\x(%x%x)",function (x) return string.char(tonumber(x,16)) end)
--[[
007FFFFFFF400000   push rcx
007FFFFFFF400001   lea eax, [rbp-0x01]
007FFFFFFF400004   push rax
007FFFFFFF400005   push qword ptr [rbp+0x0C]
007FFFFFFF400008   push qword ptr [rbp+0x08]
007FFFFFFF40000B   call [0x008000007588A5B1]
007FFFFFFF400011   test eax, eax
007FFFFFFF400013   js 0x007FFFFFFF42DB15
--]]



--print(string.format("%x %d %o ", 0xd8, 0xd8, 0xd8))
disasm.disass(code, 0x007FFFFFFF400000)


