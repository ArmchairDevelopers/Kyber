namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(EnvironmentDecalVolumeTemplateData, 0x1444AFA10);
_KB_DECLARE_TYPEINFO(EnvironmentDecalVolumeMaskType, 0x1444AF9D0);

#undef _KB_DECLARE_TYPEINFO
}
