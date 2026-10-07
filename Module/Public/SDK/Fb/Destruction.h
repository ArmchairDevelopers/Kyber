namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ConnectivityEntityData, 0x1444B16F0);
_KB_DECLARE_TYPEINFO(BreakablePartToStaticEntityPart, 0x1444B1AF0);
_KB_DECLARE_TYPEINFO(StaticModelToBreakableParts, 0x1444B1B40);
_KB_DECLARE_TYPEINFO(DestructionVolumeComponentData, 0x1444B1770);
_KB_DECLARE_TYPEINFO(DestructionComponentOnHealthTransitionTriggeredMessage, 0x1444B1B90);
_KB_DECLARE_TYPEINFO(HealthTransitionSpawnReferenceObjectData, 0x1444B1520);
_KB_DECLARE_TYPEINFO(HealthTransitionData, 0x1444B17F0);
_KB_DECLARE_TYPEINFO(HealthTransitionPartData, 0x1444B1870);
_KB_DECLARE_TYPEINFO(PartRadiosityMaterialData, 0x1444B1BE0);
_KB_DECLARE_TYPEINFO(CalculateConnectedPartsPipelineResult, 0x1444B18F0);
_KB_DECLARE_TYPEINFO(CalculateConnectedPartsPipelineParams, 0x1444B1970);
_KB_DECLARE_TYPEINFO(TouchingPartPair, 0x1444B1C30);
_KB_DECLARE_TYPEINFO(ConnectionConstraint, 0x1444B15A0);
_KB_DECLARE_TYPEINFO(SelfSupportConstraint, 0x1444B1620);
_KB_DECLARE_TYPEINFO(SupportConstraint, 0x1444B19F0);
_KB_DECLARE_TYPEINFO(DestructionComponentData, 0x1444B1A70);
_KB_DECLARE_TYPEINFO(EdgeModelInfo, 0x1444B16A0);
_KB_DECLARE_TYPEINFO(ServerHealthTransitionPart, 0x1444B1C80);
_KB_DECLARE_TYPEINFO(HealthTransitionPart, 0x1444B1D50);
_KB_DECLARE_TYPEINFO(HealthTransition, 0x1444B1E20);
_KB_DECLARE_TYPEINFO(EdgeModelOwner, 0x1444B1FC0);
_KB_DECLARE_TYPEINFO(DestructionComponent, 0x1444B2040);
_KB_DECLARE_TYPEINFO(ClientHealthTransitionPart, 0x1444B1EF0);

#undef _KB_DECLARE_TYPEINFO
}
