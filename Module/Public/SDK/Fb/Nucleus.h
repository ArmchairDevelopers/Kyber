namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(NucleusPlatformConfiguration, 0x144590DA0);
_KB_DECLARE_TYPEINFO(NucleusCloseBrowserMessage, 0x144590DF0);
_KB_DECLARE_TYPEINFO(NucleusGetLoginStatusMessageBase, 0x144590E40);
_KB_DECLARE_TYPEINFO(NucleusResponseLoginUIMessageBase, 0x144590E90);
_KB_DECLARE_TYPEINFO(NucleusResponseMessageBase, 0x144590EE0);
_KB_DECLARE_TYPEINFO(NucleusRequestAuthCodeMessageBase, 0x144590F30);
_KB_DECLARE_TYPEINFO(NucleusRequestLogoutMessageBase, 0x144590F80);
_KB_DECLARE_TYPEINFO(NucleusRequestLoginMessageBase, 0x144590FD0);
_KB_DECLARE_TYPEINFO(NucleusAsyncRequestType, 0x144590D60);

#undef _KB_DECLARE_TYPEINFO
}
