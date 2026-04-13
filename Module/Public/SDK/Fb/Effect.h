namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(VisualEnvironmentEffectEntityData, 0x1444B30D0);
_KB_DECLARE_TYPEINFO(SoundDynamicState, 0x1444B3550);
_KB_DECLARE_TYPEINFO(SoundState, 0x1444B3010);
_KB_DECLARE_TYPEINFO(SoundStaticState, 0x1444B35A0);
_KB_DECLARE_TYPEINFO(LocationEffectEntityData, 0x1444B3150);
_KB_DECLARE_TYPEINFO(LocationType, 0x1444B3050);
_KB_DECLARE_TYPEINFO(LightEffectEntityData, 0x1444B31D0);
_KB_DECLARE_TYPEINFO(EmitterSystemComponent, 0x1444B3250);
_KB_DECLARE_TYPEINFO(EmitterExclusionVolumeData, 0x1444B32D0);
_KB_DECLARE_TYPEINFO(EmitterEntityData, 0x1444B3350);
_KB_DECLARE_TYPEINFO(EmitterGraphEntityData, 0x1444B33D0);
_KB_DECLARE_TYPEINFO(EmitterChildEffectEntityData, 0x1444B3450);
_KB_DECLARE_TYPEINFO(SpawnProbabilityRandomType, 0x1444B3090);
_KB_DECLARE_TYPEINFO(EffectSystemSettings, 0x1444B34D0);
_KB_DECLARE_TYPEINFO(EffectSystemComponent, 0x1444B2460);
_KB_DECLARE_TYPEINFO(BlueprintEffectEntityData, 0x1444B24E0);
_KB_DECLARE_TYPEINFO(EffectAsset, 0x1444B2560);
_KB_DECLARE_TYPEINFO(EffectEntityData, 0x1444B25E0);
_KB_DECLARE_TYPEINFO(EffectEntity, 0x1444B2660);

#undef _KB_DECLARE_TYPEINFO
}
