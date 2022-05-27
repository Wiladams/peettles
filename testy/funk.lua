--[[
    lua functional programming routines.

    Originally inspired by: https://luafun.github.io/index.html
]]

local ffi = require("ffi")

local floor, ceil, pow = math.floor, math.ceil, math.pow
local unpack = rawget(table, "unpack") or unpack

-- These are used to expose the function interface of
-- the module
local exports = {}

-- These are used to expose the object interface of
-- the module
local methods = {}

exports.operator = {}
exports.op = exports.operator

--[[
    Comparison Operators
--]]
function exports.operator.le(a,b) return a <= b end
function exports.operator.lt(a,b) return a < b end
function exports.operator.eq(a,b) return a == b end
function exports.operator.ne(a,b) return a ~= b end
function exports.operator.ge(a,b) return a >= b end
function exports.operator.gt(a,b) return a > b end

--[[
    Arithmetic Operators
--]]
function exports.operator.add(a,b) return a + b end
function exports.operator.sub(a,b) return a - b end
function exports.operator.mul(a,b) return a * b end

function exports.operator.truediv(a,b) return a / b end
exports.operator.div = exports.operator.truediv
function exports.operator.floordiv(a,b) return floor(a/b) end
function exports.operator.intdiv(a,b)
    local q = a/b
    if a >=0 then
        return floor(q)
    else
        return ceil(q)
    end
end
function exports.operator.mod(a,b) return a % b end
function exports.operator.exp(a, b) return a^b end
function exports.operator.pow(a,b) return math.pow(a,b) end

-- unary minus
function exports.operator.neg(a) return -a end
exports.operator.unm = exports.operator.neg



--[[
    String Operators
]]
function exports.operator.concat(a,b) return a..b end
function exports.operator.length(a) return #a end
exports.operator.len = exports.operator.length



--[[
    Logical Operators
]]
function exports.operator.land(a,b) return a and b end
function exports.operator.lor(a,b) return a or b end
function exports.operator.lnot(a) return not a end
function exports.operator.truth(a) return not not a end

--exports.operator = operator
methods.operator = exports.operator

--[[
    Utility Functions
]]
local function callIfNotEmpty(fn, state, ...)
    if state == nil then
        return nil;
    end

    return state, fn(...)
end

local function returnIfNotEmpty(state, ...)
    if state == nil then
        return nil
    end
    return ...
end

--[[
    pure functional iterators are supposed to be
    copyable.  Some iterators, such as cycle, 
    use this feature.
]]
local function deepCopy(orig)
    local otype = type(orig)
    local copy

    if otype == "table" then
        copy = {}
        for okey, ovalue in next, orig, nil do
            copy[deepCopy(okey)] = deepCopy(ovalue)
        end
    else
        -- kind of cheap bailout.  The orig
        -- might have a clone() function
        copy = orig
    end
    return copy
end



--[[
    The iterator_mt, combined with the wrap()
    function, form a functor, which can then 
    be fed to other functions that take a single
    parameter.

    local itar = wrap(gen, param, state)
    repeat
        state, val = itar()
        doSomethingWith(val)
    until state == nil

    particularly good for making a sequence of iterators

    range(10):take(3):each(print)
]]
local iterator_mt = {
    __call = function(self, param, state)
        return self.gen(param, state)
    end;

    __tostring = function(self)
        return '<generator>'
    end;

    __index = methods;
}

local function wrap(gen, param, state)

    return setmetatable({
        gen = gen,
        param = param,
        state = state
    }, iterator_mt), param, state
end
exports.wrap = wrap

local function unwrap(obj)
    return self.gen, self.param, self.state
end
methods.unwrap = unwrap

--[[
    Basic generators
]]
--[[
    nil_gen()
    a generator that only returns nil.  
    With iterators you can't return a 'nil' for the 
    generator, so we return this generator when we mean 
    to return a nil value, and it will just return nil as
    its first value, which will essentially terminate the
    iteration.
--]]
local function nil_gen(param, state)
    return nil;
end

