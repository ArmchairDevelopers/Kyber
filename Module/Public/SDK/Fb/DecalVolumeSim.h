namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(EnvironmentDecalVolumeData, 0x1444AFC00);
_KB_DECLARE_TYPEINFO(EnvironmentDecalVolumeEntity, 0x1444AFC80);

#undef _KB_DECLARE_TYPEINFO
}
