-- Run test cases for demangler
package.path = "../?.lua;"..package.path

local Demangler = require("demangler")

local longcases = {
 ['?x@@3HA'] = 'int x';
 ['?x@@3PEAHEA'] = 'int*x';
 ['?x@@3PEAPEAHEA'] = 'int**x';
 ['?x@@3PEAY02HEA'] = 'int(*x)[3]';
 ['?x@@3PEAY124HEA'] = 'int(*x)[3][5]';
 ['?x@@3PEAY02$$CBHEA'] = 'int const(*x)[3]';
 ['?x@@3PEAEEA'] = 'unsigned char*x';
 ['?x@@3PEAY1NKM@5HEA'] = 'int(*x)[3500][6]';
 ['?x@@YAXMH@Z'] = 'void x(float,int)';
 ['?x@@YAXMH@Z'] = 'void x(float,int)';
 ['?x@@3P6AHMNH@ZEA'] = 'int(*x)(float,double,int)';
 ['?x@@3P6AHP6AHM@ZN@ZEA'] = 'int(*x)(int(*)(float),double)';
 ['?x@@3P6AHP6AHM@Z0@ZEA'] = 'int(*x)(int(*)(float),int(*)(float))';

 ['?x@ns@@3HA'] = 'int ns::x';

-- Microsoft's undname returns "int const * const x" for this symbol.
-- I believe it's their bug.
 ['?x@@3PEBHEB'] = 'int const*x';

 ['?x@@3QEAHEB'] = 'int*const x';
 ['?x@@3QEBHEB'] = 'int const*const x';

 ['?x@@3AEBHEB'] = 'int const&x';

 ['?x@@3PEAUty@@EA'] = 'struct ty*x';
 ['?x@@3PEATty@@EA'] = 'union ty*x';
 ['?x@@3PEAUty@@EA'] = 'struct ty*x';
 ['?x@@3PEAW4ty@@EA'] = 'enum ty*x';
 ['?x@@3PEAVty@@EA'] = 'class ty*x';

 ['?x@@3PEAV?$tmpl@H@@EA'] = 'class tmpl<int>*x';
 ['?x@@3PEAU?$tmpl@H@@EA'] = 'struct tmpl<int>*x';
 ['?x@@3PEAT?$tmpl@H@@EA'] = 'union tmpl<int>*x';
 ['?instance@@3Vklass@@A'] = 'class klass instance';
 ['?instance$initializer$@@3P6AXXZEA'] = 'void(*instance$initializer$)(void)';
 ['??0klass@@QEAA@XZ'] = 'klass::klass(void)';
 ['??1klass@@QEAA@XZ'] = 'klass::~klass(void)';
 ['?x@@YAHPEAVklass@@AEAV1@@Z'] = 'int x(class klass*,class klass&)';
 ['?x@ns@@3PEAV?$klass@HH@1@EA'] = 'class ns::klass<int,int>*ns::x';
 ['?fn@?$klass@H@ns@@QEBAIXZ'] = 'unsigned int ns::klass<int>::fn(void)const';

 ['??4klass@@QEAAAEBV0@AEBV0@@Z'] = 'class klass const&klass::operator=(class klass const&)';
 ['??7klass@@QEAA_NXZ'] = 'bool klass::operator!(void)';
 ['??8klass@@QEAA_NAEBV0@@Z'] = 'bool klass::operator==(class klass const&)';
 ['??9klass@@QEAA_NAEBV0@@Z'] = 'bool klass::operator!=(class klass const&)';
 ['??Aklass@@QEAAH_K@Z'] = 'int klass::operator[](uint64_t)';
 ['??Cklass@@QEAAHXZ'] = 'int klass::operator->(void)';
 ['??Dklass@@QEAAHXZ'] = 'int klass::operator*(void)';
 ['??Eklass@@QEAAHXZ'] = 'int klass::operator++(void)';
 ['??Eklass@@QEAAHH@Z'] = 'int klass::operator++(int)';
 ['??Fklass@@QEAAHXZ'] = 'int klass::operator--(void)';
 ['??Fklass@@QEAAHH@Z'] = 'int klass::operator--(int)';
 ['??Hklass@@QEAAHH@Z'] = 'int klass::operator+(int)';
 ['??Gklass@@QEAAHH@Z'] = 'int klass::operator-(int)';
 ['??Iklass@@QEAAHH@Z'] = 'int klass::operator&(int)';
 ['??Jklass@@QEAAHH@Z'] = 'int klass::operator->*(int)';
 ['??Kklass@@QEAAHH@Z'] = 'int klass::operator/(int)';
 ['??Mklass@@QEAAHH@Z'] = 'int klass::operator<(int)';
 ['??Nklass@@QEAAHH@Z'] = 'int klass::operator<=(int)';
 ['??Oklass@@QEAAHH@Z'] = 'int klass::operator>(int)';
 ['??Pklass@@QEAAHH@Z'] = 'int klass::operator>=(int)';
 ['??Qklass@@QEAAHH@Z'] = 'int klass::operator,(int)';
 ['??Rklass@@QEAAHH@Z'] = 'int klass::operator()(int)';
 ['??Sklass@@QEAAHXZ'] = 'int klass::operator~(void)';
 ['??Tklass@@QEAAHH@Z'] = 'int klass::operator^(int)';
 ['??Uklass@@QEAAHH@Z'] = 'int klass::operator|(int)';
 ['??Vklass@@QEAAHH@Z'] = 'int klass::operator&&(int)';
 ['??Wklass@@QEAAHH@Z'] = 'int klass::operator||(int)';
 ['??Xklass@@QEAAHH@Z'] = 'int klass::operator*=(int)';
 ['??Yklass@@QEAAHH@Z'] = 'int klass::operator+=(int)';
 ['??Zklass@@QEAAHH@Z'] = 'int klass::operator-=(int)';
 ['??_0klass@@QEAAHH@Z'] = 'int klass::operator/=(int)';
 ['??_1klass@@QEAAHH@Z'] = 'int klass::operator%=(int)';
 ['??_2klass@@QEAAHH@Z'] = 'int klass::operator>>=(int)';
 ['??_3klass@@QEAAHH@Z'] = 'int klass::operator<<=(int)';
 ['??_6klass@@QEAAHH@Z'] = 'int klass::operator^=(int)';
 ['??6@YAAEBVklass@@AEBV0@H@Z'] = 'class klass const&operator<<(class klass const&,int)';
 ['??5@YAAEBVklass@@AEBV0@_K@Z'] = 'class klass const&operator>>(class klass const&,uint64_t)';
 ['??2@YAPEAX_KAEAVklass@@@Z'] = 'void*operator new(uint64_t,class klass&)';
 ['??_U@YAPEAX_KAEAVklass@@@Z'] = 'void*operator new[](uint64_t,class klass&)';
 ['??3@YAXPEAXAEAVklass@@@Z'] = 'void operator delete(void*,class klass&)';
 ['??_V@YAXPEAXAEAVklass@@@Z'] = 'void operator delete[](void*,class klass&)';
}

local shortcases = {
    ['?x@@3HA'] = 'int x';
}

local function main(cases)
    for k,v in pairs(cases) do
        if Demangler.demangle(k) == v then
            print("PASS")
        else
            print("FAIL ", k)
        end
    end
end

--main(longcases)
main(shortcases)
