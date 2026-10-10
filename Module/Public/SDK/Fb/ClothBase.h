namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ClothControlHandle, 0x1444AF4B0);
_KB_DECLARE_TYPEINFO(SimulationDynamicState, 0x1444AF500);
_KB_DECLARE_TYPEINFO(SimulationStaticState, 0x1444AF550);
_KB_DECLARE_TYPEINFO(ClothWrappingAsset, 0x1444AF430);
_KB_DECLARE_TYPEINFO(ClothProcessingMode, 0x1444AED20);
_KB_DECLARE_TYPEINFO(BoxClothCollision, 0x1444AED60);
_KB_DECLARE_TYPEINFO(TaperedCapsuleClothCollision, 0x1444AEDE0);
_KB_DECLARE_TYPEINFO(CapsuleClothCollision, 0x1444AEE60);
_KB_DECLARE_TYPEINFO(SphereClothCollision, 0x1444AEEE0);
_KB_DECLARE_TYPEINFO(ClothCollisionGeometry, 0x1444AEF60);
_KB_DECLARE_TYPEINFO(ClothBaseAsset, 0x1444AEFE0);
_KB_DECLARE_TYPEINFO(ClothControlDynamicState, 0x1444AF060);
_KB_DECLARE_TYPEINFO(EAClothEntityData, 0x1444AF0B0);
_KB_DECLARE_TYPEINFO(EAClothAssetData, 0x1444AF130);

#undef _KB_DECLARE_TYPEINFO
}
