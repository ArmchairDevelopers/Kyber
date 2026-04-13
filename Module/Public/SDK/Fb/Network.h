namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ClientSyncedTransformEntity, 0x144537020);
_KB_DECLARE_TYPEINFO(ServerSyncedTransformEntity, 0x1445370F0);
_KB_DECLARE_TYPEINFO(ClientSyncedIntEntity, 0x1445371C0);
_KB_DECLARE_TYPEINFO(ServerSyncedIntEntity, 0x144537290);
_KB_DECLARE_TYPEINFO(ClientSyncedFloatEntity, 0x144537360);
_KB_DECLARE_TYPEINFO(ServerSyncedFloatEntity, 0x144537430);
_KB_DECLARE_TYPEINFO(ClientSyncedBoolEntity, 0x144537500);
_KB_DECLARE_TYPEINFO(ServerSyncedBoolEntity, 0x1445375D0);
_KB_DECLARE_TYPEINFO(EngineConnectionPeer, 0x144536960);
_KB_DECLARE_TYPEINFO(EngineConnection, 0x1445369E0);
_KB_DECLARE_TYPEINFO(SpikeInternalMessagePartMessage, 0x144536750);
_KB_DECLARE_TYPEINFO(SpikeInternalMessageWrapperMessage, 0x1445367A0);
_KB_DECLARE_TYPEINFO(NetworkPerfOverlaySettings, 0x144536130);
_KB_DECLARE_TYPEINFO(InterpolationManagerSettings, 0x1445361B0);
_KB_DECLARE_TYPEINFO(InternetSimulationState, 0x1445365F0);
_KB_DECLARE_TYPEINFO(NetworkCoreSettings, 0x144536230);
_KB_DECLARE_TYPEINFO(CoreDemoStatusMessage, 0x144536640);
_KB_DECLARE_TYPEINFO(NetObjectSystemSettings, 0x1445362B0);
_KB_DECLARE_TYPEINFO(NetObjectSystemDebugSettings, 0x144536040);
_KB_DECLARE_TYPEINFO(DeltaCompressionSettings, 0x144536090);
_KB_DECLARE_TYPEINFO(NetObjectDependencyType, 0x144536530);
_KB_DECLARE_TYPEINFO(NetObjectPrioritySettings, 0x1445360E0);
_KB_DECLARE_TYPEINFO(NetObjectSendStatus, 0x144536570);
_KB_DECLARE_TYPEINFO(NetworkChannelId, 0x1445365B0);
_KB_DECLARE_TYPEINFO(SyncedTransformEntityData, 0x144536330);
_KB_DECLARE_TYPEINFO(SyncedIntEntityData, 0x1445363B0);
_KB_DECLARE_TYPEINFO(SyncedFloatEntityData, 0x144536430);
_KB_DECLARE_TYPEINFO(SyncedBoolEntityData, 0x1445364B0);

#undef _KB_DECLARE_TYPEINFO
}
