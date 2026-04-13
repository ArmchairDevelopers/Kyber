namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(OriginSettings, 0x14459B8D0);
_KB_DECLARE_TYPEINFO(OriginCoreNotAvailableMessage, 0x14459B950);
_KB_DECLARE_TYPEINFO(OriginNotLoadedMessage, 0x14459B9A0);
_KB_DECLARE_TYPEINFO(OriginOnlineMessage, 0x14459B9F0);
_KB_DECLARE_TYPEINFO(OriginResponseMessageBase, 0x14459BA40);
_KB_DECLARE_TYPEINFO(OriginRequestMessageBase, 0x14459BA90);
_KB_DECLARE_TYPEINFO(OriginJoinableMessageBase, 0x14459BAE0);
_KB_DECLARE_TYPEINFO(OriginErrorMessage, 0x14459BB30);

#undef _KB_DECLARE_TYPEINFO
}
