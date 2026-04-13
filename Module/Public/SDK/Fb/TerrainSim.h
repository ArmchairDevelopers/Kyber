namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(WaterAsset, 0x144543940);
_KB_DECLARE_TYPEINFO(PhysicsTerrainUpdaterComponentData, 0x1445439C0);

#undef _KB_DECLARE_TYPEINFO
}
