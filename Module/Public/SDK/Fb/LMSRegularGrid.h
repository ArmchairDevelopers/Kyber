namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(LMSRegularGridRescaleNodeFilteringMethod, 0x14458F7B0);
_KB_DECLARE_TYPEINFO(LMSRegularGridBindFlags, 0x14458F7F0);
_KB_DECLARE_TYPEINFO(LMSRegularGridOutputAttributeMode, 0x14458F830);
_KB_DECLARE_TYPEINFO(LMSRegularGridSegmentTargetSurfaceImpCpuArrayBase, 0x14458F9F0);
_KB_DECLARE_TYPEINFO(LMSDynaPackRuntime, 0x14458F870);
_KB_DECLARE_TYPEINFO(LMSRegularGridRuntime, 0x14458F8F0);
_KB_DECLARE_TYPEINFO(LMSRegularGridCodecRuntime, 0x14458FC70);
_KB_DECLARE_TYPEINFO(LMSRegularGridSurfaceCpuArrayImpDecoderTemp, 0x14458FA70);
_KB_DECLARE_TYPEINFO(LMSRegularGridSurfaceGpuTexture, 0x14458FCF0);
_KB_DECLARE_TYPEINFO(LMSRegularGridSurfaceGpuBuffer, 0x14458FD70);
_KB_DECLARE_TYPEINFO(LMSRegularGridSurfaceCpuArray, 0x14458FDF0);
_KB_DECLARE_TYPEINFO(LMSRegularGridSurface, 0x14458FE70);
_KB_DECLARE_TYPEINFO(LMSRegularGridCPUArray, 0x14458FAF0);
_KB_DECLARE_TYPEINFO(LMSEffectsDataArray, 0x14458FB70);
_KB_DECLARE_TYPEINFO(LMSRegularGridDefaultCodecRuntime, 0x14458F970);
_KB_DECLARE_TYPEINFO(LMSRegularGridVp6CodecRuntime, 0x14458FBF0);

#undef _KB_DECLARE_TYPEINFO
}
