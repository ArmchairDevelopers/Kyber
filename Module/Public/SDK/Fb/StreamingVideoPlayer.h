namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(StreamingVideoDynamicState, 0x1445F1630);
_KB_DECLARE_TYPEINFO(StreamingVideoStaticState, 0x1445F1680);
_KB_DECLARE_TYPEINFO(StreamingVideoHandle, 0x1445F16D0);
_KB_DECLARE_TYPEINFO(StreamingVideoPlayerEntity, 0x1445F1720);

#undef _KB_DECLARE_TYPEINFO
}
