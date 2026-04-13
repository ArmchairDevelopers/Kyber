namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(EffectReferenceObjectData, 0x1444B40F0);
_KB_DECLARE_TYPEINFO(EffectBlueprint, 0x1444B4170);
_KB_DECLARE_TYPEINFO(EmitterParameter, 0x1444B42F0);
_KB_DECLARE_TYPEINFO(MeshEmitterMaskBaseAsset, 0x1444B3FF0);
_KB_DECLARE_TYPEINFO(MeshEmitterBaseAsset, 0x1444B4070);
_KB_DECLARE_TYPEINFO(EffectTransformSpaceParam, 0x1444B4370);
_KB_DECLARE_TYPEINFO(EffectParams, 0x1444B43C0);
_KB_DECLARE_TYPEINFO(EffectParameterList, 0x1444B41F0);
_KB_DECLARE_TYPEINFO(EffectParameter, 0x1444B4270);
_KB_DECLARE_TYPEINFO(EffectParameterScopeType, 0x1444B3F70);
_KB_DECLARE_TYPEINFO(EffectParameterType, 0x1444B3FB0);
_KB_DECLARE_TYPEINFO(EmitterGraphParamType, 0x1444B4330);
_KB_DECLARE_TYPEINFO(EmitterExposedTextureInput, 0x1444B4410);
_KB_DECLARE_TYPEINFO(EmitterExposedInput, 0x1444B4460);
_KB_DECLARE_TYPEINFO(EmitterGraphOverrides, 0x1444B44B0);
_KB_DECLARE_TYPEINFO(EffectHandle, 0x1444B4500);

#undef _KB_DECLARE_TYPEINFO
}
