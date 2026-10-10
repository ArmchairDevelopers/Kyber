namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ShadowExtrusionLevelDataEntity, 0x1445D21B0);
_KB_DECLARE_TYPEINFO(ShadowExtrusionLightDirectionEntity, 0x1445D2280);
_KB_DECLARE_TYPEINFO(ShadowExtrusionDataEntity, 0x1445D2350);

#undef _KB_DECLARE_TYPEINFO
}
