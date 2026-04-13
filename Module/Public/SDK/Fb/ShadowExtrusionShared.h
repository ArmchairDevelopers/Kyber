namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ShadowExtrusionLevelSettings, 0x1445D2910);
_KB_DECLARE_TYPEINFO(ShadowExtrusionLightDirectionEntityData, 0x1445D2990);
_KB_DECLARE_TYPEINFO(ShadowExtrusionLevelDataEntityData, 0x1445D2A10);
_KB_DECLARE_TYPEINFO(ShadowExtrusionDataEntityData, 0x1445D2A90);
_KB_DECLARE_TYPEINFO(ShadowExtrusionAsset, 0x1445D2B10);
_KB_DECLARE_TYPEINFO(ShadowExtrusionObjectData, 0x1445D2B90);
_KB_DECLARE_TYPEINFO(ShadowExtrusionObjectInstance, 0x1445D2C10);

#undef _KB_DECLARE_TYPEINFO
}
