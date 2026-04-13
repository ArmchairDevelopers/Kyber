namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(MovieEntityData, 0x144535530);
_KB_DECLARE_TYPEINFO(ClientMovieEntity, 0x1445355B0);

#undef _KB_DECLARE_TYPEINFO
}
