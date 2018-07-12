
-- print each line as:
-- offset, Hex-16 digits, ASCII
local function isprintable(c)
        return c >= 0x20 and c < 0x7f
end

local function printHex(ms, buffer, offsetbits, iterations)
    offsetbits = offsetbits or 32
    --iterations = iterations or 1

    if offsetbits == 32 then
        print("Offset (h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  Decoded text")
        print("------------------------------------------------------------------------------")

    elseif offsetbits > 32 then
        print("        Offset (h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  Decoded text")
        print("--------------------------------------------------------------------------------------")
    end

    local iteration = 0
    while true do
        if iterations and iteration >= iterations then
            break;
        end

        local sentinel = ms:tell();
        local bytes = ms:readBytes(16, buffer);

        if offsetbits > 32 then
            io.write(string.format("0x%016X: ", sentinel))
        else
            io.write(string.format("0x%08X: ", sentinel))
        end

        -- write 16 hex values
        for i=0,15 do
            io.write(string.format("%02X ", bytes[i]))
            if i == 7 then io.write(' '); end 
        end
        
        io.write(' ')
        for i=0,15 do
            if isprintable(bytes[i]) then
                io.write(string.format("%c", bytes[i]))
            else
                io.write('.')
            end
        end

        io.write("\n")

        iteration = iteration + 1;
    end
end

return {
    printHex = printHex;
}