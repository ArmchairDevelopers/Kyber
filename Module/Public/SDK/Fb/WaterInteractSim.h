namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(WaterHeightEntityData, 0x14460CD60);
_KB_DECLARE_TYPEINFO(WaterInteractWaveEntityData, 0x14460CDE0);
_KB_DECLARE_TYPEINFO(WaterInteractTurbulenceDisturbEntityData, 0x14460CE60);
_KB_DECLARE_TYPEINFO(WaterInteractPhysicsComponentData, 0x14460CEE0);
_KB_DECLARE_TYPEINFO(WaterSurfaceEntityData, 0x14460CF60);
_KB_DECLARE_TYPEINFO(WaterOceanSimulationEntityData, 0x14460CB60);
_KB_DECLARE_TYPEINFO(WaterEffectSetup, 0x14460CFE0);
_KB_DECLARE_TYPEINFO(WaterAmbientFoamEffectSpawner, 0x14460D060);
_KB_DECLARE_TYPEINFO(WaterLevelDescriptionComponent, 0x14460CBE0);
_KB_DECLARE_TYPEINFO(ServerWaterOceanSimulationEntity, 0x14460D180);
_KB_DECLARE_TYPEINFO(ClientWaterOceanSimulationEntity, 0x14460D250);
_KB_DECLARE_TYPEINFO(WaterOceanSimulationEntity, 0x14460D0B0);
_KB_DECLARE_TYPEINFO(ClientWaterInteractWaveEntity, 0x14460D320);
_KB_DECLARE_TYPEINFO(WaterInteractWaveEntity, 0x14460D3F0);
_KB_DECLARE_TYPEINFO(WaterHeightEntity, 0x14460D4C0);
_KB_DECLARE_TYPEINFO(ServerWaterSurfaceEntity, 0x14460D590);
_KB_DECLARE_TYPEINFO(ServerWaterInteractPhysicsComponent, 0x14460CC60);
_KB_DECLARE_TYPEINFO(ClientWaterSurfaceEntity, 0x14460D660);
_KB_DECLARE_TYPEINFO(ClientWaterInteractPhysicsComponent, 0x14460CCE0);
_KB_DECLARE_TYPEINFO(WaterInteractTurbulenceDisturbEntity, 0x14460D730);

#undef _KB_DECLARE_TYPEINFO
}
