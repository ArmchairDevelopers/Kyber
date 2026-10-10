namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(FlapComponentData, 0x14460A420);
_KB_DECLARE_TYPEINFO(WingComponentData, 0x14460A4A0);

#undef _KB_DECLARE_TYPEINFO
}
