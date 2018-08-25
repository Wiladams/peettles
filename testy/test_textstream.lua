package.path = "../?.lua;"..package.path


local TextStream = require("TextStream")

local function test_get()
    print("==== test_get ====")
    local ts = TextStream("The quick brown fox jumped over the lazy dogs back.")

    while true do
        local c = ts:get();
        if not c then
            break;
        end

        io.write(c);
    end
end

function consume(ts, str)
    if (not ts:startsWith(str)) then
      return false;
    end

    ts:trim(#str);

    return true;
end


local function test_startswith()
    local ts = TextStream('?x@@3HA')

    print("StartsWithChar - '?' : ", ts:startsWithChar('?'))
    print("StartsWithChar - '*' : ", ts:startsWithChar('*'))
end

local function test_consume()
    print("==== test_consume ====")
    local str = '?x@@3HA';
    local ts = TextStream(str)

    print(str)
    print(consume(ts, "?"))
    print(consume(ts, "x@@"))
    print(consume(ts, "4"))
    print(ts:str())
end

--test_get();
--test_startswith();
test_consume();
