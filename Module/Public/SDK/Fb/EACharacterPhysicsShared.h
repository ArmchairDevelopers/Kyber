namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(EACharacterPhysicsStateTestEntityData, 0x144487170);
_KB_DECLARE_TYPEINFO(EACharacterPhysicsComponentPositions, 0x144487270);
_KB_DECLARE_TYPEINFO(EACharacterPhysicsComponentPosition, 0x1444872C0);
_KB_DECLARE_TYPEINFO(EACharacterPhysicsComponentData, 0x1444871F0);

#undef _KB_DECLARE_TYPEINFO
}
