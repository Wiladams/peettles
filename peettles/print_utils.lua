
local ffi = require("ffi")

-- print each line as:
-- offset, Hex-16 digits, ASCII
local function isprintable(c)
    return c >= 0x20 and c < 0x7f
end

-- ' ' 0x20, '\t' 0x09, '\n' 0x0a, '\v' 0x0b, '\f' 0x0c, '\r' 0x0d
local function isspace(c)
	return c == 0x20 or (c >= 0x09 and c<=0x0d)
end


--[[
    Pass in a config that looks like this:

    local config = {
        ms = stream;
        buffer = buff;
        offsetbits = 32;
        iterations = 256;
        verbose = true;
    }
]]
local function printHex(config)
    local ms = config.stream;
    local buffer = config.buffer or ffi.new("uint8_t[?]", 16)
    local offsetbits = config.offsetbits or 32;
    local iterations = config.iterations;
    local verbose = config.verbose;

if verbose then
    if offsetbits == 32 then
        print("Offset (h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  Decoded text")
        print("------------------------------------------------------------------------------")

    elseif offsetbits > 32 then
        print("        Offset (h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  Decoded text")
        print("--------------------------------------------------------------------------------------")
    end
end

    local iteration = 0
    while true do
        if iterations and iteration >= iterations then
            break;
        end

        local sentinel = ms:tell();
        local success, actualRead = ms:readBytes(16, buffer);

        if not success then
            if actualRead < 1 then break end
        end

        if offsetbits > 32 then
            io.write(string.format("0x%016X: ", sentinel))
        else
            io.write(string.format("0x%08X: ", sentinel))
        end

        -- write actualRead hex values
        for i=0,actualRead-1 do
            --print(buffer, err)
            io.write(string.format("%02X ", buffer[i]))
            if i == 7 then io.write(' '); end 
        end
        
        io.write(' ')
        for i=0,actualRead-1 do
            if isprintable(buffer[i]) then
                io.write(string.format("%c", buffer[i]))
            else
                io.write('.')
            end
        end

        io.write("\n")

        iteration = iteration + 1;
    end
end

return {
    isprintable = isprintable;
    isspace = isspace;
    printHex = printHex;
}