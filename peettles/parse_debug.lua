local ffi = require("ffi")

local peenums = require("peettles.peenums")
local DebugType = peenums.DebugType;

--[[
static const int  FRAME_FPO  = 0;               
static const int  FRAME_TRAP = 1;
static const int  FRAME_TSS  = 2;

typedef struct _FPO_DATA {
    DWORD       ulOffStart;            // offset 1st byte of function code
    DWORD       cbProcSize;            // # bytes in function
    DWORD       cdwLocals;             // # bytes in locals/4
    WORD        cdwParams;             // # bytes in params/4
    WORD        cbProlog : 8;          // # bytes in prolog
    WORD        cbRegs   : 3;          // # regs saved
    WORD        fHasSEH  : 1;          // TRUE if SEH in func
    WORD        fUseBP   : 1;          // TRUE if EBP has been allocated
    WORD        reserved : 1;          // reserved for future use
    WORD        cbFrame  : 2;          // frame type
} FPO_DATA;
]]

local function readFPO(bs, res)
    res = res or {}

    -- read an array of FPO_DATA records
    -- until EOF
    while not bs:EOF() do 
        local fpo = {
            ulOffStart = bs:readDWORD();
            cbProcSize = bs:readDWORD();
            cdwLocals = bs:readDWORD();
            cdwParams = bs:readWORD();
            Flags = bs:readUInt16();
        }
        fpo.cbProlog = band(fpo.Flags, 0xff);
        fpo.cbRegs = band(rshift(fpo.Flags,8), 0x7);
        fpo.fHasSEH = band(rshift(fpo.Flags,11),0x1);
        fpo.fUseBP = band(rshift(fpo.Flags,12), 0x1);
        fpo.cbFrame = band(rshift(fpo.Flags,14),0x3);
        
        table.insert(res, fpo)
    end

    return res;
end


local typeParsers = {
    [DebugType.IMAGE_DEBUG_TYPE_FPO] = readFPO;
}


local function readStream(bs, res)
    res = res or {}
    
    res.Characteristics = bs:readUInt32();
    res.TimeDateStamp = bs:readUInt32();
    res.MajorVersion = bs:readUInt16();
    res.MinorVersion = bs:readUInt16();
    res.Type = bs:readUInt32();
    res.SizeOfData = bs:readUInt32();
    res.AddressOfRawData = bs:readUInt32();
    res.PointerToRawData = bs:readUInt32();
    
    -- get the parser
    bs:seek(res.PointerToRawData);
    local ds = bs:range(res.SizeOfData)
    local typeParser =typeParsers[res.Type] 
    
    if not typeParser then
        return res;
    end

    local typeinfo = typeParser(ds)
    res.TypeInfo = typeinfo;

    return res;
end

return {
    read = readStream;
}
