namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ZoneStreamerZoneDestroyMessage, 0x14473B590);
_KB_DECLARE_TYPEINFO(ZoneStreamerZoneInitMessage, 0x14473B5E0);
_KB_DECLARE_TYPEINFO(ZoneStreamerZoneChangedMessage, 0x14473AFB0);
_KB_DECLARE_TYPEINFO(ZoneStreamerShutdownMessage, 0x14473B630);
_KB_DECLARE_TYPEINFO(ZoneStreamerAnnounceMessage, 0x14473B680);
_KB_DECLARE_TYPEINFO(ZoneStreamerNotificationEntityData, 0x14473B050);
_KB_DECLARE_TYPEINFO(VistaZoneInfo, 0x14473B6D0);
_KB_DECLARE_TYPEINFO(VistaZoneMeshInfo, 0x14473B720);
_KB_DECLARE_TYPEINFO(ZoneStreamerVistaEntityData, 0x14473B0D0);
_KB_DECLARE_TYPEINFO(ZoneStreamerSubWorldRod, 0x14473B150);
_KB_DECLARE_TYPEINFO(ZoneStreamerEntityData, 0x14473B1D0);
_KB_DECLARE_TYPEINFO(ZoneStreamerInfo, 0x14473B000);
_KB_DECLARE_TYPEINFO(ZoneStreamerZoneInfo, 0x14473B770);
_KB_DECLARE_TYPEINFO(ZoneStreamerRasterNodeUsage, 0x14473B550);
_KB_DECLARE_TYPEINFO(ZoneStreamerSettings, 0x14473B250);
_KB_DECLARE_TYPEINFO(ZoneStreamerFocusEntityData, 0x14473B2D0);
_KB_DECLARE_TYPEINFO(ZoneStreamerZoneProxyEntityData, 0x14473B350);
_KB_DECLARE_TYPEINFO(ZoneStreamerTransitionEntityData, 0x14473B3D0);
_KB_DECLARE_TYPEINFO(ZoneStreamerControlEntityData, 0x14473B450);
_KB_DECLARE_TYPEINFO(ZoneStreamerLogicEntityData, 0x14473B4D0);
_KB_DECLARE_TYPEINFO(ZoneStreamerZoneProxyEntity, 0x14473B7C0);
_KB_DECLARE_TYPEINFO(ZoneStreamerVistaEntity, 0x14473B960);
_KB_DECLARE_TYPEINFO(ZoneStreamerTransitionEntity, 0x14473B890);
_KB_DECLARE_TYPEINFO(ZoneStreamerNotificationEntity, 0x14473BA30);
_KB_DECLARE_TYPEINFO(ZoneStreamerLogicEntity, 0x14473A020);
_KB_DECLARE_TYPEINFO(ZoneStreamerGrid, 0x144739B90);
_KB_DECLARE_TYPEINFO(ZoneStreamerEntityBase, 0x144739E80);
_KB_DECLARE_TYPEINFO(ZoneStreamerEntity, 0x144739C10);
_KB_DECLARE_TYPEINFO(ZoneStreamerControlEntity, 0x144739CE0);
_KB_DECLARE_TYPEINFO(RealmProxy, 0x144739F50);
_KB_DECLARE_TYPEINFO(ZoneStreamerFocusEntity, 0x144739DB0);

#undef _KB_DECLARE_TYPEINFO
}
