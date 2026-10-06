namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(VegetationSystemSettings, 0x1445469D0);
_KB_DECLARE_TYPEINFO(VegetationTreeBreakNodeState, 0x144546B50);
_KB_DECLARE_TYPEINFO(VegetationTreeBreakNodeDestruction, 0x144546BA0);
_KB_DECLARE_TYPEINFO(VegetationTreeEntityData, 0x144546A50);
_KB_DECLARE_TYPEINFO(VegetationEffectSlot, 0x144546980);
_KB_DECLARE_TYPEINFO(VegetationBaseEntityData, 0x144546AD0);
_KB_DECLARE_TYPEINFO(VegetationTreeEntity, 0x144546BF0);
_KB_DECLARE_TYPEINFO(ServerVegetationTreeEntity, 0x144546CC0);
_KB_DECLARE_TYPEINFO(ClientVegetationTreeEntity, 0x144546D90);

#undef _KB_DECLARE_TYPEINFO
}
