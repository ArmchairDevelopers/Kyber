namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(URLConfigData, 0x1446162A0);
_KB_DECLARE_TYPEINFO(WebUtilsEnvironment, 0x144616260);

#undef _KB_DECLARE_TYPEINFO
}
