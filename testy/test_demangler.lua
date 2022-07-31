-- Run test cases for demangler
package.path = "../?.lua;"..package.path

local Demangler = require("peettles.demangler")

local longcases = {
 {['?x@@3HA'] = 'int x'};
 {['?x@@3PEAHEA'] = 'int*x'};
 {['?x@@3PEAPEAHEA'] = 'int**x'};
 {['?x@@3PEAY02HEA'] = 'int(*x)[3]'};
 {['?x@@3PEAY124HEA'] = 'int(*x)[3][5]'};
 {['?x@@3PEAY02$$CBHEA'] = 'int const(*x)[3]'};
 {['?x@@3PEAEEA'] = 'unsigned char*x'};
 {['?x@@3PEAY1NKM@5HEA'] = 'int(*x)[3500][6]'};
 {['?x@@YAXMH@Z'] = 'void x(float,int)'};
 {['?x@@YAXMH@Z'] = 'void x(float,int)'};
 {['?x@@3P6AHMNH@ZEA'] = 'int(*x)(float,double,int)'};
 {['?x@@3P6AHP6AHM@ZN@ZEA'] = 'int(*x)(int(*)(float),double)'};
 {['?x@@3P6AHP6AHM@Z0@ZEA'] = 'int(*x)(int(*)(float),int(*)(float))'};

 {['?x@ns@@3HA'] = 'int ns::x'};

-- Microsoft's undname returns "int const * const x" for this symbol.
-- I believe it's their bug.
 {['?x@@3PEBHEB'] = 'int const*x'};

 {['?x@@3QEAHEB'] = 'int*const x'};
 {['?x@@3QEBHEB'] = 'int const*const x'};

 {['?x@@3AEBHEB'] = 'int const&x'};

 {['?x@@3PEAUty@@EA'] = 'struct ty*x'};
 {['?x@@3PEATty@@EA'] = 'union ty*x'};
 {['?x@@3PEAUty@@EA'] = 'struct ty*x'};
 {['?x@@3PEAW4ty@@EA'] = 'enum ty*x'};
 {['?x@@3PEAVty@@EA'] = 'class ty*x'};

 {['?x@@3PEAV?$tmpl@H@@EA'] = 'class tmpl<int>*x'};
 {['?x@@3PEAU?$tmpl@H@@EA'] = 'struct tmpl<int>*x'};
 {['?x@@3PEAT?$tmpl@H@@EA'] = 'union tmpl<int>*x'};
 {['?instance@@3Vklass@@A'] = 'class klass instance'};
 {['?instance$initializer$@@3P6AXXZEA'] = 'void(*instance$initializer$)(void)'};
 {['??0klass@@QEAA@XZ'] = 'klass::klass(void)'};
 {['??1klass@@QEAA@XZ'] = 'klass::~klass(void)'};
 {['?x@@YAHPEAVklass@@AEAV1@@Z'] = 'int x(class klass*,class klass&)'};
 {['?x@ns@@3PEAV?$klass@HH@1@EA'] = 'class ns::klass<int,int>*ns::x'};
 {['?fn@?$klass@H@ns@@QEBAIXZ'] = 'unsigned int ns::klass<int>::fn(void)const'};

 {['??4klass@@QEAAAEBV0@AEBV0@@Z'] = 'class klass const&klass::operator=(class klass const&)'};
 {['??7klass@@QEAA_NXZ'] = 'bool klass::operator!(void)'};
 {['??8klass@@QEAA_NAEBV0@@Z'] = 'bool klass::operator==(class klass const&)'};
 {['??9klass@@QEAA_NAEBV0@@Z'] = 'bool klass::operator!=(class klass const&)'};
 {['??Aklass@@QEAAH_K@Z'] = 'int klass::operator[](uint64_t)'};
 {['??Cklass@@QEAAHXZ'] = 'int klass::operator->(void)'};
 {['??Dklass@@QEAAHXZ'] = 'int klass::operator*(void)'};
 {['??Eklass@@QEAAHXZ'] = 'int klass::operator++(void)'};
 {['??Eklass@@QEAAHH@Z'] = 'int klass::operator++(int)'};
 {['??Fklass@@QEAAHXZ'] = 'int klass::operator--(void)'};
 {['??Fklass@@QEAAHH@Z'] = 'int klass::operator--(int)'};
 {['??Hklass@@QEAAHH@Z'] = 'int klass::operator+(int)'};
 {['??Gklass@@QEAAHH@Z'] = 'int klass::operator-(int)'};
 {['??Iklass@@QEAAHH@Z'] = 'int klass::operator&(int)'};
 {['??Jklass@@QEAAHH@Z'] = 'int klass::operator->*(int)'};
 {['??Kklass@@QEAAHH@Z'] = 'int klass::operator/(int)'};
 {['??Mklass@@QEAAHH@Z'] = 'int klass::operator<(int)'};
 {['??Nklass@@QEAAHH@Z'] = 'int klass::operator<=(int)'};
 {['??Oklass@@QEAAHH@Z'] = 'int klass::operator>(int)'};
 {['??Pklass@@QEAAHH@Z'] = 'int klass::operator>=(int)'};
 {['??Qklass@@QEAAHH@Z'] = 'int klass::operator,(int)'};
 {['??Rklass@@QEAAHH@Z'] = 'int klass::operator()(int)'};
 {['??Sklass@@QEAAHXZ'] = 'int klass::operator~(void)'};
 {['??Tklass@@QEAAHH@Z'] = 'int klass::operator^(int)'};
 {['??Uklass@@QEAAHH@Z'] = 'int klass::operator|(int)'};
 {['??Vklass@@QEAAHH@Z'] = 'int klass::operator&&(int)'};
 {['??Wklass@@QEAAHH@Z'] = 'int klass::operator||(int)'};
 {['??Xklass@@QEAAHH@Z'] = 'int klass::operator*=(int)'};
 {['??Yklass@@QEAAHH@Z'] = 'int klass::operator+=(int)'};
 {['??Zklass@@QEAAHH@Z'] = 'int klass::operator-=(int)'};
 {['??_0klass@@QEAAHH@Z'] = 'int klass::operator/=(int)'};
 {['??_1klass@@QEAAHH@Z'] = 'int klass::operator%=(int)'};
 {['??_2klass@@QEAAHH@Z'] = 'int klass::operator>>=(int)'};
 {['??_3klass@@QEAAHH@Z'] = 'int klass::operator<<=(int)'};
 {['??_6klass@@QEAAHH@Z'] = 'int klass::operator^=(int)'};
 {['??6@YAAEBVklass@@AEBV0@H@Z'] = 'class klass const&operator<<(class klass const&,int)'};
 {['??5@YAAEBVklass@@AEBV0@_K@Z'] = 'class klass const&operator>>(class klass const&,uint64_t)'};
 {['??2@YAPEAX_KAEAVklass@@@Z'] = 'void*operator new(uint64_t,class klass&)'};
 {['??_U@YAPEAX_KAEAVklass@@@Z'] = 'void*operator new[](uint64_t,class klass&)'};
 {['??3@YAXPEAXAEAVklass@@@Z'] = 'void operator delete(void*,class klass&)'};
 {['??_V@YAXPEAXAEAVklass@@@Z'] = 'void operator delete[](void*,class klass&)'};
}

