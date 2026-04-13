namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(EnvironmentDecalVolumeDynamicState, 0x1444AF810);
_KB_DECLARE_TYPEINFO(EnvironmentDecalVolumeStaticState, 0x1444AF860);
_KB_DECLARE_TYPEINFO(EnvironmentDecalVolumeTemplateBaseData, 0x1444AF790);

#undef _KB_DECLARE_TYPEINFO
}
