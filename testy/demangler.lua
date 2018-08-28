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
    Cdecl = 0,
    Pascal =1,
    Thiscall=2,
    Stdcall=3,
    Fastcall=4,
    Regcall=5,
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
    params.str = params.str or "";
    params.op = params.op or "";
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

--  This should be attached to the 'Kind' class
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
local function strempty(str)
    if not str then return true end
    if #str == 0 then return true end
        
    return false;
end

local TypeWriter = {}
setmetatable(TypeWriter, {
      __call = function(self,...)
          return self:create(...);
      end;
})
local TypeWriter_mt = {
      __index = TypeWriter;
  
      __tostring = function(self)
          return self:str();
      end;
}
  
function TypeWriter.init(self, ast)
      local obj = {
        ast = ast;
      }
      setmetatable(obj, TypeWriter_mt);
  
      return obj;
end
  
function TypeWriter.create(self, ...)
      return self:init(...);
end
  
function TypeWriter:str()  -- toString 
      self.os = StringBuilder();
      self:write_pre(self.ast.kind);
      self:write_name(self.ast.symbol);
      self:write_post(self.ast.kind);
  
      return self.os:str();
end
  
  -- Write the "first half" of a given kind.
function TypeWriter:write_pre(ty)
      local typrim = ty.prim;
      local os = self.os;
  
      if typrim == Unknown or typrim == None then
--print("write_pre (2.0): ", typrim)
        -- nothing
      elseif typrim == Function then
          self:write_pre(ty.ptr);
          return;
      elseif typrim == Ptr or typrim == Ref then
          self:write_pre(ty.ptr);
  
      -- "[]" and "()" (for function parameters) take precedence over "*",
      -- so "int *x(int)" means "x is a function returning int *". We need
      -- parentheses to supercede the default precedence. (e.g. we want to
      -- emit something like "int (*x)(int)".)
          if (ty.ptr.prim == Function or ty.ptr.prim == Array) then
              os = os + "(";
          end
  
          if (ty.prim == Ptr) then
              os = os + "*";
          else
              os = os + "&";
          end
      elseif typrim == Array then
          self:write_pre(ty.ptr);
      elseif typrim == Struct then
          self:write_class(ty.name, "struct");
      elseif typrim == Union then  self:write_class(ty.name, "union");
      elseif typrim == Class then  self:write_class(ty.name, "class");
      elseif typrim == Enum then   self:write_class(ty.name, "enum");
      elseif typrim == Void then    os = os + "void";
      elseif typrim == Bool then    os = os + "bool";
      elseif typrim ==  Char then    os = os + "char";
      elseif typrim ==  Schar then   os = os + "signed char";
      elseif typrim ==  Uchar then   os = os + "unsigned char";
      elseif typrim ==  Short then   os = os + "short";
      elseif typrim ==  Ushort then  os = os + "unsigned short";
      elseif typrim ==  Int then     os = os + "int";
      elseif typrim ==  Uint then    os = os + "unsigned int";
      elseif typrim ==  Long then    os = os + "long";
      elseif typrim ==  Ulong then   os = os + "unsigned long";
      elseif typrim ==  Int64 then   os = os + "int64_t";
      elseif typrim ==  Uint64 then  os = os + "uint64_t";
      elseif typrim ==  Wchar then   os = os + "wchar_t";
      elseif typrim ==  Float then   os = os + "float";
      elseif typrim ==  Double then  os = os + "double";
      elseif typrim ==  Ldouble then os = os + "long double";
      end
  
      if band(ty.sclass, Const) ~= 0 then
          self:write_space();
          os = os + "const";
      end
end
  
  -- Write the "second half" of a given kind.
function TypeWriter:write_post(ty)
      local os = self.os;
  --print("write_post (1.0): ", ty.prim)
      if (ty.prim == Function) then
        --print("write_post (1.1): ", ty.params)
        os = os + "(";
        self:write_params(ty.params);
        os = os + ")";
        if band(ty.sclass, Const) ~= 0 then
          os = os + "const";
        end
  
        return;
      end
  
      if (ty.prim == Ptr or ty.prim == Ref) then
          if (ty.ptr.prim == Function or ty.ptr.prim == Array) then
            os = os + ")";
          end
          self:write_post(ty.ptr);
          return;
      end
  
      if (ty.prim == Array) then
          os = os + "[" + ty.len + "]";
          self:write_post(ty.ptr);
      end
end
  
  -- Write a function or template parameter list.
function TypeWriter:write_params(params)
      local tp = params;
      local os = self.os;
  
      while tp ~= nil do
          if tp ~= params then
              os = os + ",";
          end
          self:write_pre(tp);
          self:write_post(tp);
  
          tp = tp.next;
      end
end
  
function TypeWriter:write_class(name, s)
      self.os = self.os + s + " ";
      self:write_name(name);
end
  

-- Write a name read by read_name().
function TypeWriter:write_name(name)
      local os = self.os;
  
      if (not name) then
          return;
      end
  
      self:write_space();
  
      -- Print out namespaces or outer class names.
      local nm = name;
      while name.next do
          os = os + name.str;
          self:write_tmpl_params(name);
          os = os + "::";
  
          name = name.next;
      end
  
      -- Print out a regular name.
      if (strempty(name.op)) then
          os = os + name.str;
          self:write_tmpl_params(name);
          
          return;
      end
  
      -- Print out ctor or dtor.
      if (name.op == "ctor" or name.op == "dtor") then
          os = os + name.str;
          self:write_params(name.params);
          os = os + "::";
          if name.op == "dtor" then
              os = os + "~";
          end
      
          os = os + name.str;
          return;
      end
  
      -- Print out an overloaded operator.
      if (not strempty(name.str)) then
          os = os + name.str + "::";
      end
      
      os = os + "operator" + name.op;
