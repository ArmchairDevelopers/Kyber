namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(LinearMediaBillboardSettings, 0x14458C140);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardClientEntityData, 0x14458C1C0);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardOverrideFeedEntityData, 0x14458C240);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardFeedEntityData, 0x14458C2C0);
_KB_DECLARE_TYPEINFO(LinearMediaLODCodes, 0x14458C400);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardProviderEntityData, 0x14458C0C0);
_KB_DECLARE_TYPEINFO(LMSBillboardAsset, 0x14458C340);
_KB_DECLARE_TYPEINFO(LODDimension, 0x14458C450);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardDefs, 0x14458C3C0);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardProviderEntity, 0x14458C4A0);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardOverrideFeedEntity, 0x14458C570);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardFeedEntity, 0x14458C640);
_KB_DECLARE_TYPEINFO(LinearMediaBillboardClientEntity, 0x14458C710);

#undef _KB_DECLARE_TYPEINFO
}
