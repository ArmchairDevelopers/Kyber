namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(EmitterHandle, 0x1444BEB90);
_KB_DECLARE_TYPEINFO(EmitterCreateState, 0x1444BEBE0);
_KB_DECLARE_TYPEINFO(EmitterDynamicState, 0x1444BEC30);
_KB_DECLARE_TYPEINFO(EmitterControlPoint, 0x1444BEC80);
_KB_DECLARE_TYPEINFO(EmitterState, 0x1444BE890);
_KB_DECLARE_TYPEINFO(EmitterStaticState, 0x1444BECD0);
_KB_DECLARE_TYPEINFO(EmitterExclusionVolumesBaseAsset, 0x1444BE990);
_KB_DECLARE_TYPEINFO(EmitterTag, 0x1444BEA10);
_KB_DECLARE_TYPEINFO(EmitterGraphBaseAsset, 0x1444BEA90);
_KB_DECLARE_TYPEINFO(EmitterBaseAsset, 0x1444BEB10);
_KB_DECLARE_TYPEINFO(PropertyIdLookup, 0x1444BED20);
_KB_DECLARE_TYPEINFO(EmitterExposableType, 0x1444BE8D0);
_KB_DECLARE_TYPEINFO(EmitterExclusionVolumeResultData, 0x1444BED70);
_KB_DECLARE_TYPEINFO(LightProbeSampleOffsetMethod, 0x1444BE910);
_KB_DECLARE_TYPEINFO(LightProbeSampleMethod, 0x1444BE950);

#undef _KB_DECLARE_TYPEINFO
}
