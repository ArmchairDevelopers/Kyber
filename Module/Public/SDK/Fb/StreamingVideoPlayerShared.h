namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(StreamingVideoPlayerEntityData, 0x1445F18B0);

#undef _KB_DECLARE_TYPEINFO
}