local shortcases = {
    {['?fn@?$klass@H@ns@@QEBAIXZ'] = 'unsigned int ns::klass<int>::fn(void)const'};
}

-- system32\msvcp_win.dll
local classcases = {
    "??0?$basic_iostream@_WU?$char_traits@_W@std@@@std@@QEAA@PEAV?$basic_streambuf@_WU?$char_traits@_W@std@@@1@@Z";
    "??0?$basic_ostream@DU?$char_traits@D@std@@@std@@IEAA@$$QEAV01@@Z";
    "??0?$ctype@_W@std@@QEAA@_K@Z";
    "??0?$time_put@DV?$ostreambuf_iterator@DU?$char_traits@D@std@@@std@@@std@@QEAA@AEBV_Locinfo@1@_K@Z";
    "??1time_base@std@@UEAA@XZ";
    "??4?$_Iosb@H@std@@QEAAAEAV01@$$QEAV01@@Z";
    "?_Ftime_base@std@@QEAAXXZ";
    "?CaptureCallstack@platform@details@Concurrency@@YA_KPEAPEAX_K1@Z";
    "?GetCurrentThreadId@platform@details@Concurrency@@YAJXZ";
    "?GetNextAsyncId@platform@details@Concurrency@@YAIXZ";
    "?ReportUnhandledError@_ExceptionHolder@details@Concurrency@@AEAAXXZ";
    "?_Addcats@_Locinfo@std@@QEAAAEAV12@HPEBD@Z";
    "?_Addfac@_Locimp@locale@std@@AEAAXPEAVfacet@23@_K@Z";
    "?_Addstd@ios_base@std@@SAXPEAV12@@Z";
    "?_Assign@_ContextCallback@details@Concurrency@@AEAAXPEAX@Z";
    "?_Atexit@@YAXP6AXXZ@Z";
    "?_BADOFF@std@@3_JB";
--[[
        409  198 00018350 ?_C_str@?$_Yarn@D@std@@QEBAPEBDXZ
        410  199 00018350 ?_C_str@?$_Yarn@G@std@@QEBAPEBGXZ
        411  19A 00018350 ?_C_str@?$_Yarn@_W@std@@QEBAPEB_WXZ
        412  19B 0003E590 ?_CallInContext@_ContextCallback@details@Concurrency@@QEBAXV?$function@$$A6AXXZ@std@@_N@Z
        413  19C 00019430 ?_Callfns@ios_base@std@@AEAAXW4event@12@@Z
        414  19D 0003E6B0 ?_Capture@_ContextCallback@details@Concurrency@@AEAAXXZ
        415  19E 00095158 ?_Clocptr@_Locimp@locale@std@@0PEAV123@EA
        416  19F 00009EB0 ?_Decref@facet@locale@std@@UEAAPEAV_Facet_base@3@XZ
        417  1A0 00020530 ?_Donarrow@?$ctype@G@std@@IEBADGD@Z
        418  1A1 00020530 ?_Donarrow@?$ctype@_W@std@@IEBAD_WD@Z
        419  1A2 0000A300 ?_Dowiden@?$ctype@G@std@@IEBAGD@Z
        420  1A3 000186D0 ?_Dowiden@?$ctype@_W@std@@IEBA_WD@Z
        421  1A4 00018340 ?_Empty@?$_Yarn@D@std@@QEBA_NXZ
        422  1A5 00018340 ?_Empty@?$_Yarn@G@std@@QEBA_NXZ
        423  1A6 00018340 ?_Empty@?$_Yarn@_W@std@@QEBA_NXZ
        424  1A7 0000FE00 ?_Execute_once@std@@YAHAEAUonce_flag@1@P6AHPEAX1PEAPEAX@Z1@Z
        425  1A8 00001E70 ?_Ffmt@?$num_put@DV?$ostreambuf_iterator@DU?$char_traits@D@std@@@std@@@std@@AEBAPEADPEADDH@Z
        426  1A9 00029B50 ?_Ffmt@?$num_put@GV?$ostreambuf_iterator@GU?$char_traits@G@std@@@std@@@std@@AEBAPEADPEADDH@Z
        427  1AA 00029B50 ?_Ffmt@?$num_put@_WV?$ostreambuf_iterator@_WU?$char_traits@_W@std@@@std@@@std@@AEBAPEADPEADDH@Z
        428  1AB 00020590 ?_Findarr@ios_base@std@@AEAAAEAU_Iosarray@12@H@Z
        429  1AC 0000FFA0 ?_Fiopen@std@@YAPEAU_iobuf@@PEBDHH@Z
        430  1AD 0000FE60 ?_Fiopen@std@@YAPEAU_iobuf@@PEBGHH@Z
        431  1AE 0000FE60 ?_Fiopen@std@@YAPEAU_iobuf@@PEB_WHH@Z
        432  1AF 00001EE0 ?_Fput@?$num_put@DV?$ostreambuf_iterator@DU?$char_traits@D@std@@@std@@@std@@AEBA?AV?$ostreambuf_iterator@DU?$char_traits@D@std@@@2@V32@AEAVios_base@2@DPEBD_K@Z
        433  1B0 00029BF0 ?_Fput@?$num_put@GV?$ostreambuf_iterator@GU?$char_traits@G@std@@@std@@@std@@AEBA?AV?$ostreambuf_iterator@GU?$char_traits@G@std@@@2@V32@AEAVios_base@2@GPEBD_K@Z
        434  1B1 00029FD0 ?_Fput@?$num_put@_WV?$ostreambuf_iterator@_WU?$char_traits@_W@std@@@std@@@std@@AEBA?AV?$ostreambuf_iterator@_WU?$char_traits@_W@std@@@2@V32@AEAVios_base@2@_WPEBD_K@Z
        435  1B2 000030D0 ?_Getcat@?$codecvt@DDU_Mbstatet@@@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
        436  1B3 00020610 ?_Getcat@?$codecvt@GDU_Mbstatet@@@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
        437  1B4 00020700 ?_Getcat@?$codecvt@_SDU_Mbstatet@@@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
        438  1B5 000207C0 ?_Getcat@?$codecvt@_UDU_Mbstatet@@@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
        439  1B6 00020880 ?_Getcat@?$codecvt@_WDU_Mbstatet@@@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
        440  1B7 000025A0 ?_Getcat@?$ctype@D@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
        441  1B8 000034D0 ?_Getcat@?$ctype@G@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
        442  1B9 00020970 ?_Getcat@?$ctype@_W@std@@SA_KPEAPEBVfacet@locale@2@PEBV42@@Z
--]]
}


local function main(cases)
    for idx, testcase in ipairs(cases) do
        if type(testcase) == "table" then
            for k,v in pairs(testcase) do
                local res, err = Demangler.demangle(k)

                if not res then
                    print("FAIL, ERROR: ", err)
                elseif res == v then
                    print("PASS")
                else
                    print("FAIL", k, v, res)
                end
            end
        elseif type(testcase) == "string" then
            local res, err = Demangler.demangle(testcase)
            if not res then
                print("FAIL, ERROR: ", err)
            else
                print(res, testcase)
            end
        end
    end
end

local function simple(str)
    local res, err = Demangler.demangle(str)
    if not res then
        print("FAIL, ERROR: ", err)
        return false;
    end

    print(str, res)

end

--main(longcases)
--main(shortcases)
--main(classcases)
simple("_initterm")
