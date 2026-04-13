namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PresencePartyServiceData, 0x144740B90);
_KB_DECLARE_TYPEINFO(PresenceDurangoPartyBackendData, 0x144740C10);
_KB_DECLARE_TYPEINFO(PresencePs4PartyBackendData, 0x144740C90);
_KB_DECLARE_TYPEINFO(PresenceOriginPartyBackendData, 0x144740D10);
_KB_DECLARE_TYPEINFO(DurangoCurrentActivity, 0x144740B10);
_KB_DECLARE_TYPEINFO(OriginPartyType, 0x144740B50);
_KB_DECLARE_TYPEINFO(PresencePartyRequestMessageBase, 0x144740D90);
_KB_DECLARE_TYPEINFO(PresencePartyMessageBase, 0x144740DE0);
_KB_DECLARE_TYPEINFO(PresenceLeavePartyRequestParameters, 0x144740E30);
_KB_DECLARE_TYPEINFO(PresenceAcceptPartyInviteRequestParameters, 0x144740EB0);
_KB_DECLARE_TYPEINFO(PresenceSendPartyInvitesRequestParameters, 0x144740F30);
_KB_DECLARE_TYPEINFO(PresenceCreatePartyRequestParameters, 0x144740FB0);
_KB_DECLARE_TYPEINFO(ClientPartyService, 0x144741130);
_KB_DECLARE_TYPEINFO(PartyEvent, 0x144741030);
_KB_DECLARE_TYPEINFO(OriginPartyBackend, 0x1447410B0);

#undef _KB_DECLARE_TYPEINFO
}
