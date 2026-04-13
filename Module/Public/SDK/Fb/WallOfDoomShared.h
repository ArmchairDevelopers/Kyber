namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(WallOfDoomMeshEntityData, 0x14460AA90);
_KB_DECLARE_TYPEINFO(WallOfDoomEntityData, 0x14460AB10);
_KB_DECLARE_TYPEINFO(WallOfDoomHeightmapMetaData, 0x14460AA40);

#undef _KB_DECLARE_TYPEINFO
}
