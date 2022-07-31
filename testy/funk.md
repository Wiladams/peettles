
wrap(gen, param, state)

--[[
    Generators
]]
array_gen(param, state)
string_gen(param, state)
ipairs_gen
pairs_gen
dict_gen(tab, key)

--[[
    Basic functions
]]
each(fn, gen, param, state)

--[[
    Indexing
]]
index(x, gen, param, state)
indexes(x, gen, param, state)

--[[
    Filtering
]]
filter(fn, gen, param, state)
grep(fn_or_regexp, gen, param, state)
partition(fn, gen, param, state)

--[[
    Reducing
]]
foldl(fn, start, gen_x, param_x, state_x)
reduce(fn, start, gen_x, param_x, state_x)
length(gen, param, state)
isNullIterator(gen, param, state)
isPrefixOf(iter_x, iter_y)
all(fn, gen_x, param_x, state_x)
any(fn, gen_x, param_x, state_x)
sum(gen, param, state)
product(gen, param, state)
minCompare(m, n)
maxCompare(m, n)
orderBy(cmp, gen_x, param_x, state_x)
minimum(gen, param, state)
maximum(gen, param, state)

totable(gen, param, state)
tomap(gen, param, state)
map(fn, gen, param, state)
enumerate(gen, param, state)
intersperse(x, gen, param, state)

--[[
    Compositions
]]
zip(...)
cycle(gen, param, state)
chain(...)



range(start, stop, step)
duplicate(...)
tabulate(fn)
zeroes()
ones()
rands(n,m)
nth(n)
head()
tail()
take_n(n, gen, param, state)
take_while(fn, gen, param, state)
take(n_or_fn, gen, param, state)
drop_n(n, gen, param, state)
drop_while(fn, genx, param_x, state_x)
drop(n_or_fun)
split()