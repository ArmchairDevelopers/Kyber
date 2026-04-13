namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(WaterWaveHandle, 0x14460B820);
_KB_DECLARE_TYPEINFO(WaterSurfaceHandle, 0x14460B870);
_KB_DECLARE_TYPEINFO(WaterGlobalHandle, 0x14460B8C0);
_KB_DECLARE_TYPEINFO(WaterSimulationHandle, 0x14460B700);
_KB_DECLARE_TYPEINFO(WaterWaveDynamicState, 0x14460B910);
_KB_DECLARE_TYPEINFO(WaterWaveStaticState, 0x14460B960);
_KB_DECLARE_TYPEINFO(WaterWaveCreateState, 0x14460B9B0);
_KB_DECLARE_TYPEINFO(WaterSurfaceDynamicState, 0x14460BA00);
_KB_DECLARE_TYPEINFO(WaterSurfaceStaticState, 0x14460BA50);
_KB_DECLARE_TYPEINFO(WaterSimulationDynamicState, 0x14460BAA0);
_KB_DECLARE_TYPEINFO(WaterSimulationStaticState, 0x14460BAF0);
_KB_DECLARE_TYPEINFO(WaterGlobalDynamicState, 0x14460BB40);
_KB_DECLARE_TYPEINFO(WaterGlobalStaticState, 0x14460BB90);
_KB_DECLARE_TYPEINFO(WaterAmbientFoamEffect, 0x14460BBE0);
_KB_DECLARE_TYPEINFO(WaterSurfaceCreateState, 0x14460BC30);
_KB_DECLARE_TYPEINFO(WaterDisturbParams, 0x14460BC80);
_KB_DECLARE_TYPEINFO(WaterEntityClipInfo, 0x14460B750);
_KB_DECLARE_TYPEINFO(WaterInteractLevelSettings, 0x14460BCD0);
_KB_DECLARE_TYPEINFO(WaterInteractSettings, 0x14460B7A0);

#undef _KB_DECLARE_TYPEINFO
}
