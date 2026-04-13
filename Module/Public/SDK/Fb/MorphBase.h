namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(MorphStatic, 0x144532DB0);
_KB_DECLARE_TYPEINFO(MorphTargets, 0x144532E30);
_KB_DECLARE_TYPEINFO(MorphTargetsInterfaceInfo, 0x144532F30);
_KB_DECLARE_TYPEINFO(MorphDebugRenderOption, 0x144532EB0);
_KB_DECLARE_TYPEINFO(MorphDebugRenderFlag, 0x144532EF0);
_KB_DECLARE_TYPEINFO(MorphTargetsResource, 0x144532F80);
_KB_DECLARE_TYPEINFO(MorphResource, 0x144533000);

#undef _KB_DECLARE_TYPEINFO
}
