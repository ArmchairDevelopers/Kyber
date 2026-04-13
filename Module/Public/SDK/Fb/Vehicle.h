namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ServerWingComponent, 0x14460A0B0);
_KB_DECLARE_TYPEINFO(ServerFlapComponent, 0x14460A130);
_KB_DECLARE_TYPEINFO(ClientWingComponent, 0x14460A1B0);
_KB_DECLARE_TYPEINFO(ClientFlapComponent, 0x14460A230);

#undef _KB_DECLARE_TYPEINFO
}