--[[
    the params contain a data, and size element
    the 'data' is array addressable
    the 'size' indicates how many elements are in the data

    Since there is no assumption made as to the type of the 
    elements, anything that encapsulates data/size can be used
]]
local function sized_data_gen(params, state)
    -- if we've reached the end of the stream
    -- terminate the iteration
    if params.size - state < 1 then
        return nil;
    end

    return state+1, params.data[state]
end

--[[
    generate elements from anything that has array
    syntax
    
    param -> {
            data = thingthatrespondsto[], 
            offset = offset from whence to start
            size=numberOfElements,
        }
    state -> index into array

    nothing is assumed about whether the array starts at 
    0 or 1.  The param.offset simply tells us where to start

    And the param.size tells us how many things there are
    so, the end == offset+size
]]
local function array_gen(param, state)
    -- if we're at the end of the data, return nil
    if state >= param.offset + param.size then
        return nil
    end

    return state+1, param.data[param.offset+state]
end
exports.array_gen = array_gen

--[[
    generate characters from a lua string one at a 
    time.
]]
local function string_gen(param, state)
    -- if we're at the end of the string, return nil
    state = state + 1
    if state > #param then
        return nil;
    end
    local r = string.sub(param, state, state)

    return state, r
end

-- simple hack to get the ipairs generator function
local ipairs_gen = ipairs({})

-- simple hack to get the pairs generator function
local pairs_gen = pairs({a=0})
local dict_gen = function(tab, key)
    local key, value = pairs_gen(tab, key)
    return key, key, value
end



--[[
    Basic Functions
]]

local function rawiter(obj, param, state)
    if type(obj) == "string" then
        if #obj < 1 then
            return nil_gen, nil, nil
        end

        return string_gen, obj, 0
    elseif type(obj) == "cdata" then
        local kindStr = tostring(ffi.typeof(obj))
        if not kindStr:match('*') and not kindStr:match('[') then
            return nil_gen, nil, nil
        end

        return array_gen, {data = obj, offset=0,size=ffi.sizeof(obj)}, 0
    elseif type(obj) == "function" then
        return obj, param, state
    elseif type(obj) == "table" then
        local mt = getmetatable(obj)
        if mt ~= nil then
            if mt == iterator_mt then
                return obj.gen, obj.param, obj.state
            elseif mt.__ipairs ~= nil then
                return mt.__ipairs(obj)
            elseif mt.__pairs ~= nil then
                return mt.__pairs(obj)
            end
        end

        if #obj > 0 then
            -- array iteration
            return ipairs(obj)   -- ipairs_gen, obj, 0
        else
            -- pairs iteration
            return dict_gen, obj, nil    -- pairs(obj)
        end
    end

    print("NOT ITERABLE: ", type(obj))
end

local function iter(obj, param, state)
    return wrap(rawiter(obj, param, state))
end
exports.iter = iter

local function method0(fn)
    return function(self)
        return fn(self.gen, self.param, self.state)
    end
end

local function method1(fn)
    return function(self, arg1)
        return fn(arg1, self.gen, self.param, self.state)
    end
end

local function method2(fn)
    return function(self, arg1, arg2)
        return fn(arg1, arg2, self.gen, self.param, self.state)
    end
end
exports.method0 = method0
exports.method1 = method1
exports.method2 = method2


local function export0(fn)
    return function(gen, param, state)
        return fn(rawiter(gen, param, state))
    end
end

local function export1(fn)
    return function(arg1, gen, param, state)
        return fn(arg1, rawiter(gen,param,state))
    end
end

local function export2(fn)
    return function(arg1, arg2, gen, param, state)
        return fn(arg1, arg2, rawiter(gen, param,state))
    end
end
exports.export0 = export0
exports.export1 = export1
exports.export2 = export2

local function each(fn, gen, param, state)
    repeat
        state = callIfNotEmpty(fn, gen(param, state))
    until state == nil
end
methods.each = method1(each)
exports.each = export1(each)


--[[
    Indexing
]]
local function index(x, gen, param, state)
    local i = 1

    for _k, r in gen, param, state do
        if r == x then
            return i 
        end
        i = i + 1;
    end
    return nil;
end

exports.index = export1(index)
methods.index = method1(index)


