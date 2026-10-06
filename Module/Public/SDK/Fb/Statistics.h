namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PresenceStatisticsRequestMessageBase, 0x144742650);
_KB_DECLARE_TYPEINFO(PresenceStatisticsMessageBase, 0x1447426A0);
_KB_DECLARE_TYPEINFO(PresenceLeaderboardServiceData, 0x144742550);
_KB_DECLARE_TYPEINFO(PresenceStatisticsServiceData, 0x1447425D0);
_KB_DECLARE_TYPEINFO(PresenceGetLeaderboardRequestParameters, 0x1447426F0);
_KB_DECLARE_TYPEINFO(PresenceDownloadStatisticsRequestParameters, 0x144742770);
_KB_DECLARE_TYPEINFO(ClientStatisticsService, 0x1447427F0);
_KB_DECLARE_TYPEINFO(ClientLeaderboardService, 0x144742870);

#undef _KB_DECLARE_TYPEINFO
}
