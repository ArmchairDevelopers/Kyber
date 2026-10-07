namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(LocalizationLanguageChangedMessage, 0x144588440);
_KB_DECLARE_TYPEINFO(FsUITextDatabase, 0x144588340);
_KB_DECLARE_TYPEINFO(FsLocalizationAsset, 0x1445883C0);

#undef _KB_DECLARE_TYPEINFO
}
