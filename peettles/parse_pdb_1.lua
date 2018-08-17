-- Read PDB stream 1 (PDB Info)
local win32 = require("peettles.w32")

local function readStream(bs, res)
    res = res or {}

    res.Version = bs:readUInt32();
    res.TimeDateStamp = bs:readUInt32();
    res.Age = bs:readUInt32();
    res.GUID = bs:readBytes(16);
    res.NamesLength = bs:readUInt32();

    if res.NamesLength > 0 then
        res.Names = {};
        local ns = bs:range(res.NamesLength);
        while true do
            local name, err = ns:readString();
            if name then
                table.insert(res.Names, name);
            end

            if ns:EOF() then
                break;
            end
        end
    end

    return res;
end

return {
    read = readStream;
}

