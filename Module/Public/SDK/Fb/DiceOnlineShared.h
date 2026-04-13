namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(DiceOnlineSettings, 0x1444491B0);
_KB_DECLARE_TYPEINFO(DiceOnlineLogLevelT, 0x144449170);
_KB_DECLARE_TYPEINFO(AwardGroup, 0x144449230);
_KB_DECLARE_TYPEINFO(StarLevelCategory, 0x144449270);
_KB_DECLARE_TYPEINFO(WSClass, 0x1444492B0);
_KB_DECLARE_TYPEINFO(InventoryProgress, 0x1444492F0);
_KB_DECLARE_TYPEINFO(OnlineItemType, 0x144449330);
_KB_DECLARE_TYPEINFO(VirtualCurrency, 0x144449370);
_KB_DECLARE_TYPEINFO(RarityType, 0x1444493B0);

#undef _KB_DECLARE_TYPEINFO
}
