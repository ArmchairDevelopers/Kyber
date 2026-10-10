namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PresenceOverlayServiceData, 0x14473E140);
_KB_DECLARE_TYPEINFO(PresenceOverlayRequestMessageBase, 0x14473E1C0);
_KB_DECLARE_TYPEINFO(PresenceOverlayMessageBase, 0x14473E210);
_KB_DECLARE_TYPEINFO(PresenceShowInviteUIRequestParameters, 0x14473E260);
_KB_DECLARE_TYPEINFO(PresenceDisplayFriendRequestDialogRequestParameters, 0x14473E2E0);
_KB_DECLARE_TYPEINFO(PresenceDisplayFriendsDialogRequestParameters, 0x14473E360);
_KB_DECLARE_TYPEINFO(PresenceDisplayUserProfileRequestParameters, 0x14473E3E0);
_KB_DECLARE_TYPEINFO(ClientOverlayService, 0x14473E460);

#undef _KB_DECLARE_TYPEINFO
}
