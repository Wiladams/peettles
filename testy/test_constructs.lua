package.path = "../?.lua;"..package.path

local enum = require("peettles.enum")

-- create a namespace
local namespace = {}
setmetatable(namespace, {__index= _G})
setfenv(1, namespace)
---------------------

local x86_operand_type = enum {
	OP_IMM = 0,
	OP_MEM = 1,
	OP_MEM_DISP = 2,
	OP_REG = 3,
	OP_SEG_REG = 4,
	OP_REL = 5,
};

enum.inject(x86_operand_type, namespace)

print("_G.OP_IMM: ", _G.OP_MEM)
print("namespace.OP_IMM: ", namespace.OP_MEM)
print("local OP_MEM: ", OP_MEM)


local mod_dst_decode = {
    [0] = OP_MEM,
    OP_SEG_REG,
    OP_REL,
};

for idx=0,2 do 
    print(idx, mod_dst_decode[idx])
end

for k,v in pairs(mod_dst_decode) do
    print(k,v)
end
