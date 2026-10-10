namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(BifrostSettings, 0x14442A060);
_KB_DECLARE_TYPEINFO(BifrostInternal, 0x14442A0E0);
_KB_DECLARE_TYPEINFO(BifrostHttpErrorMessage, 0x14442A160);
_KB_DECLARE_TYPEINFO(BifrostConnectionErrorMessage, 0x14442A1B0);

#undef _KB_DECLARE_TYPEINFO
}
