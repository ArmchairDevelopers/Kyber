namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ClothAsset, 0x1444AE2E0);
_KB_DECLARE_TYPEINFO(ClothSystemSettings, 0x1444AE360);
_KB_DECLARE_TYPEINFO(ClothComponentData, 0x1444AE3E0);
_KB_DECLARE_TYPEINFO(ClothAssetInstance, 0x1444AE460);
_KB_DECLARE_TYPEINFO(ClothCollisionComponentData, 0x1444AE4E0);
_KB_DECLARE_TYPEINFO(ClothObjectBlueprint, 0x1444AE560);
_KB_DECLARE_TYPEINFO(ClothEntityData, 0x1444AE5E0);
_KB_DECLARE_TYPEINFO(ClothObjectVariationExampleEntityData, 0x1444AD980);
_KB_DECLARE_TYPEINFO(ClothInstanceObserverEntityData, 0x1444ADA00);
_KB_DECLARE_TYPEINFO(ClothDebugRendererSettings, 0x1444ADA80);
_KB_DECLARE_TYPEINFO(ClothCollisionComponent, 0x1444ADB00);
_KB_DECLARE_TYPEINFO(ClothEntity, 0x1444ADD00);
_KB_DECLARE_TYPEINFO(ClothManager, 0x1444ADC00);
_KB_DECLARE_TYPEINFO(EAClothMemoryInitializer, 0x1444ADC80);
_KB_DECLARE_TYPEINFO(ClothComponent, 0x1444ADB80);

#undef _KB_DECLARE_TYPEINFO
}
