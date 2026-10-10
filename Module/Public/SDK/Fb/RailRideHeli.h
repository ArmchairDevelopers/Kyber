namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(RailRideHeliWaypointData, 0x1445AF160);
_KB_DECLARE_TYPEINFO(RailRideHeliSegmentData, 0x1445AF330);
_KB_DECLARE_TYPEINFO(RailRideNodePointToData, 0x1445AF1E0);
_KB_DECLARE_TYPEINFO(RailRideHeliPointToSide, 0x1445AF0E0);
_KB_DECLARE_TYPEINFO(RailRideHeliData, 0x1445AF260);
_KB_DECLARE_TYPEINFO(RailRideHeliControlType, 0x1445AF120);
_KB_DECLARE_TYPEINFO(RailRideHeliClientActivatedMessage, 0x1445AF2E0);
_KB_DECLARE_TYPEINFO(ServerRailRideHeliEntity, 0x1445AF3B0);
_KB_DECLARE_TYPEINFO(RailRideHeliSegmentEntity, 0x1445AF480);
_KB_DECLARE_TYPEINFO(ClientRailRideHeliEntity, 0x1445AF550);

#undef _KB_DECLARE_TYPEINFO
}
