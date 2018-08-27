--[[
    This code demangles MSVC style mangled symbols

    Original file

    https://github.com/rui314/msvc-demangler
    https:--raw.githubusercontent.com/rui314/msvc-demangler/master/MicrosoftDemangle.cpp
]]

local namespace = require("namespace")
local ns = namespace()

local ffi = require("ffi")
local bit = require("bit")
local bor, band = bit.bor, bit.band
local lshift, rshift = bit.lshift, bit.rshift

local StringBuilder = require("stringbuilder")
local TextStream = require("TextStream")
local enum = require("peettles.enum")

-- Storage classes
local StorageClass = enum {
    Const = 0x01,
    Volatile = 0x02,
    Far = 0x04,
    Huge = 0x08,
    Unaligned = 0x10,
    Restrict = 0x20,
};
enum.inject(StorageClass, ns)

-- Calling conventions
-- uint8_t
local CallingConv = enum  {
    Cdecl = 1,
    Pascal =2,
    Thiscall=3,
    Stdcall=4,
    Fastcall=5,
    Regcall=6,
};
enum.inject(CallingConv, ns)

-- Types
--  uint8_t
local PrimTy = enum {
  Unknown=0,
  None=1,
  Function=2,
  Ptr=3,
  Ref=4,
  Array=5,

  Struct=6,
  Union=7,
  Class=8,
  Enum=9,

  Void=10,
  Bool=11,
  Char=12,
  Schar=13,
  Uchar=14,
  Short=15,
  Ushort=16,
  Int=17,
  Uint=18,
  Long=19,
  Ulong=20,
  Int64=21,
  Uint64=22,
  Wchar=23,
  Float=24,
  Double=25,
  Ldouble=26,
};
enum.inject(PrimTy, ns)

-- Function classes
local FuncClass = enum {
  Public = 0x01,
  Protected = 0x02,
  Private = 0x04,
  Global = 0x08,
  Static = 0x10,
  Virtual = 0x20,
  FFar = 0x40,
};
enum.inject(FuncClass, ns)

local MAX_NAMES = 10;

