namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(StaticMorphEntityData, 0x144533E20);
_KB_DECLARE_TYPEINFO(StaticMorphSaveGameStorageEntityData, 0x144533EA0);
_KB_DECLARE_TYPEINFO(StaticMorphStorageEntityData, 0x144533F20);
_KB_DECLARE_TYPEINFO(StaticMorphBlendEntityData, 0x144533FA0);
_KB_DECLARE_TYPEINFO(StoredStaticMorphComponentData, 0x144534020);
_KB_DECLARE_TYPEINFO(StoredStaticMorphPreset, 0x144534220);
_KB_DECLARE_TYPEINFO(StoredStaticMorphBaseComponentData, 0x144533CA0);
_KB_DECLARE_TYPEINFO(StaticMorphGeneratorComponentData, 0x144533D20);
_KB_DECLARE_TYPEINFO(StaticMorphComponentData, 0x1445340A0);
_KB_DECLARE_TYPEINFO(ServerStaticMorphSaveGameStorageEntity, 0x1445342F0);
_KB_DECLARE_TYPEINFO(ClientStoredStaticMorphComponent, 0x144534120);
_KB_DECLARE_TYPEINFO(ClientStoredStaticMorphBaseComponent, 0x144534270);
_KB_DECLARE_TYPEINFO(ClientStaticMorphStorageEntity, 0x1445343C0);
_KB_DECLARE_TYPEINFO(ClientStaticMorphSaveGameStorageEntity, 0x144534490);
_KB_DECLARE_TYPEINFO(ClientStaticMorphGeneratorComponent, 0x144533DA0);
_KB_DECLARE_TYPEINFO(ClientStaticMorphComponent, 0x1445341A0);
_KB_DECLARE_TYPEINFO(ClientStaticMorphBlendEntity, 0x144534560);

#undef _KB_DECLARE_TYPEINFO
}