end
  
function TypeWriter:write_tmpl_params(name)
      local os = self.os;
  
      if (not name.params) then
          return;
      end
      
      os = os + "<";
      self:write_params(name.params);
      os = os + ">";
end
  
-- Writes a space if the last token does not end with a punctuation.
local function isalpha(c)
    return (c >= string.byte('a') and c <= string.byte('z')) or
      (c >= string.byte('A') and c <= string.byte('Z'))
end
  
function TypeWriter:write_space() 
--print(string.format("write_space (1.0): '%s'", self.os:str()))
      if (not self.os:empty()) then
          local s = self.os:str();
--print(string.format("write_space (2.0): '%s'", s))
          if isalpha(string.byte(s, #s)) then
              self.os = self.os + " ";
          end
      end
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

    -- return demangled string string
    if not dm.error:empty() then
      return false, dm.error:str();
    end

    local tw = TypeWriter(dm)

    return tw:str();
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

--print("PARSE 1: ", self.input:str())

    -- What follows is a main symbol name. This may include
    -- namespaces or class names.
    self.symbol = self:read_name();

--print("PARSE 2: ", self.symbol.str, "REMAIN:",self.input:str(), "ERR:",self.error:str())
    -- Read a variable.
    if (self:consume("3")) then
--print("PARSE 3: ", "REMAIN: ", self.input:str())
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

--print("read_name (1) : ", self.input:str())
  while (not self:consume("@")) do
--print("read_name(2) : ", self.input:str())
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
--print("read_string (2.4): ", elem.str)
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

  local achar = string.char(self.input:get())
  local rhs1 = operatorName[achar]

  if rhs1 then
    if type(rhs1) == "string" then 
        return rhs1;
    elseif type(rhs1) == "table" then
        achar = string.char(self.input:get())
        local rhs2 = rhs1[achar];
        if rhs2 then
            return rhs2;
        end
    end
  end

  if (self.error:empty()) then
    self.error = self.error + "unknown operator name: " + orig:str();
  end

  return "";
end

function Demangler:read_operator(name)
    name.op = self:read_operator_name();
    if (self.error:empty() and self.input:peek() ~= '@') then
        name.str = self:read_string(true);
    end
end

function Demangler:read_func_class()
--print("read_func_class: ", self.input:str())

    local c = self.input:get();
--print("read_func_class (2.0): ",string.char(c))

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
--print("read_func_access_class (1.0): ", self.input:str())
    local c = string.char(self.input:get());
    local rhs = FuncAccessClass[c]
    if rhs then
      return rhs;
    end

    self.input:unget(c);

    return 0;
end

function  Demangler:read_calling_conv() 
--print("read_calling_conv (1.0): ", self.input:str())
    local orig = self.input:clone();

    --local c = self.input:get();

    local c = string.char(self.input:get());
    local rhs = FuncAccessClass[c]
    if rhs then
      return rhs;
    end

--[[
    if c == string.byte('A') then return Cdecl;
    elseif c == string.byte('B') then return Cdecl;
    elseif c == string.byte('C') then return Pascal;
    elseif c == string.byte('E') then return Thiscall;
    elseif c == string.byte('G') then return Stdcall;
    elseif c == string.byte('I') then return Fastcall;
    end
--]]

    if (self.error:empty()) then
      self.error = self.error + "unknown calling convention: " + orig:str();
    end

    return Cdecl;
end

-- <return-type> ::= <type>
--               ::= @ # structors (they have no declared return type)
function Demangler:read_func_return_type(ty)
--print("read_func_return_type (1.0): ", self.input:str())
    if (self:consume("@")) then
        ty.prim = None;
    else
--print("read_func_return_type (1.1): ")
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
--print("read_storage_class_for_return (1.0): ", self.input:str())
    if (not self:consume("?")) then
      return 0;
    end
--print("read_storage_class_for_return (2.0): ", self.input:str())

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
--print("read_var_type (1): ", self.input:str())
  if (self:consume("W4")) then
    ty.prim = Enum;
    ty.name = self:read_name();
    return self;
  end

--print("read_var_type (2): ", self.input:str())
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
--print("read_prim_type (4.2): ", c)
        local primtype = rhs[c];
--print("read_prim_type (4.2.3): ", primtype)
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
  local tp = nil;
  local head = nil;

--print("read_params (1.0): ", self.input:str())
  local idx = 0;
  while (self.error:empty() and not self.input:startsWith('@') and not self.input:startsWith('Z')) do
--print("read_params (1.1): ", self.input:str())
    if (self.input:startsWithDigit()) then
--print("read_params (1.1.1): ", self.input:str())
      local n = self.input:peekDigit();
      if (n >= idx) then
        if (self.error:empty()) then
          self.error = self.error + "invalid backreference: " + self.input:str();
        end
        return nil;
      end

      self.input:trim(1);

      if not tp then
        tp = Kind();
        head = tp;
      end

      tp = assignKind(tp, backref[n]);
      tp.next = Kind();
      tp = tp.next;
    else
      local len = self.input:length();
--print("read_params (1.2): ", len)
      if not tp then
        tp = Kind();
        head = tp;
      else
        tp.next = Kind();
        tp = tp.next;
      end

      self:read_var_type(tp);

      -- Single-letter types are ignored for backreferences because
      -- memorizing them doesn't save anything.
      if (idx <= 9 and len - self.input:length() > 1) then
print("read_params (1.3): ", idx)
        backref[idx] = tp;
        idx = idx + 1;
      end

      --tp.next = Kind();
      --tp = tp.next;
    end
  end

  return head;
end

return Demangler