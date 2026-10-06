namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PresenceMatchmakingServiceData, 0x14473FFF0);
_KB_DECLARE_TYPEINFO(PresenceMatchmakerMessageBase, 0x144740070);
_KB_DECLARE_TYPEINFO(PresenceMatchmakingRequestMessageBase, 0x1447400C0);
_KB_DECLARE_TYPEINFO(ClientMatchmakingService, 0x144740110);

#undef _KB_DECLARE_TYPEINFO
}
