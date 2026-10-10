namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ClientWallOfDoomMeshEntity, 0x14460A690);
_KB_DECLARE_TYPEINFO(ClientWallOfDoomEntity, 0x14460A760);

#undef _KB_DECLARE_TYPEINFO
}