--[[
namespace {
struct Type;

-- Represents an identifier which may be a template.
struct Name {
  -- Name read from an input string.
  String str;

  -- Overloaded operators are represented as special names in mangled symbols.
  -- If this is an operator name, "op" has an operator name (e.g. ">>").
  -- Otherwise, empty.
  String op;

  -- Template parameters. Null if not a template.
  Type *params = nullptr;

  -- Nested names (e.g. "A::B::C") are represented as a linked list.
  Name *next = nullptr;
};
--]]
local function Name (params)
    params = params or {}
    params.str = params.str;
    params.op = params.op;
    params.params = params.params;
    params.next = params.next;

    return params;
end

--[[
-- The type class. Mangled symbols are first parsed and converted to
-- this type and then converted to string.
struct Type {
  -- Primitive type such as Int.
  PrimTy prim;

  -- Represents a type X in "a pointer to X", "a reference to X",
  -- "an array of X", or "a function returning X".
  Type *ptr = nullptr;

  uint8_t sclass = 0;  -- storage class
  CallingConv calling_conv;
  FuncClass func_class;

  uint32_t len; -- valid if prim == Array

  -- Valid if prim is one of (Struct, Union, Class, Enum).
  Name *name = nullptr;

  -- Function parameters.
  Type *params = nullptr;

  -- Lists of types (e.g. function parameters) are represented as linked lists.
  Type *next = nullptr;
};
--]]
local function assignKind(lhs, rhs)
    lhs.prim = rhs.prim or 0;
    lhs.ptr = rhs.ptr;
    lhs.sclass = rhs.sclass or 0;
    lhs.calling_conv = rhs.calling_conv or 0;
    lhs.func_class = rhs.func_class or 0;
    lhs.len = rhs.len or 0;
    lhs.name = rhs.name;
    lhs.params = rhs.params;
    lhs.next = rhs.next;

    return lhs;
end

local function Kind(params)
    params = params or {}

    params.prim = params.prim or 0;
    params.ptr = params.ptr;
    params.sclass = params.sclass or 0;
    params.calling_conv = params.calling_conv or 0;
    params.func_class = params.func_class or 0;
    params.len = params.len or 0;
    params.name = params.name;
    params.params = params.params;
    params.next = params.next;

    return params
end


--[[
    The Essential Demangler class
--]]
local Demangler = {}
setmetatable(Demangler, {
  __call = function(self, ...)
  return self:create(...)
end,
})

local Demangler_mt = {
  __index = Demangler;
}

function Demangler.init(self, str)
    local strm = TextStream(str);

    local obj = {
      input = strm;
      names = {};
      num_names = 0;

      symbol = {};
  
      kind = Kind();  -- A parsed mangled symbol.
      error = StringBuilder();

      os = StringBuilder();
    }
    setmetatable(obj, Demangler_mt)

    return obj;
end

function Demangler.create(self, str)
    return self:init(str)
end

function Demangler.demangle(str)
    -- create state
    local dm = Demangler(str);

    -- do parsing
    local res = dm:parse();

print("RESULT: ", res.symbol.str, res.error)

    -- return demangled string string
    if not res then
      return false, err;
    end

    return res;
end

function Demangler:consume(str)
    if (not self.input:startsWith(str)) then
      return false;
    end

    self.input:trim(#str);

    return true;
end

function Demangler:expect(s) 
  
    if (not self:consume(s) and self.error:empty()) then
      self.error = self.error + s + " expected, but got " + self.input:str();
      return false;
    end

    return true;
end

-- Parser entry point.
  -- You are supposed to call parse() first and then check if error is
  -- still empty. After that, call str() to get a result.

function Demangler:parse()
    -- MSVC-style mangled symbols must start with '?'.
    if (not self:consume("?")) then
        self.symbol.str = self.input;
        self.kind.prim = Unknown;
    end

print("PARSE 1: ", self.input:str())

    -- What follows is a main symbol name. This may include
    -- namespaces or class names.
    self.symbol = self:read_name();

print("PARSE 2: ", self.symbol.str, "REMAIN:",self.input:str(), "ERR:",self.error:str())
    -- Read a variable.
    if (self:consume("3")) then
print("PARSE 3: ", "REMAIN: ", self.input:str())
      self:read_var_type(self.kind);
      return self;
    end

    -- Read a non-member function.
    if (self:consume("Y")) then
      self.kind.prim = Function;
      self.kind.calling_conv = self:read_calling_conv();
      self.kind.ptr = Kind();
      self.kind.ptr.sclass = self:read_storage_class_for_return();
      self:read_var_type(self.kind.ptr);
      self.kind.params = self:read_params();
      return self;
    end

    -- Read a member function.
    self.kind.prim = Function;
    self.kind.func_class = self:read_func_class();
    self:expect("E"); -- if 64 bit
    self.kind.sclass = self:read_func_access_class();
    self.kind.calling_conv = self:read_calling_conv();

    self.kind.ptr = Kind();
    self.kind.ptr.sclass = self:read_storage_class_for_return();
    self:read_func_return_type(self.kind.ptr);
    self.kind.params = self:read_params();

    return self;
end

--[[
-- Sometimes numbers are encoded in mangled symbols. For example,
-- "int (*x)[20]" is a valid C type (x is a pointer to an array of
-- length 20), so we need some way to embed numbers as part of symbols.
-- This function parses it.
--
-- <number>               ::= [?] <non-negative integer>
--
-- <non-negative integer> ::= <decimal digit> # when 1 <= Number <= 10
--                        ::= <hex digit>+ @  # when Numbrer == 0 or >= 10
--
-- <hex-digit>            ::= [A-P]           # A = 0, B = 1, ...
--]]
function Demangler:read_number()
    local neg = self:consume("?");

    -- the easy case, where a number is the first thing
    if (self.input:startsWithDigit()) then
        local ret = self.input:peekDigit() + 1;
        self.input:trim(1);
        if neg then return -ret end

        return ret;
    end

    local ret = 0;
    for i = 0, self.input:length() do
        local c = self.input:peek();
        if (c == string.byte('@')) then
            self.input:trim(i + 1);

            if neg then 
              return -ret
            end
            return ret;
        end

        if (string.byte('A') <= c and c <= string.byte('P')) then
            ret = lshift(ret, 4) + (c - string.byte('A'));
        else
            break;
        end
    end

    if (self.error:empty()) then
        self.error = self.error + "bad number: " + self.input:str();
    end

    return 0;
end

-- Read until the next '@'.
function Demangler:read_string(memorize) 
    for i = 0, self.input:length()-1 do
      if (self.input:peek(i) == string.byte('@')) then
        local ret = self.input:substr(0, i);
        self.input:trim(i + 1);
  
        if (memorize) then
          self:memorize_string(ret);
        end
  
        return ret;        
      end
    end

    if (self.error:empty()) then
      self.error = self.error + "read_string: missing '@': " + self.input:str();
    end

    return "";
end


-- First 10 strings can be referenced by special names ?0, ?1, ..., ?9.
-- Memorize it.
function Demangler:memorize_string(s)
    if self.num_names > MAX_NAMES then
      return self;
    end

    for i=0, self.num_names-1 do 
      if self.names[i] == s then 
        return true;
      end
    end
    self.num_names = self.num_names + 1;
    self.names[self.num_names] = s;
end

-- Parses a name in the form of A@B@C@@ which represents C::B::A.
function Demangler:read_name()
    local head = nil;

print("read_name (1) : ", self.input:str())
  while (not self:consume("@")) do
print("read_name(2) : ", self.input:str())
    local elem = Name();

    if (self.input:startsWithDigit()) then
      local i = self.input:peek() - string.byte('0');
print("read_name(2.1), i: ", i)
      if (i >= self.num_names) then
        if (self.error:empty()) then
          self.error = self.error + "name reference too large: " + self.input:str();
        end
        return {};
      end
      self.input:trim(1);
      elem.str = self.names[i];
    elseif (self:consume("?$")) then
      -- Class template.
      elem.str = self:read_string(false);
      elem.params = self:read_params();
      self:expect("@");
    elseif (self:consume("?")) then
      -- Overloaded operator.
      self:read_operator(elem);
    else

      -- Non-template functions or classes.
      elem.str = self:read_string(true);
      print("read_string (2.4): ", elem.str)
    end

    elem.next = head;
    head = elem;
  end

  return head;
end

function Demangler:read_func_ptr(ty)
  local tp = Kind();
  tp.prim = Function;
  tp.ptr = Kind();
  self:read_var_type(tp.ptr);
  tp.params = self:read_params();

  ty.prim = Ptr;
  ty.ptr = tp;

  if (self.input:startsWith("@Z")) then
    self.input:trim(2);
  elseif (self.input:startsWith("Z")) then
    self.input:trim(1);
  end
end



local operatorName = {
    ['0'] = "ctor";
    ['1'] = "dtor";
    ['2'] = " new";
    ['3'] = " delete";
    ['4'] = "=";
    ['5'] = ">>";
    ['6'] = "<<";
    ['7'] = "!";
    ['8'] = "==";
    ['9'] = "!=";
    ['A'] = "[]";
    ['C'] = ".";
    ['D'] = "*";
    ['E'] = "++";
    ['F'] = "--";
    ['G'] = "-";
    ['H'] = "+";
    ['I'] = "&";
    ['J'] = ".*";
    ['K'] = "/";
    ['L'] = "%";
    ['M'] = "<";
    ['N'] = "<=";
    ['O'] = ">";
    ['P'] = ">=";
    ['Q'] = ",";
    ['R'] = "()";
    ['S'] = "~";
    ['T'] = "^";
    ['U'] = "|";
    ['V'] = "&&";
    ['W'] = "||";
    ['X'] = "*=";
    ['Y'] = "+=";
    ['Z'] = "-=";
    ['_'] = {
      ['0'] = "/=";
      ['1'] = "%=";
      ['2'] = ">>=";
      ['3'] = "<<=";
      ['4'] = "&=";
      ['5'] = "|=";
      ['6'] = "^=";
      ['U'] = " new[]";
      ['V'] = " delete[]";
    };
}


function Demangler:read_operator_name()
  local orig = self.input:clone();

  local function returnError()
    if (self.error:empty()) then
      self.error = self.error + "unknown operator name: " + orig:str();
    end
  
    return "";
  end

  local achar = self.input:get()
  local rhs1 = operatorName[achar]

  if not rhs1 then
    -- didn't find the operator in the table
    return returnError();
  end

  -- found a straight translation
  if type(rhs1) ~= "table" then
    return rhs1;
  end

  -- right hand side is a table, so get another
  -- character to lookup
  achar = self.input:get();
  local rhs2 = rhs1[achar]
  
  if not rhs2 then
    return returnError();
  end

  -- again, got a rhs, so return it
  if rhs2 == '_' then
    if self:consume("L") then
      return " co_await";
    end

    return rhs2;
  end

  return returnError()
end

function Demangler:read_operator(name)
    name.op = self:read_operator_name();
    if (self.error:empty() and self.input:peek() ~= '@') then
        name.str = self:read_string(true);
    end
end

function Demangler:read_func_class()
    local c = self.input:get();

    if c == string.byte('A') then return Private;
    elseif c == string.byte('B') then return bor(Private, FFar);
    elseif c == string.byte('C') then return bor(Private, Static);
    elseif c == string.byte('D') then return bor(Private, Static);
    elseif c == string.byte('E') then return bor(Private, Virtual);
    elseif c == string.byte('F') then return bor(Private, Virtual);
    elseif c == string.byte('I') then return Protected;
    elseif c == string.byte('J') then return bor(Protected, FFar);
    elseif c == string.byte('K') then return bor(Protected, Static);
    elseif c == string.byte('L') then return bor(Protected, Static, FFar);
    elseif c == string.byte('M') then return bor(Protected, Virtual);
    elseif c == string.byte('N') then return bor(Protected, Virtual, FFar);
    elseif c == string.byte('Q') then return Public;
    elseif c == string.byte('R') then return bor(Public, FFar);
    elseif c == string.byte('S') then return bor(Public, Static);
    elseif c == string.byte('T') then return bor(Public, Static, FFar);
    elseif c == string.byte('U') then return bor(Public, Virtual);
    elseif c == string.byte('V') then return bor(Public, Virtual, FFar);
    elseif c == string.byte('Y') then return Global;
    elseif c == string.byte('Z') then return bor(Global, FFar);
    end

    self.input:unget(c);
    if (self.error:empty()) then
        self.error = self.error + "unknown func class: " + self.input:str();
    end

    return 0;
end


local FuncAccessClass = {
  A = Cdecl;
  B = Cdecl;
  C = Pascal;
  E = Thiscall;
  G = Stdcall;
  I = Fastcall;
}

function Demangler:read_func_access_class()
    local c = self.input:get();
    local rhs = FuncAccessClass[c]
    if rhs then
      return rhs;
    end

    self.input:unget(c);

    return 0;
end

function  Demangler:read_calling_conv() 

    local orig = self.input:clone();

    local c = self.input:get();

    if c == string.byte('A') then return Cdecl;
    elseif c == string.byte('B') then return Cdecl;
    elseif c == string.byte('C') then return Pascal;
    elseif c == string.byte('E') then return Thiscall;
    elseif c == string.byte('G') then return Stdcall;
    elseif c == string.byte('I') then return Fastcall;
    end

    if (self.error:empty()) then
      self.error = self.error + "unknown calling convention: " + orig:str();
    end

    return Cdecl;
end

-- <return-type> ::= <type>
--               ::= @ # structors (they have no declared return type)
function Demangler:read_func_return_type(ty)
  if (self:consume("@")) then
    ty.prim = None;
  else
    self:read_var_type(ty);
  end

  return self;
end

function Demangler:read_storage_class()
    local c = self.input:get();

  if c == string.byte('A') then return 0;
  elseif c == string.byte('B') then return Const;
  elseif c == string.byte('C') then return Volatile;
  elseif c == string.byte('D') then return bor(Const, Volatile);
  elseif c == string.byte('E') then return Far;
  elseif c == string.byte('F') then return bor(Const, Far);
  elseif c == string.byte('G') then return bor(Volatile, Far);
  elseif c == string.byte('H') then return bor(Const, Volatile, Far);
  end

    self.input:unget(c);
    return 0;
end

function Demangler:read_storage_class_for_return()
    if (not self:consume("?")) then
      return 0;
    end

    local orig = input:clone();

    local c = self.input:get();

    if c == string.byte('A') then return 0;
    elseif c == string.byte('B') then return Const;
    elseif c == string.byte('C') then return Volatile;
    elseif c == string.byte('D') then return bor(Const, Volatile); 
    end

    -- default case
    if (self.error:empty()) then
        self.error = self.error + "unknown storage class: " + orig:str();
    end

    return 0;
end


-- Reads a variable kind.
function Demangler:read_var_type(ty) 
  --print("read_var_type (1): ", ty)
  if (self:consume("W4")) then
    ty.prim = Enum;
    ty.name = self:read_name();
    return self;
  end

  --print("read_var_type (2): ", "REMAIN: ", self.input:str())
  if (self:consume("P6A")) then
    return self:read_func_ptr(ty);
  end

  local c = self.input:get();
  --print("read_var_type (3): ", string.char(c))

  if c == string.byte('T') then
    return self:read_class(ty, Union);
  elseif c == string.byte('U') then
    return self:read_class(ty, Struct);
  elseif c == string.byte('V') then
    return self:read_class(ty, Class);
  elseif c == string.byte('A') then
    return self:read_pointee(ty, Ref);
  elseif c == string.byte('P') then
    return self:read_pointee(ty, Ptr);
  elseif c == string.byte('Q') then
    self:read_pointee(ty, Ptr);
    ty.sclass = Const;
    return self;
  elseif c == string.byte('Y') then
    return self:read_array(ty);
  else
    self.input:unget(c);
--print("read_var_type (4): ", self.input:str())
    ty.prim = self:read_prim_type();
    return self;
  end
end

-- Reads a primitive kind.
local PrimitiveType = {
    X = Void;
    D = Char;
    C = Schar;
    E = Uchar;
    F = Short;
    G = Ushort;
    H = Int;
    I = Uint;
    J = Long;
    K = Ulong;
    M = Float;
    N = Double;
    O = Ldouble;
    ['_'] = {
      N = Bool;
      J = Int64;
      K = Uint64;
      W = Wchar;
    }
}

function Demangler:read_prim_type() 
--print("read_prim_type (1): ", self.input:str())
    local orig = self.input:clone();
--print("read_prim_type (2): ", orig:str())
    local c = string.char(self.input:get());
--print("read_prim_type (3): ", c)
    local rhs = PrimitiveType[c]
--print("read_prim_type (4): ", rhs)

    if rhs and type(rhs) == "number" then
        return rhs;
    elseif rhs and type(rhs) == "table" then
        c = string.char(self.input:get())
        local primtype = rhs[c];
        if primtype then
            return primtype;
        end
    end 

    if (self.error:empty()) then
          self.error = self.error + "unknown primitive type: " + orig:str();
    end

    return Unknown;
end

function Demangler:read_class(ty, prim)
    ty.prim = prim;
    ty.name = self:read_name();

    return self;
end

function Demangler:read_pointee(ty, prim)
    ty.prim = prim;
    self:expect("E"); -- if 64 bit
    ty.ptr = Kind();
    ty.ptr.sclass = self:read_storage_class();
    self:read_var_type(ty.ptr);

    return self;
end

function Demangler:read_array(ty)
  local dimension = self:read_number();
  if (dimension <= 0) then
    if (self.error:empty()) then
      self.error = self.error + "invalid array dimension: " + tostring(dimension);
    end

    return self;
  end

  local tp = ty;
  for i = 0, dimension-1 do
    tp.prim = Array;
    tp.len = self:read_number();
    tp.ptr = Kind();
    tp = tp.ptr;
  end

  if (self:consume("$$C")) then
    if (self:consume("B")) then
      ty.sclass = Const;
    elseif (self:consume("C") or self:consume("D")) then
      ty.sclass = bor(Const, Volatile);
    elseif (not self:consume("A") and self.error:empty()) then
      self.error = self.error + "unkonwn storage class: " + self.input:str();
    end
  end

  self:read_var_type(tp);

  return self;
end


-- Reads a function or a template parameters.
function Demangler:read_params()
  -- Within the same parameter list, you can backreference the first 10 types.
  local backref = {};
  local idx = 0;

  local head = Kind();
  local tp = head;

  while (self.error:empty() and not self.input:startsWith('@') and not self.input:startsWith('Z')) do
    if (self.input:startsWithDigit()) then
      local n = self.input:peekDigit();
      if (n >= idx) then
        if (self.error:empty()) then
          self.error = self.error + "invalid backreference: " + self.input:str();
        end
        return nil;
      end

      self.input:trim(1);

      tp = assignKind(tp, backref[n]);
      tp.next = Kind();
      tp = tp.next;
    else
      local len = self.input:length();

      tp = Kind();
      self:read_var_type(tp);

      -- Single-letter types are ignored for backreferences because
      -- memorizing them doesn't save anything.
      if (idx <= 9 and len - self.input:length() > 1) then
        backref[idx] = tp;
        idx = idx + 1;
      end

      tp = tp.next;
    end
  end

  return head;
end




--[=[
  This should be attached to the 'Kind' class

-- Converts an AST to a string.
--
-- Converting an AST representing a C++ type to a string is tricky due
-- to the bad grammar of the C++ declaration inherited from C. You have
-- to construct a string from inside to outside. For example, if a type
-- X is a pointer to a function returning int, the order you create a
-- string becomes something like this:
--
--   (1) X is a pointer: *X
--   (2) (1) is a function returning int: int (*X)()
--
-- So you cannot construct a result just by appending strings to a result.
--
-- To deal with this, we split the function into two. write_pre() writes
-- the "first half" of type declaration, and write_post() writes the
-- "second half". For example, write_pre() writes a return type for a
-- function and write_post() writes an parameter list.
local TypeWriter = {}

function TypeWriter:write(ast)
    write_pre(type);
    write_name(symbol);
    write_post(type);
    return os.str();
end
  
function TypeWriter:str()  -- toString 
  write_pre(type);
  write_name(symbol);
  write_post(type);

  return os:str();
end

-- Write the "first half" of a given kind.
function TypeWriter:write_pre(Type &ty) {
  switch (ty.prim) {
  case Unknown:
  case None:
    break;
  case Function:
    write_pre(*ty.ptr);
    return;
  case Ptr:
  case Ref:
    write_pre(*ty.ptr);

    -- "[]" and "()" (for function parameters) take precedence over "*",
    -- so "int *x(int)" means "x is a function returning int *". We need
    -- parentheses to supercede the default precedence. (e.g. we want to
    -- emit something like "int (*x)(int)".)
    if (ty.ptr.prim == Function || ty.ptr.prim == Array)
      os << "(";

    if (ty.prim == Ptr)
      os << "*";
    else
      os << "&";
    break;
  case Array:
    write_pre(*ty.ptr);
    break;

  case Struct: write_class(ty.name, "struct"); break;
  case Union:  write_class(ty.name, "union"); break;
  case Class:  write_class(ty.name, "class"); break;
  case Enum:   write_class(ty.name, "enum"); break;
  case Void:    os << "void"; break;
  case Bool:    os << "bool"; break;
  case Char:    os << "char"; break;
  case Schar:   os << "signed char"; break;
  case Uchar:   os << "unsigned char"; break;
  case Short:   os << "short"; break;
  case Ushort:  os << "unsigned short"; break;
  case Int:     os << "int"; break;
  case Uint:    os << "unsigned int"; break;
  case Long:    os << "long"; break;
  case Ulong:   os << "unsigned long"; break;
  case Int64:   os << "int64_t"; break;
  case Uint64:  os << "uint64_t"; break;
  case Wchar:   os << "wchar_t"; break;
  case Float:   os << "float"; break;
  case Double:  os << "double"; break;
  case Ldouble: os << "long double"; break;
  }

  if (ty.sclass & Const) {
    write_space();
    os << "const";
  }
}

-- Write the "second half" of a given kind.
function TypeWriter:write_post(Type &ty)
  if (ty.prim == Function) {
    os << "(";
    write_params(ty.params);
    os << ")";
    if (ty.sclass & Const)
      os << "const";
    return;
  }

  if (ty.prim == Ptr || ty.prim == Ref) {
    if (ty.ptr.prim == Function || ty.ptr.prim == Array)
      os << ")";
    write_post(*ty.ptr);
    return;
  }

  if (ty.prim == Array) {
    os << "[" << ty.len << "]";
    write_post(*ty.ptr);
  }
end

-- Write a function or template parameter list.
function TypeWriter:write_params(Type *params) {
  for (Type *tp = params; tp; tp = tp.next) {
    if (tp != params)
      os << ",";
    write_pre(*tp);
    write_post(*tp);
  }
}

function TypeWriter:write_class(Name *name, String s) {
  os << s << " ";
  write_name(name);
}

-- Write a name read by read_name().
function TypeWriter:write_name(Name *name) {
  if (!name)
    return;
  write_space();

  -- Print out namespaces or outer class names.
  for (; name.next; name = name.next) {
    os << name.str;
    write_tmpl_params(name);
    os << "::";
  }

  -- Print out a regular name.
  if (name.op:empty()) {
    os << name.str;
    write_tmpl_params(name);
    return;
  }

  -- Print out ctor or dtor.
  if (name.op == "ctor" || name.op == "dtor") {
    os << name.str;
    write_params(name.params);
    os << "::";
    if (name.op == "dtor")
      os << "~";
    os << name.str;
    return;
  }

  -- Print out an overloaded operator.
  if (!name.str:empty())
    os << name.str << "::";
  os << "operator" << name.op;
}

function TypeWriter:write_tmpl_params(Name *name) {
  if (!name.params)
    return;
  os << "<";
  write_params(name.params);
  os << ">";
}

-- Writes a space if the last token does not end with a punctuation.
function TypeWriter:write_space() 

  std::string s = os.str();
  if (!s:empty() && isalpha(s.back()))
    os << " ";
end
--]=]

return Demangler