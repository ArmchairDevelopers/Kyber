namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(DebrisCollisionComponentData, 0x144432C40);
_KB_DECLARE_TYPEINFO(ProceduralDestructionForceData, 0x144432CC0);
_KB_DECLARE_TYPEINFO(DebrisClusterData, 0x144432D40);
_KB_DECLARE_TYPEINFO(DebrisClusterPartInfoData, 0x144432EC0);
_KB_DECLARE_TYPEINFO(DebrisSystemSettings, 0x144432DC0);
_KB_DECLARE_TYPEINFO(DebrisSystemAsset, 0x144432E40);
_KB_DECLARE_TYPEINFO(DebrisHavokInfo, 0x144432F10);
_KB_DECLARE_TYPEINFO(DebrisSystemMetrics, 0x144432F60);
_KB_DECLARE_TYPEINFO(ServerDebrisCluster, 0x144433080);
_KB_DECLARE_TYPEINFO(DebrisSpawnEvent, 0x144433220);
_KB_DECLARE_TYPEINFO(DebrisCluster, 0x144432FB0);
_KB_DECLARE_TYPEINFO(ClientDebrisCluster, 0x144433150);

#undef _KB_DECLARE_TYPEINFO
}
