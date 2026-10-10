namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ServerEACharacterPhysicsComponent, 0x144486DD0);
_KB_DECLARE_TYPEINFO(ClientEACharacterPhysicsComponent, 0x144486E50);

#undef _KB_DECLARE_TYPEINFO
}
