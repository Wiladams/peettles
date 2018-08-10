package.path = "../?.lua;"..package.path

local enum = require("peettles.enum")
--local namespace = require("namespace")()


local function namespace(name)

	local function closure(params)
		res = res or {}
		res._name = name or "namespace";
    	setmetatable(res, {__index= _G})
    	setfenv(2, res)
		return res
	end

	return closure;
end

local nspace = namespace 'frolic' {}
--namespace 'operands' {
local x86_operand_type = enum {
	OP_IMM = 0,
	OP_MEM = 1,
	OP_MEM_DISP = 2,
	OP_REG = 3,
	OP_SEG_REG = 4,
	OP_REL = 5,
};

enum.inject(x86_operand_type, nspace);

local function test_namespace()

print("_G.OP_IMM (nil): ", _G.OP_MEM)
print("namespace.OP_IMM (1): ", nspace.OP_MEM)
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
--}

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

local function test_sparse_enum()
	local SymStorageClass = enum {
		[0XFF] = "IMAGE_SYM_CLASS_END_OF_FUNCTION";
		[0] = "IMAGE_SYM_CLASS_NULL";
		"IMAGE_SYM_CLASS_AUTOMATIC";
		[100] = "IMAGE_SYM_CLASS_BLOCK";
		"IMAGE_SYM_CLASS_FUNCTION";
		"IMAGE_SYM_CLASS_END_OF_STRUCT";
		"IMAGE_SYM_CLASS_FILE";
		"IMAGE_SYM_CLASS_SECTION";
		"IMAGE_SYM_CLASS_WEAK_EXTERNAL";
		[107] = "IMAGE_SYM_CLASS_CLR_TOKEN";
	};

	print(" FUNCTION: ", SymStorageClass[0xff])
	print("     NULL: ", SymStorageClass[0])
	print("AUTOMATIC: ", SymStorageClass[1])
	print("    BLOCK: ", SymStorageClass[100])
	print("CLR_TOKEN: ", SymStorageClass[107])
end

--test_namespace()
--test_namedparams();
test_sparse_enum();