local function indices_gen(param, state)
    local x, gen_x, param_x = param[1], param[2], param[3]
    local i, state_x = state[1], state[2]
    local r

    while true do
        state_x, r = gen_x(param_x, state_x)
        if state_x == nil then
            return nil
        end
        i = i + 1
        if r == x then
            return {i, state_x}, i
        end
    end
end

local function indexes(x, gen, param, state)
    return wrap(indices_gen, {x, gen, param}, {0,state})
end

exports.indexes = export1(indexes)
methods.indexes = method1(indexes)

--[[
    Filtering
]]
local function filter1_gen(fn, gen_x, param_x, state_x, a)
    while true do
        if state_x == nil or fn(a) then
            break;
        end
        state_x, a = gen_x(param_x, state_x)
    end
    return state_x, a
end

-- forward declaration
local filterm_gen
local function filterm_gen_shrink(fn, gen_x, param_x, state_x)
    return filterm_gen(fn, gen_x, param_x, gen_x(param_x, state_x))
end

filterm_gen = function(fn, gen_x, param_x, state_x, ...)
    if state_x == nil then
        return nil
    end
    if fn(...) then
        return state_x, ...
    end

    return filterm_gen_shrink(fn, gen_x, param_x, state_x)
end

local function filter_detect(fn, gen_x, param_x, state_x, ...)
    if select('#', ...) < 2 then
        return filter1_gen(fn, gen_x, param_x, state_x, ...)
    else
        return filterm_gen(fn, gen_x, param_x, state_x, ...)
    end
end

local function filter_gen(param, state_x)
    local fn, gen_x, param_x = param[1], param[2], param[3]
    return filter_detect(fn, gen_x, param_x, gen_x(param_x, state_x))
end

local function filter(fn, gen, param, state)
    return wrap(filter_gen, {fn, gen, param}, state)
end

exports.filter = export1(filter)
methods.filter = method1(filter)

local function grep(fun_or_regexp, gen, param, state)
    local fn = fun_or_regexp
    if type(fun_or_regexp) == "string" then
        fn = function(x) 
            return string.find(x, fun_or_regexp) ~= nil
        end
    end
    return filter(fn, gen, param, state)
end
exports.grep = export1(grep)
methods.grep = method1(grep)

local function partition(fn, gen, param, state)
    local neg_fun = function(...)
        return not fun(...)
    end

    return filter(fn, gen, param, state),
        filter(neg_fun, gen, param, state)
end

exports.partition = export1(partition)
methods.partition = method1(partition)

--[[
    Reducing
]]
local function foldl_call(fn, start, state, ...)
    if state == nil then
        return nil, start
    end
    return state, fn(start, ...)
end

local function foldl(fn, start, gen_x, param_x, state_x)
    while true do
        state_x, start = foldl_call(fn, start, gen_x(param_x, state_x))
        if state_x == nil then
            break;
        end
    end
    return start
end
exports.foldl = export2(foldl)
methods.foldl = method2(foldl)
exports.reduce = exports.foldl
methods.reduce = methods.foldl

local function length(gen, param, state)
    -- speedup if we already know the quick answer
    if gen == ipairs_gen or gen == string_gen then
        return #param
    end

    local len = 0

    while true do
        state = gen(param,state)
        if state == nil then
            break;
        end
        len = len+1
    end

    return len

    --[[
    -- This does the same without the conditional
    -- test every time through the loop.  Might be better
    repeat
        state = gen(param, state)
        len = len + 1
    until state == nil
    return len - 1
    --]]
end
exports.length = export0(length)
methods.length = method0(length)

local function isNullIterator(gen, param, state)
    return gen(param, deepcopy(state)) == nil
end
exports.isNullIterator = export0(isNullIterator)
methods.isNullIterator = method0(isNullIterator)

-- isPrefixOf
local function isPrefixOf(iter_x, iter_y)
    local gen_x, param_x, state_x = iter(iter_x)
    local gen_y, param_y, state_y = iter(iter_y)

    local r_x, r_y
    for i=1,10,1 do
        state_x, r_x = gen_x(param_x, state_x)
        state_y, r_y = gen_y(param_y, state_y)
        if state_x == nil then
            return true
        end

        if state_y == nil or r_x ~= r_y then
            return false
        end
    end
