namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(VehicleWaypointData, 0x14453BBA0);
_KB_DECLARE_TYPEINFO(WaypointsShapeData, 0x14453BC20);
_KB_DECLARE_TYPEINFO(WaypointData, 0x14453BCA0);
_KB_DECLARE_TYPEINFO(RouteType, 0x14453BA90);
_KB_DECLARE_TYPEINFO(WaypointsSnappingSettings, 0x14453C320);
_KB_DECLARE_TYPEINFO(FollowWaypointsEntityBaseData, 0x14453BD20);
_KB_DECLARE_TYPEINFO(PathFollowingComponentBaseData, 0x14453BDA0);
_KB_DECLARE_TYPEINFO(PathfindingChoice, 0x14453C360);
_KB_DECLARE_TYPEINFO(PathfindingStreamEntityBaseData, 0x14453BE20);
_KB_DECLARE_TYPEINFO(PathfindingDebugSettings, 0x14453BEA0);
_KB_DECLARE_TYPEINFO(PathfindingReplayMode, 0x14453BAD0);
_KB_DECLARE_TYPEINFO(PathfindingTypeAsset, 0x14453BF20);
_KB_DECLARE_TYPEINFO(LinkDat, 0x14453BFA0);
_KB_DECLARE_TYPEINFO(CustomPathLinkData, 0x14453C020);
_KB_DECLARE_TYPEINFO(NavLinkType, 0x14453BB10);
_KB_DECLARE_TYPEINFO(LinkFlowTune, 0x14453C0A0);
_KB_DECLARE_TYPEINFO(PathfindingRuntimeResourceAssetResult, 0x14453C120);
_KB_DECLARE_TYPEINFO(PathfindingRuntimeResourceAsset, 0x14453C1A0);
_KB_DECLARE_TYPEINFO(PathfindingBlobAsset, 0x14453C220);
_KB_DECLARE_TYPEINFO(PathfindingBlob, 0x14453BB50);
_KB_DECLARE_TYPEINFO(PathfindingSystemEntityData, 0x14453C2A0);

#undef _KB_DECLARE_TYPEINFO
}
