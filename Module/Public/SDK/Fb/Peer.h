namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PeerServerBackendData, 0x144741AB0);
_KB_DECLARE_TYPEINFO(PresenceGetClientHostMigrationDataMessageBase, 0x144741BF0);
_KB_DECLARE_TYPEINFO(PresenceServerPeerNotificationMessageBase, 0x144741C40);
_KB_DECLARE_TYPEINFO(PresenceServerPeerRequestMessageBase, 0x144741C90);
_KB_DECLARE_TYPEINFO(PresencePeerGameRequestMessageBase, 0x144741CE0);
_KB_DECLARE_TYPEINFO(PresencePeerGameMessageBase, 0x144741D30);
_KB_DECLARE_TYPEINFO(PresenceHostMigrationRestoreFromSnapshotMessage, 0x144741D80);
_KB_DECLARE_TYPEINFO(PresenceHostMigrationStoreDataForCheckpointMessage, 0x144741DD0);
_KB_DECLARE_TYPEINFO(PresenceHostMigrationMessage, 0x144741A10);
_KB_DECLARE_TYPEINFO(PresenceHostMigrationClearCheckpointDataMessage, 0x144741E20);
_KB_DECLARE_TYPEINFO(PresenceHostMigrationCheckpointMessage, 0x144741E70);
_KB_DECLARE_TYPEINFO(HostMigrationMessageType, 0x144741BB0);
_KB_DECLARE_TYPEINFO(PeerCreateGameParameters, 0x144741A60);
_KB_DECLARE_TYPEINFO(PresencePeerServiceData, 0x144741B30);
_KB_DECLARE_TYPEINFO(PeerOnlineManager, 0x144741EC0);
_KB_DECLARE_TYPEINFO(ClientPeerService, 0x144741FC0);
_KB_DECLARE_TYPEINFO(ClientPeerGameManagementBackend, 0x144741F40);

#undef _KB_DECLARE_TYPEINFO
}