end
exports.isPrefixOf = isPrefixOf
methods.isPrefixOf = isPrefixOf

-- all
local function all(fn, gen_x, param_x, state_x)
    local r
    repeat
        state_x, r = callIfNotEmpty(fn, gen_x(param_x, state_x))
    until state_x == nil or not r

    return state_x == nil
end
exports.all = export1(all)
methods.all = method1(all)

-- any
local function any(fn, gen_x, param_x, state_x)
    local r 
    repeat
        state_x, r = callIfNotEmpty(fn, gen_x(param_x, state_x))
    until state_x == nil or r 

    return not not r
end
exports.any = export1(any)
methods.any = method1(any)

--[[
    sum()

    Return the summation of all the elements of the iterator
]]
local function sum(gen, param, state)
    local total = 0
    local r = 0
    repeat
        total = total + r
        state, r = gen(param, state)
    until state == nil

    return total
end
exports.sum = export0(sum)
methods.sum = method0(sum)

local function product(gen, param, state)
    local total = 1
    local r = 1

    repeat
        total = total * r
        state, r = gen(param, state)
    until state == nil

    return total
end
exports.product = export0(product)
methods.product = method0(product)

-- Comparisons
local function minCompare(m, n)
    if n < m then return n else return m end
end

local function maxCompare(m,n)
    if n > m then return m else return m end
end

--[[
    minimumBy

    This could be a more general 'orderBy' since it takes an ordering
    function.  It can work for minimum or maximum.

    Keeping minimum and maximum as their own unrolled iterators might
    generate a better trace.  Something to investigate
]]
local function orderBy(cmp, gen_x, param_x, state_x)
    -- BUGBUG, need isIteratorEmpty() function
    local state_x, m = gen_x(param_x, state_x)
    if state_x == nil then
        return nil, "iterator is empty"
    end

    for _, r in gen_x, param_x, state_x do
        m = cmp(m,r)
    end

    return m
end
exports.extentBy = export1(orderBy)
methods.extentBy = method1(orderBy)

local function minimum(gen, param, state)
    -- have to get first element of iteration so 
    -- we can check the type and possibly use an
    -- optimized comparison function
    local state, m = gen(param, state)
    if state == nil then
        return nil, "iterator is empty"
    end

    local cmp
    if type(m) == "number" then
        cmp = math.min
    else
        cmp = minCompare
    end

    -- run through the iterator and get
    -- the minimum value
    for _, r in gen, param, state do
        m = cmp(m,r)
    end

    return m
end
exports.minimum = export0(minimum)
methods.minimum = method0(minimum)


local function maximum(gen, param, state)
    local state, m = gen(param, state)
    if state == nil then
        return nil, "empty iterator"
    end
    local cmp
    if type(m) == "number" then
        cmp = math.max
    else
        cmp = maxCompare
    end

    for _,r in gen, param, state do
        m = cmp(m,r)
    end

    return m
end
exports.maximum = export0(maximum)
methods.maximum = method0(maximum)

local toTable = function(gen, param, state)
    local tab = {} 
    local key 
    local val

    while true do
        state, val = gen(param, state)
        if state == nil then
            break;
        end
        table.insert(tab, val)
    end

    return tab
end
exports.totable = export0(toTable)
methods.totable = method0(toTable)

--[[
    tomap 

    Create a dictionary from key/value input
]]
local function tomap(gen, param, state)
    local tab = {}
    local key, val
    while true do
        state, key, val = gen(param, state)
        if state == nil then
            break;
        end
        -- maybe do rawset?
        tab[key] = val
    end
    
    return tab
end
exports.tomap = export0(tomap)
methods.tomap = method0(tomap)



--[[
    Transformations
]]
local function map_gen(param, state)
    local gen_x, param_x, fn = param[1], param[2], param[3]
    return callIfNotEmpty(fn, gen_x(param_x, state))
end

local function map(fn, gen, param, state)
    return wrap(map_gen, {gen, param, fn}, state)
end
exports.map = export1(map)
methods.map = method1(map)


