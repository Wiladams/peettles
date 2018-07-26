package.path = "../?.lua;"..package.path

-- Use the in-built disassembler
local ffi = require("ffi")
--local disasm = require("dis_x86")
local binstream = require("peettles.binstream")
local enum = require("peettles.enum")
local disasm = require("dis_x64")
local x86_decode = require("x86_decode")

local x86_instr = enum (require("x86_instructions"))

-- binary encode a string
local codeLength = 64;
local code = [[\x0E\x1F\xBA\x0E\x00\xB4\x09\xCD\x21\xB8\x01\x4C\xCD\x21\x54\x68\x69\x73\x20\x70\x72\x6F\x67\x72\x61\x6D\x20\x63\x61\x6E\x6E\x6F\x74\x20\x62\x65\x20\x72\x75\x6E\x\x20\x69\x6E\x20\x44\x4F\x53\x20\x6D\x6F\x64\x65\x2E\x0D\x0D\x0A\x24\x00\x00\x00\x00\x00\x00\x00]]

code=code:gsub("\\x(%x%x)",function (x) return string.char(tonumber(x,16)) end)



local function test_disasm()

--print(string.format("%x %d %o ", 0xd8, 0xd8, 0xd8))
disasm.disass(code, 0x007FFFFFFF400000)
end

local function printInstruction(instr)
    print(string.format("0x%x", instr.opcode), x86_instr[instr.opcode], instr.nr_bytes, instr.width)
end


local function test_x86_decode()
    local bs = binstream(code, codeLength)
    while not bs:EOF() do
        local instr = ffi.new("struct x86_instr");
        x86_decode.decodeInstruction(instr, bs)

        printInstruction(instr)
    end
end

test_x86_decode();
