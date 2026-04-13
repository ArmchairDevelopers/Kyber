namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(NavigationInterfaceData, 0x1443F3730);
_KB_DECLARE_TYPEINFO(LocoEntityData, 0x1443F36B0);
_KB_DECLARE_TYPEINFO(AIWaypointExtraWaypointDataPtr, 0x1443F37B0);
_KB_DECLARE_TYPEINFO(AIWaypointExtraTeleport, 0x1443F3800);
_KB_DECLARE_TYPEINFO(AIWaypointExtraSpatial, 0x1443F3850);
_KB_DECLARE_TYPEINFO(AIWaypointGUID, 0x1443F38A0);
_KB_DECLARE_TYPEINFO(ServerNavigationInterface, 0x1443F39C0);
_KB_DECLARE_TYPEINFO(ServerAuthNavigationInterface, 0x1443F3A90);
_KB_DECLARE_TYPEINFO(LocoEntity, 0x1443F38F0);
_KB_DECLARE_TYPEINFO(ClientNavigationInterface, 0x1443F3B60);

#undef _KB_DECLARE_TYPEINFO
}
