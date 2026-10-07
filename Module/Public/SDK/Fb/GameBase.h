namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(UIImScreenDynamicState, 0x1444BF7D0);
_KB_DECLARE_TYPEINFO(UIScreenSamplerSettings, 0x1444BF600);
_KB_DECLARE_TYPEINFO(UIImScreenStaticState, 0x1444BF820);
_KB_DECLARE_TYPEINFO(UIImReverseHandle, 0x1444BF870);
_KB_DECLARE_TYPEINFO(UIImCommandHandle, 0x1444BF8C0);
_KB_DECLARE_TYPEINFO(UIImScreenHandle, 0x1444BF910);
_KB_DECLARE_TYPEINFO(UIImTextCommandConfig, 0x1444BF960);
_KB_DECLARE_TYPEINFO(UITextureMappingAssetBinding, 0x1444BF9B0);
_KB_DECLARE_TYPEINFO(UIElementFontEffectBaseAsset, 0x1444BF650);
_KB_DECLARE_TYPEINFO(UIElementFontStyleBaseAsset, 0x1444BF6D0);
_KB_DECLARE_TYPEINFO(UITextureMappingBaseAsset, 0x1444BF750);
_KB_DECLARE_TYPEINFO(UIScreenProjectionMode, 0x1444BF580);
_KB_DECLARE_TYPEINFO(UIElementAlignment, 0x1444BF5C0);

#undef _KB_DECLARE_TYPEINFO
}
