namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(InputConfiguration, 0x1443FDE40);
_KB_DECLARE_TYPEINFO(InputSet, 0x1443FDEC0);
_KB_DECLARE_TYPEINFO(InputBinding, 0x1443FDF40);
_KB_DECLARE_TYPEINFO(WindowSettings, 0x1443FDFC0);
_KB_DECLARE_TYPEINFO(ApplicationWindowFullscreenRequestMessage, 0x1443FE0C0);
_KB_DECLARE_TYPEINFO(ApplicationWindowResizeEndMessage, 0x1443FE110);
_KB_DECLARE_TYPEINFO(ApplicationWindowStyleChangedMessage, 0x1443FE160);
_KB_DECLARE_TYPEINFO(ApplicationWindowClosedMessage, 0x1443FE1B0);
_KB_DECLARE_TYPEINFO(ApplicationWindowCreatedMessage, 0x1443FE200);
_KB_DECLARE_TYPEINFO(WindowFullscreenMode, 0x1443FE040);
_KB_DECLARE_TYPEINFO(WindowResizeType, 0x1443FE080);
_KB_DECLARE_TYPEINFO(Window, 0x1443FE2D0);
_KB_DECLARE_TYPEINFO(Win32Window, 0x1443FE250);

#undef _KB_DECLARE_TYPEINFO
}
