namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(DecalVolumeEntityData, 0x144433B10);
_KB_DECLARE_TYPEINFO(DecalEntityData, 0x144433B90);
_KB_DECLARE_TYPEINFO(DecalTemplateAsset, 0x144433C10);
_KB_DECLARE_TYPEINFO(DecalSettings, 0x144433C90);

#undef _KB_DECLARE_TYPEINFO
}
