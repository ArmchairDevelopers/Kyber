namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PixelPaintingBlueprint, 0x1445ADDC0);

#undef _KB_DECLARE_TYPEINFO
}
