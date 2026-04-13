namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(DeformationComponentData, 0x1444B0240);
_KB_DECLARE_TYPEINFO(BoneToPartMapping, 0x1444B0440);
_KB_DECLARE_TYPEINFO(DeformationAsset, 0x1444B02C0);
_KB_DECLARE_TYPEINFO(ServerDeformationComponent, 0x1444B0340);
_KB_DECLARE_TYPEINFO(DeformationResource, 0x1444B0490);
_KB_DECLARE_TYPEINFO(DeformationManager, 0x1444B0510);
_KB_DECLARE_TYPEINFO(ClientDeformationComponent, 0x1444B03C0);

#undef _KB_DECLARE_TYPEINFO
}
