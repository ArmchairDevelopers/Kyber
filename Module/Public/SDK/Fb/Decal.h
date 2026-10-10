namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(DecalDynamicState, 0x1444335F0);
_KB_DECLARE_TYPEINFO(DecalStaticState, 0x144433640);
_KB_DECLARE_TYPEINFO(DecalLifeTime, 0x1444335B0);
_KB_DECLARE_TYPEINFO(DecalVolumeEntity, 0x144433690);
_KB_DECLARE_TYPEINFO(DecalEntity, 0x144433760);

#undef _KB_DECLARE_TYPEINFO
}
