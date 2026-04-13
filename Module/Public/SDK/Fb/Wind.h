namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(Baked3DAs2x2DTexWindForceBase, 0x1445472B0);
_KB_DECLARE_TYPEINFO(ConeWindForceBase, 0x144547300);
_KB_DECLARE_TYPEINFO(SphereWindForceBase, 0x144547350);
_KB_DECLARE_TYPEINFO(LocalWindForce, 0x1445473A0);
_KB_DECLARE_TYPEINFO(DirectionWindForceBase, 0x1445473F0);
_KB_DECLARE_TYPEINFO(LocalWindForceGroup, 0x144547230);
_KB_DECLARE_TYPEINFO(LocalWindForceType, 0x144547270);

#undef _KB_DECLARE_TYPEINFO
}