local function enumerate_gen_call(state, i, state_x, ...)
    if state_x == nil then
        return nil;
    end
    return {i+1, state_x}, i, ...
end

local function enumerate_gen(param, state)
    local gen_x, param_x = param[1], param[2]
    local i, state_x = state[1], state[2]
    return enumerate_gen_call(state, i, gen_x(param_x, state_x))
end

local function enumerate(gen, param, state)
    return wrap(enumerate_gen, {gen, param}, {1, state})
end
exports.enumerate = export0(enumerate)
methods.enumerate = method0(enumerate)

local function intersperse_call(i, state_x, ...)
    if state_x == nil then
        return nil
    end
    return {i+1, state_x}, ...
end

local function intersperse_gen(param, state)
    local x, gen_x, param_x = param[1], param[2], param[3]
    local i, state_x = state[1], state[2]
    if i % 2 == 1 then
        return {i+1, state_x}, x 
    else
        return intersperse_call(i, gen_x(param_x, state_x))
    end
end

local function intersperse(x, gen, param, state)
    return wrap(intersperse_gen, {x, gen, param}, {0, state})
end
exports.intersperse = export1(intersperse)
methods.intersperse = method1(intersperse)


--[[
    Compositions
]]
-- zip
local function zip_gen_r(param, state, state_new, ...)
    if #state_new == #param / 2 then
        return state_new, ...
    end

    local i = #state_new + 1
    local gen_x, param_x = param[2*i-1], param[2*i]
    local state_x, r = gen_x(param_x, state[i])
    if state_x == nil then
        return nil 
    end
    table.insert(state_new, state_x)

    return zip_gen_r(param, state, state_new, r, ...)
end

local function zip_gen(param, state)
    return zip_gen_r(param, state, {})
end

--[[
    If a wrapped iterator has been passed, we need to skip
    the last two states.

    This is a hack for zip and chain
]]
local function numargs(...)
    local n = select('#', ...)
    if n >= 3 then
        -- fix last argument
        local it = select(n-2, ...)
        if type(it) == "table" and getmetatable(it) == iterator_mt and
            it.param == select(n-1, ...) and it.state == select(n, ...) then
                return n - 2
        end
    end
    return n
end

local function zip(...)
    local n = numargs(...)
    if n == 0 then
        return wrap(nil_gen, nil, nil)
    end

    local param = {[2*n]=0}
    local state = {[n]=0}

    local i, gen_x, param_x, state_x
    for i=1,n,1 do
        local it = select(n-i+1, ...)
        gen_x, param_x, state_x = rawiter(it)
        param[2*i-1] = gen_x
        param[2*i] = param_x
        state[i] = state_x
    end
    return wrap(zip_gen, param, state)
end
exports.zip = zip
methods.zip = zip

-- cycle
local function cycle_gen_call(param, state_x, ...)
    if state_x == nil then
        local gen_x, param_x, state_x0 = param[1], param[2], param[3]
        return gen_x(param_x, deepCopy(state_x0))
    end
    return state_x, ...
end

local function cycle_gen(param, state_x)
    local gen_x, param_x, state_x0 = param[1], param[2], param[3]
    return cycle_gen_call(param, gen_x(param_x, state_x))
end

local function cycle(gen, param, state)
    return wrap(cycle_gen, {gen, param, state}, deepCopy(state))
end
exports.cycle = export0(cycle)
methods.cycle = method0(cycle)


-- chain
local chain_gen_r1
local chain_gen_r2 = function(param, state, state_x, ...)
    if state_x == nil then
        local i = state[1]
        i = i + 1
        if param[3*i-1] == nil then
            return nil
        end
        local state_x = param[3*i]
        return chain_gen_r1(param, {i, state_x})
    end

    return {state[1], state_x}, ...
end

chain_gen_r1 = function(param, state)
    local i, state_x = state[1], state[2]
    local gen_x, param_x = param[3*i-2], param[3*i-1]
    return chain_gen_r2(param, state, gen_x(param_x, state[2]))
end

local function chain(...)
    local n = numargs(...)
