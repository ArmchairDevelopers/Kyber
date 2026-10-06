namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(SnowglobeTrackerEntityData, 0x1445D44F0);
_KB_DECLARE_TYPEINFO(SnowglobeComponentData, 0x1445D4320);
_KB_DECLARE_TYPEINFO(CinematicSettingsSplitterData, 0x1445D4570);
_KB_DECLARE_TYPEINFO(NetworkSnowglobeStatusChangeMessage, 0x1445D44A0);
_KB_DECLARE_TYPEINFO(CinematicSettings, 0x1445D43A0);
_KB_DECLARE_TYPEINFO(SnowglobeEntityData, 0x1445D45F0);
_KB_DECLARE_TYPEINFO(SnowglobeEntityStatus, 0x1445D4670);
_KB_DECLARE_TYPEINFO(MultiplayerStartType, 0x1445D4220);
_KB_DECLARE_TYPEINFO(UserInputType, 0x1445D4260);
_KB_DECLARE_TYPEINFO(CleanUpType, 0x1445D42A0);
_KB_DECLARE_TYPEINFO(PrimeType, 0x1445D42E0);
_KB_DECLARE_TYPEINFO(ServerSnowglobeEntity, 0x1445D46B0);
_KB_DECLARE_TYPEINFO(SnowglobeTrackerEntity, 0x1445D4780);
_KB_DECLARE_TYPEINFO(SnowglobeComponent, 0x1445D4420);
_KB_DECLARE_TYPEINFO(CinematicSettingsSplitterEntity, 0x1445D4850);
_KB_DECLARE_TYPEINFO(ClientSnowglobeEntity, 0x1445D4920);

#undef _KB_DECLARE_TYPEINFO
}
