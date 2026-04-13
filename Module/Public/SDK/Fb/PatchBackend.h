namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(LiveContentUpdateSettings, 0x14459CB20);
_KB_DECLARE_TYPEINFO(LCUServiceMessageProgressMessage, 0x14459CC20);
_KB_DECLARE_TYPEINFO(LCUServiceMessageStateChangedMessage, 0x14459CC70);
_KB_DECLARE_TYPEINFO(LCUEntityData, 0x14459CBA0);
_KB_DECLARE_TYPEINFO(ClientLCUEntity, 0x14459CCC0);

#undef _KB_DECLARE_TYPEINFO
}