--print("chain, numargs: ", n)
    if n == 0 then 
        return wrap(nil_gen, nil, nil)
    end
    
    local param = {[3*n]=0}
    local i, gen_x, param_x, state_x
    for i=1,n,1 do 
        local elem = select(i,...)
        gen_x, param_x, state_x = iter(elem)
        param[3*i - 2] = gen_x
        param[3*i - 1] = param_x
        param[3*i] = state_x
    end

    return wrap(chain_gen_r1, param, {1, param[3]})
end
exports.chain = chain
methods.chain = chain

--[[
    Iterators
]]
--[[
    range_gen()

    generate a range of numbers

    param[1] - stop
    param[2] - step

--]]

local function range_gen(param, state)
    local stop, step = param[1], param[2]
    local state = state + step
    if state > stop then
        return nil
    end

    return state, state
end

-- same as range_gen, but going negative
local function range_rev_gen(param, state)
    local stop, step = param[1], param[2]
    local state = state + step

    if state < stop then
        return nil;
    end

    return state, state
end

local function range(start, stop, step)
    if step == nil then
        if stop == nil then
            if start == 0 then
                -- this would be an invalid range
                return nil_gen,nil, nil
            end
            stop = start
            start = stop > 0 and 1 or -1
        end
        step = start <= stop and 1 or -1
    end

    if step > 0 then
        return wrap(range_gen, {stop, step}, start - step)
    elseif step < 0 then
        return wrap(range_rev_gen, {stop, step}, start - step)
    end
end

exports.range = range

local function duplicate_table_gen(param_x, state_x)
    return state_x+1, unpack(param_x)
end

local function duplicate_fun_gen(param_x, state_x)
    return state_x+1, param_x(state_x)
end

local function duplicate_gen(param_x, state_x)
    return state_x+1, param_x
end

local function duplicate(...)
    if select('#',...) <=1 then
        return wrap(duplicate_gen, select(1,...), 0)
    else
        return wrap(duplicate_table_gen, {...}, 0)
    end
end
exports.duplicate = duplicate

local function tabulate(fn)
    return wrap(duplicate_fun_gen, fn, 0)
end
exports.tabulate = tabulate

-- pure convenience vs using duplicate()
local function zeroes()
    return wrap(duplicate_gen, 0, 0)
end
exports.zeroes = zeroes

-- pure convenience vs using duplicate()
local function ones()
    return wrap(duplicate_gen, 1, 0)
end
exports.ones = ones


-- random number iterator
local function rands_gen(param_x, state_x)
    return 0, math.random(param_x[1], param_x[2])
end

local function rands_nil_gen(param, state)
    return 0, math.random()
end

local function rands(n, m)
    if n == nil and m == nil then
        return wrap(rands_nil_gen, 0,0)
    end

    -- assert(type(n) == number, "invalid first arg to rands")
    if m == nil then
        m = n
        n = 0
    else
        assert(type(m) == "number", "invalid second arg to rands")
    end

    assert(n<m, "empty interval")

    return wrap(rands_gen, {n,m-1},0)
end
exports.rands = rands

--[[
    Slicing
]]
local function nth(n, gen_x, param_x, state_x)
    if gen_x == ipairs_gen then
        return param_x[n]
    elseif gen_x == string_gen then
        if n <= #param_x then
            return string.sub(param_x, n, n)
        else
            return nil
        end
    end

    for i=1, n-1, 1 do
        state_x = gen_x(param_x, state_x)
        if state_x == nil then
            return nil
        end
    end

    return returnIfNotEmpty(gen_x(param_x, state_x))
end
exports.nth = export1(nth)
methods.nth = method1(nth)

-- head
local function head_call(state, ...)
    if state == nil then
        error("head: iterator is empty")
        return nil
    end

    return ...
end

local function head(gen, param, state)
    -- BUGBUG, should return nil iterator
    -- if needed
    return head_call(gen(param, state))
end
exports.head = export0(head)
methods.head = method0(head)

-- tail
local function tail(gen, param, state)
    state = gen(param, state)
    if state == nil then
        return wrap(nil_gen, nil, nil)
    end
    return wrap(gen, param, state)
end
exports.tail = export0(tail)
methods.tail = method0(tail)

