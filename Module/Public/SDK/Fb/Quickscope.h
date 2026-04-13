namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(QuickscopeControlEntity, 0x1445ADF00);

#undef _KB_DECLARE_TYPEINFO
}
