package.path = "../?.lua;"..package.path

local enum = require("peettles.enum")
--local namespace = require("namespace")()


local function namespace(name)
	local function closure(params)
		res = res or {}
		res._name = name;
    	setmetatable(res, {__index= _G})
    	setfenv(2, res)
		return res
	end

	return closure;
end

namespace 'operands' {
x86_operand_type = enum {
	OP_IMM = 0,
	OP_MEM = 1,
	OP_MEM_DISP = 2,
	OP_REG = 3,
	OP_SEG_REG = 4,
	OP_REL = 5,
};

enum.inject(x86_operand_type, namespace);

test_namespace = function()

print("_G.OP_IMM (nil): ", _G.OP_MEM)
print("namespace.OP_IMM (1): ", namespace.OP_MEM)
print("local OP_MEM (1): ", OP_MEM)



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
end;
}

local function test_namedparams()
local function foo(name)
	print(name)
	local function bar(params)
		for k,v in pairs(params) do
			print(k,v)
		end
	end

	return bar
end

foo 'myname' {
	Alpha = 1;
	Beta = 2;
}
end

test_namespace()
