namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(SetVariableTypeInfoAsset, 0x1445D1780);
_KB_DECLARE_TYPEINFO(GetVariableTypeInfoAsset, 0x1445D1800);
_KB_DECLARE_TYPEINFO(SchematicsUpdatePassAsset, 0x1445D1880);
_KB_DECLARE_TYPEINFO(SchematicsBasePatchData, 0x1445D1900);
_KB_DECLARE_TYPEINFO(SchematicsBaseAsset, 0x1445D1980);
_KB_DECLARE_TYPEINFO(SchematicsPatchData, 0x1445D1A00);
_KB_DECLARE_TYPEINFO(SchematicsObserverPatch, 0x1445D1B00);
_KB_DECLARE_TYPEINFO(SchematicsNestedPatch, 0x1445D1B50);
_KB_DECLARE_TYPEINFO(SchematicsParameterPatch, 0x1445D1BA0);
_KB_DECLARE_TYPEINFO(SchematicsFieldPatch, 0x1445D1BF0);
_KB_DECLARE_TYPEINFO(ConstField, 0x1445D1C40);
_KB_DECLARE_TYPEINFO(AutoCreatedDispatcher, 0x1445D1C90);
_KB_DECLARE_TYPEINFO(AutoCreatedField, 0x1445D1CE0);
_KB_DECLARE_TYPEINFO(EventObserverEntry, 0x1445D1D30);
_KB_DECLARE_TYPEINFO(SchematicsAsset, 0x1445D1A80);
_KB_DECLARE_TYPEINFO(SchematicsInstance, 0x1445D1F00);
_KB_DECLARE_TYPEINFO(SchematicsEventDispatcher, 0x1445D1D80);
_KB_DECLARE_TYPEINFO(SchematicsContext, 0x1445D1E00);
_KB_DECLARE_TYPEINFO(SchematicsPipelineBuilder, 0x1445D1E80);

#undef _KB_DECLARE_TYPEINFO
}
