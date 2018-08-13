local math = require("math")
local ffi = require("ffi")

ffi.cdef[[
typedef int16_t     PN16;
typedef int16_t     SPN16;
typedef int32_t     PN32;
typedef int32_t     SPN32;
]]

ffi.cdef[[
typedef void *      PB;
typedef void *      PV;
typedef uint16_t    SN;     // stream number


typedef PN32    UPN;    // universal page no.
typedef SPN32   USPN;   // universal stream page no.

typedef uint32_t    UNSN;   // unified stream number
typedef long     CB;     // size (count of bytes)
typedef long     OFF;    // offset
]]
local CHAR_BIT = ffi.sizeof("char")

local const = {
    cbPgMax   = 0x1000;   -- Biggest page size possible
    cbPgMin   = 0x0200;

    cbDbMax   = 128 * 0x10000;    -- 128meg
    cpnDbMax    = 0x10000;

    cpnDbMaxBigMsf = 0x100000;      -- 2^20 pages
    
    pnMaxMax    = 0xffff;       -- max no of pgs in any msf
    pnHdr       = 0;

    snSt        = 0;            -- stream info stream
    snUserMin   = 1;            -- first valid user sn
    snMax       = 0x1000;       -- max no of streams in msf
    
    unsnMax     = 0x10000;             -- 64K streams

}

const.cbitsFpmMax = const.cpnDbMax;
const.cbFpmMax    = const.cbitsFpmMax/CHAR_BIT
const.cbitsFpmMaxBigMsf = const.cpnDbMaxBigMsf;
const.cbFpmMaxBigMsf = const.cbitsFpmMaxBigMsf/CHAR_BIT;

const.spnMaxMax   = const.pnMaxMax;             -- max no of pgs in a stream
const.upnMaxMax   = const.cpnDbMaxBigMsf;       -- 2^20 pages
const.uspnMaxMax  = const.upnMaxMax;


local function validPageSize(pgSize)
    return pgSize == 512 or pgSize == 1024 or 
        pgSize == 2048 or pgSize == 4096;
end

local function cpnMaxForCb(cb) 
    return math.floor((cb + const.cbPgMin - 1) / const.cbPgMin)
end

ffi.cdef[[
struct SI_PERSIST {
    CB      cb;
    int32_t mpspnpn;
};
]]

local PN32 = ffi.typeof("PN32")
local UNSN = ffi.typeof("UNSN")
local UPN = ffi.typeof("UPN")
local SI_PERSIST = ffi.typeof("struct SI_PERSIST")

--local    cbMaxSerialization = const.snMax*sizeof(SI_PERSIST) + sizeof(SN) + sizeof(ushort) + pnMaxMax*sizeof(PN),
local    cbBigMSFMaxSer = const.unsnMax*ffi.sizeof(SI_PERSIST) + ffi.sizeof(UNSN) + const.upnMaxMax*ffi.sizeof(UPN)


--print("cpnMaxForCb: ", cpnMaxForCb(cpnMaxForCb(cbBigMSFMaxSer) * ffi.sizeof(PN32)))

return {
    validPageSize = validPageSize;

    const = const;
}