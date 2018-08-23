package.path = "../?.lua;"..package.path


local TextStream = require("TextStream")

local ts = TextStream("The quick brown fox jumped over the lazy dogs back.")

while true do
    local c = ts:get();
    if not c then
        break;
    end

    io.write(c);
end