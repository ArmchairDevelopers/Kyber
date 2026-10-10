namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ReplaySettings, 0x1445F1150);
_KB_DECLARE_TYPEINFO(EmptyDynamicState, 0x1445F11D0);
_KB_DECLARE_TYPEINFO(EmptyStaticState, 0x1445F1220);
_KB_DECLARE_TYPEINFO(BundleDynamicState, 0x1445F1270);
_KB_DECLARE_TYPEINFO(BundleStaticState, 0x1445F12C0);
_KB_DECLARE_TYPEINFO(TransformSpaceHandle, 0x1445F1310);
_KB_DECLARE_TYPEINFO(SkeletonHandle, 0x1445F1360);

#undef _KB_DECLARE_TYPEINFO
}
