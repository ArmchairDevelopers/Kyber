namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PresenceAchievementServiceData, 0x14473C010);
_KB_DECLARE_TYPEINFO(PresenceAchievementRequestMessageBase, 0x14473C190);
_KB_DECLARE_TYPEINFO(PresenceAchievementMessageBase, 0x14473C1E0);
_KB_DECLARE_TYPEINFO(Xb1AchievementsBackendData, 0x14473C090);
_KB_DECLARE_TYPEINFO(Ps4TrophyBackendData, 0x14473C110);
_KB_DECLARE_TYPEINFO(ClientAchievementService, 0x14473C2B0);
_KB_DECLARE_TYPEINFO(PresenceUpdateAchievementsRequestParameters, 0x14473C330);
_KB_DECLARE_TYPEINFO(PresenceUnlockAchievementsRequestParameters, 0x14473C230);

#undef _KB_DECLARE_TYPEINFO
}