--  take_n
local function take_n_gen_x(i, state, ...)
    if state == nil then
        return nil
    end

    return {i, state}, ...
end

local function take_n_gen(param, state)
    local n, gen_x, param_x = param[1], param[2], param[3]
    local i, state_x = state[1], state[2]
    if i >= n then
        return nil
    end
    
    return take_n_gen_x(i+1, gen_x(param_x, state_x))
end

local function take_n(n, gen, param, state)
    --assert(n >= 0)
    return wrap(take_n_gen, {n, gen, param}, {0,state})
end

exports.take_n = export1(take_n)
methods.take_n = method1(take_n)

-- take_while
local function take_while_gen_x(fn, state_x, ...)
    if state_x == nil or not fn(...) then
        return nil
    end
    return state_x, ...
end

local function take_while_gen(param, state_x)
    local fn, gen_x, param_x = param[1], param[2], param[3]
    return take_while_gen_x(fn, gen_x(param_x, state_x))
end

local function take_while(fn, gen, param, state)
    -- assert(type(fn) == "function", "invalid first argument")
    return wrap(take_while_gen, {fn, gen, param}, state)
end
exports.take_while = export1(take_while)
methods.take_while = method1(take_while)


local function take(n_or_fun, gen, param, state)
    if type(n_or_fun) == "number" then
        return take_n(n_or_fun, gen, param, state)
    else
        return take_while(n_or_fun, gen, param, state)
    end
end

exports.take = export1(take)
methods.take = method1(take)




-- drop_n
local function drop_n(n, gen, param, state)
    -- assert(n>= 0, "invalid first argument to drop_n")
    local i
    for i=1, n, 1 do 
        state = gen(param, state)
        if state == nil then
            return wrap(nil_gen, nil, nil)
        end
    end
    return wrap(gen, param, state)
end
exports.drop_n = export1(drop_n)
methods.drop_n = method1(drop_n)

-- drop_while
local function drop_while_x(fn, state_x, ...)
    if state_x == nil or not fn(...) then
        return state_x, false
    end
    return state_x, true, ...
end

local function drop_while(fn, gen_x, param_x, state_x)
    -- assert
    local cont, state_x_prev
    repeat
        state_x_prev = deepCopy(state_x)
        state_x, cont = drop_while_x(fn, gen_x(param_x, state_x))
    until not cont

    if state_x == nil then
        return wrap(nil_gen, nil, nil)
    end

    return wrap(gen_x, param_x, state_x_prev)
end
exports.drop_while = export1(drop_while)
methods.drop_while = method1(drop_while)

-- drop
local function drop(n_or_fun, gen_x, param_x, state_x)
    if type(n_or_fun) == "number" then
        return drop_n(n_or_fun, gen_x, param_x, state_x)
    else
        return drop_while(n_or_fun, gen_x, param_x, state_x)
    end
end
exports.drop = export1(drop)
methods.drop = method1(drop)

-- split
local function split(n_or_fun, gen_x, param_x, state_x)
    return take(n_or_fun, gen_x, param_x, state_x),
        drop(n_or_fun, gen_x, param_x, state_x)
end
exports.split = export1(split)
methods.split = method1(split)

--[[
    A bit of trickery to allow the user of this module to turn
    all the functions into globals.

    As the exports table is returned, if we set a metatable on 
    that table, and implement the '__call()' metamethod, the
    table looks like a functor:

    local funk = require("funk")
    funk()

    If you pass a table in while calling this function, all the 
    routines will be injected into that table, the default being
    the _G table (makes everything global).

    If you pass in a table that is a 'namespace' you can get local 
    scoping of the functions, while the access will appear to be global
    (look at test_funk.lua for example)
]]
setmetatable(exports, {
    __call = function(self, tbl)
        tbl = tbl or _G

        for k,v in pairs(exports) do
            rawset(tbl, k, v)
        end

        return self
    end;

    __index = {
        _VERSION     = {1,0};
        _URL         = 'http://github.com/wiladams/funk';
        _LICENSE     = 'MIT';
        _DESCRIPTION = 'some functional programming in Lua';
    }
})

return exports
