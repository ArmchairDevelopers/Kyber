// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <SDK/SDK.h>

#include <Base/Log.h>
#include <SDK/Funcs.h>
#include <Utilities/PlatformUtils.h>
#include <Core/Program.h>

namespace Kyber
{
void** g_entityWorld = (void**)0x143FCB370;
GameWorld** g_gameWorld = (GameWorld**)0x143EEC298;
void** g_gameContext = (void**)0x143EFABD0;

PlayerExtentRegistration* ServerGamePlayerExtent::s_registration = reinterpret_cast<PlayerExtentRegistration*>(0x143A8C2A0);
PlayerExtentRegistration* ServerPlayerExtent4::s_registration = reinterpret_cast<PlayerExtentRegistration*>(0x143AB7470);
PlayerExtentRegistration* WSServerPlayerAbilityExtent::s_registration = reinterpret_cast<PlayerExtentRegistration*>(0x143AB5F50);
PlayerExtentRegistration* PersistenceServerPlayerExtent::s_registration = reinterpret_cast<PlayerExtentRegistration*>(0x143AB4900);
PlayerExtentRegistration* SoldierServerPlayerExtent::s_registration = reinterpret_cast<PlayerExtentRegistration*>(0x143AAD370);

TL_DECLARE_FUNC(0x140C45C30, __int64, ServerTeleportEntity_clearNewPosition, void* inst, void* character, void* vehicle,
    const LinearTransform& transform);

TL_DECLARE_FUNC(
    0x140AF1290, void, ClientCharacterEntity_onSetNetState, ClientSoldierEntity* inst, const CharacterEntityNetState& netState, __int64 a3);

TL_DECLARE_FUNC(0x148373280, void, WeaponFiring_setPrimaryAmmoMags, const WeaponFiring* inst, int mags);
TL_DECLARE_FUNC(0x146C500C0, void, IServerNetworkable_stateChanged, void* gameContext, uint16_t flags);

TL_DECLARE_FUNC(0x141128770, bool, SimpleEntityOwner_internalDestroyEntity, void* inst, NativeEntity* entity);
TL_DECLARE_FUNC(0x1470BC9B0, bool, SimpleEntityOwner_destroyOwnedEntities, void* inst, Realm realm);
TL_DECLARE_FUNC(0x1470BC620, void, SimpleEntityOwner_deinitOwnedEntities, void* inst, void* info);

typedef __int64(__fastcall* SpatialEntity_getTransform_t)(const void* inst, LinearTransform& transform);
typedef __int64(__fastcall* SpatialEntity_setTransform_t)(void* inst, const LinearTransform& transform);

TL_DECLARE_FUNC(0x14116F610, bool, Entity_init, NativeEntity* inst, EntityInitInfo* info);
TL_DECLARE_FUNC(0x1469DAF40, EntityInitInfo*, EntityInitInfo_ctor, EntityInitInfo* inst, Realm realm, void* context);

TL_DECLARE_FUNC(0x140814260, MemoryArena*, ArenaMap_findArenaForObject, void* object);

TL_DECLARE_FUNC(0x14114C290, void, FullEntityBus_internalFireEvent, EntityBus* inst, const DataContainer* data, EntityEvent* event);
TL_DECLARE_FUNC(
    0x141180770, void, EventAndPropertyModificationQueue_registerEvent, Realm realm, EntityBase* target, EntityEvent* entityEvent);

TL_DECLARE_FUNC(
    0x1471E1410, EntityBase*, EntityBus_convertDataToEntity, const EntityBus* inst, const DataContainer* data, bool allowNonRegisteredData);

static constexpr uint32_t __declspec(align(16)) g_emptyArray[8] = {};
void* ArrayBase::emptyArrayBegin()
{
    return (void*)&(g_emptyArray[4]);
}

TypeCodeEnum TypeInfo::getBasicType() const
{
    return TypeCodeEnum((typeInfoData->flags >> 5) & 31);
}

const char* TypeInfo::getName() const
{
    return typeInfoData->name;
}

void DataContainer::release()
{
    return;
    
    if (0 == InterlockedDecrement((volatile unsigned __int32*)&m_refCount))
    {
        this->~DataContainer();
        if (MemoryArena* arena = ArenaMap_findArenaForObject(this))
        {
            arena->free(this);
        }
    }
}

DataContainer* ResourceManagerLookupDataContainer(const char* name)
{
    for (int i = 0; i < ResourceCompartment_Count_; ++i)
    {
        DataContainer* container = ResourceManager_lookupDataContainer((ResourceCompartment)i, name);
        if (container != nullptr)
        {
            return container;
        }
    }

    return nullptr;
}

bool TypeInfo::isKindOf(const TypeInfo* other) const
{
    return ClassInfo_isKindOf(this, other);
}

void ServerPlayer::SendChatMessage(ChatChannel channel, const char* message) const
{
    Server_sendChatMessage(channel, message, this);
}

ServerCharacterEntity* ServerPlayer::GetCharacterEntity()
{
    return reinterpret_cast<ServerCharacterEntity*>(GetServerGamePlayerExtent()->GetCharacter());
}

ServerVehicleEntity* ServerPlayer::GetVehicleEntity()
{
    return reinterpret_cast<ServerVehicleEntity*>(GetServerGamePlayerExtent()->GetVehicle());
}

void ClientSoldierEntity::Teleport(const LinearTransform& transform)
{
    CharacterEntityNetState netState;
    netState.m_dirtyStates = 1;
    netState.m_transform = transform;
    ClientCharacterEntity_onSetNetState(reinterpret_cast<ClientSoldierEntity*>(reinterpret_cast<uintptr_t>(this) + 8), netState, 0);
}

bool ServerPlayer::Teleport(const LinearTransform& transform)
{
    if (GetServerGamePlayerExtent()->IsInVehicle())
    {
        if (ServerVehicleEntity* vehicle = GetVehicleEntity())
        {
            vehicle->Teleport(transform);
        }
    }
    else if (ServerCharacterEntity* character = GetCharacterEntity())
    {
        character->Teleport(transform);
    }
    else 
    {
        return false;
    }
    
    return true;
}

void ServerPlayer::ForceSendChatMessage(ChatChannel channel, const char* message)
{
    Server_sendChatMessage(channel, message, this);
}

void ServerVehicleEntity::Teleport(const LinearTransform& transform)
{
    GameComponentEntity_externalSetWorldTransform(this, transform, false);
}

void WSServerSoldierHealthComponent::SetMaxHealth(float value)
{
    intptr_t thisptr = reinterpret_cast<intptr_t>(this);
    m_displayMaxHealth = value;
    m_regenMaxHealth = value;
    m_calculatedMaxHealth = value;
    if (m_regenMaxHealth < m_health)
    {
        SetHealth(value);
    }
    SetStateChanged(1);
}

void SetNetStateDirty(uint32_t ghostFlags, uint32_t* fieldMask, uint32_t fieldIndex)
{
    uint16_t hiFlags = HIWORD(ghostFlags);
    if ((ghostFlags & 0x20000) != 0 || ((ghostFlags & 0x40000) != 0 && !*fieldMask))
    {
        IServerNetworkable_stateChanged(g_gameContext[hiFlags & 1], ghostFlags);
        KYBER_LOG(Info, "Sent state changed");
    }
    *fieldMask |= 1 << fieldIndex;
}

void WSServerSoldierHealthComponent::SetStateChanged(int index)
{
    uintptr_t thisptr = reinterpret_cast<uintptr_t>(this);
    SetNetStateDirty(*reinterpret_cast<uint32_t*>(thisptr + 0x560), reinterpret_cast<uint32_t*>(thisptr + 0x570), index);
}

void ServerGamePlayerExtent_SetJumpHeightMultiplier(void* extent, float multiplier)
{
    reinterpret_cast<float*>(extent)[0x1E4] = multiplier;
    if (reinterpret_cast<float*>(extent)[0x1E4] == reinterpret_cast<float*>(extent)[0x205])
    {
        reinterpret_cast<float*>(extent)[0x205] = multiplier;
    }
}

void WeaponFiring::SetPrimaryAmmoMags(int mags) const
{
    WeaponFiring_setPrimaryAmmoMags(this, mags);
}

ServerPlayer* ServerPlayerManager::GetPlayerOrSpectator(uint64_t id)
{
    ServerPlayer* player = GetPlayer(id);
    if (player != nullptr)
    {
        return player;
    }

    player = GetSpectator(id);
    if (player != nullptr)
    {
        return player;
    }

    return nullptr;
}

ServerPlayer* ServerPlayerManager::GetPlayerOrSpectator(const char* name)
{
    ServerPlayer* player = GetPlayer(name);
    if (player != nullptr)
    {
        return player;
    }

    player = GetSpectator(name);
    if (player != nullptr)
    {
        return player;
    }

    return nullptr;
}

ServerPlayer* ServerPlayerManager::GetPlayer(const char* name)
{
    for (const auto& player : m_players)
    {
        if (player->IsAIPlayer())
        {
            continue;
        }

        if (strcmp(player->m_name, name) != 0)
        {
            continue;
        }

        return player;
    }

    return nullptr;
}

ServerPlayer* ServerPlayerManager::GetSpectator(const char* name)
{
    for (const auto& player : m_spectators)
    {
        if (player->IsAIPlayer())
        {
            continue;
        }

        if (strcmp(player->m_name, name) != 0)
        {
            continue;
        }

        return player;
    }

    return nullptr;
}

ServerPlayer* ServerPlayerManager::GetPlayer(uint64_t id, bool includeAI)
{
    for (const auto& player : m_players)
    {
        if (!includeAI && player->IsAIPlayer())
        {
            continue;
        }

        if (player->m_onlineId.m_nativeData != id)
        {
            continue;
        }

        return player;
    }

    return nullptr;
}

ServerPlayer* ServerPlayerManager::GetSpectator(uint64_t id)
{
    for (const auto& player : m_spectators)
    {
        if (player->IsAIPlayer())
        {
            continue;
        }

        if (player->m_onlineId.m_nativeData != id)
        {
            continue;
        }

        return player;
    }

    return nullptr;
}

void ServerConnection::SafeDisconnect(const char* reasonText, SecureReason reason)
{
    m_disconnectReason = reason;
    m_shouldDisconnect = true;
    m_disconnectText = StringUtils::CopyWithArena(reasonText, FB_SERVER_ARENA);
}

void ServerConnection::SafeDisconnect(const char* reasonText)
{
    SafeDisconnect(reasonText, SecureReason_KickedViaFairFight);
}

bool EntityBase::IsSpatial() const
{
    return getType()->isKindOf(typeInfo_SpatialEntity);
}

bool EntityBase::IsComponent() const
{
    return getType()->isKindOf(typeInfo_ComponentEntity) || getType()->isKindOf(typeInfo_Component);
}

EntityBus* EntityBase::GetEntityBus() const
{
    if (IsSpatial())
    {
        return reinterpret_cast<const SpatialEntity*>(this)->m_entityBus;
    }

    return reinterpret_cast<const NativeEntity*>(this)->m_entityBus;
}

const GameObjectData* EntityBase::GetData() const
{
    if (IsSpatial())
    {
        return reinterpret_cast<const SpatialEntity*>(this)->m_data;
    }

    return reinterpret_cast<const NativeEntity*>(this)->m_data;
}

void EntityBase::FireEvent(EntityEvent* event)
{
    FullEntityBus_internalFireEvent(GetEntityBus(), GetData(), event);
}

void EntityBase::Event(EntityEvent* event)
{
    EventAndPropertyModificationQueue_registerEvent(GetRealm(), this, event);
}

void NativeEntity::Init()
{
    EntityInitInfo info;
    EntityInitInfo_ctor(&info, m_entityBus->GetRealm(), nullptr);
    Entity_init(this, &info);
}

void SpatialEntity::GetTransform(LinearTransform& transform) const
{
    auto func = reinterpret_cast<SpatialEntity_getTransform_t>(PlatformUtils::GetVTableFunction(this, 27));

    // Same reason as raycast vecs being heap allocated
    LinearTransform* trans = new LinearTransform();
    func(this, *trans);
    transform = *trans;
    delete trans;
}

void SpatialEntity::SetTransform(const LinearTransform& transform)
{
    auto func = reinterpret_cast<SpatialEntity_setTransform_t>(PlatformUtils::GetVTableFunction(this, 28));

    // See above
    LinearTransform* trans = new LinearTransform(transform);
    func(this, *trans);
    delete trans;
}

NativeEntity* EntityOwner::GetOwnedEntity(const DataContainer* entityData, EntityBus* bus)
{
    __int64 node = *reinterpret_cast<__int64*>(reinterpret_cast<__int64>(this) + 0x10);
    while (node)
    {
        NativeEntity* entity = reinterpret_cast<NativeEntity*>(node - 8);

        if (bus != nullptr && entity->GetEntityBus() != bus)
        {
            node = *reinterpret_cast<__int64*>(node + 8);
            continue;
        }

        if (entity->GetData() != entityData)
        {
            node = *reinterpret_cast<__int64*>(node + 8);
            continue;
        }

        return entity;
    }

    return nullptr;
}

eastl::vector<NativeEntity*> EntityOwner::GetOwnedEntities(EntityBus* bus)
{
    eastl::vector<NativeEntity*> entities;

    uintptr_t node = *reinterpret_cast<uintptr_t*>(reinterpret_cast<uintptr_t>(this) + 0x10);
    while (node)
    {
        NativeEntity* entity = reinterpret_cast<NativeEntity*>(node - 8);
        node = *reinterpret_cast<uintptr_t*>(node + 8);

        if (bus != nullptr && entity->GetEntityBus() != bus)
        {
            continue;
        }

        entities.push_back(entity);
    }

    return entities;
}

eastl::vector<NativeEntity*> EntityOwner::GetOwnedEntitiesRecursively()
{
    eastl::vector<NativeEntity*> entities;

    auto ownedEntities = GetOwnedEntities();
    entities.insert(entities.end(), ownedEntities.begin(), ownedEntities.end());

    if (m_firstChild != nullptr)
    {
        auto childEntities = m_firstChild->GetOwnedEntitiesRecursively();
        entities.insert(entities.end(), childEntities.begin(), childEntities.end());
    }

    if (m_nextSibling != nullptr)
    {
        auto siblingEntities = m_nextSibling->GetOwnedEntitiesRecursively();
        entities.insert(entities.end(), siblingEntities.begin(), siblingEntities.end());
    }

    return entities;
}

void EntityOwner::DestroyEntity(NativeEntity* entity)
{
    SimpleEntityOwner_internalDestroyEntity(this, entity);
}

void EntityOwner::DeinitOwnedEntities(void* info)
{
    SimpleEntityOwner_deinitOwnedEntities(this, info);
}

void EntityOwner::DestroyOwnedEntities(Realm realm)
{
    SimpleEntityOwner_destroyOwnedEntities(this, realm);
}

void EntityOwner::DestroyOwnedEntitiesRecursively(Realm realm)
{
    DestroyOwnedEntities(realm);

    if (m_firstChild != nullptr)
    {
        m_firstChild->DestroyOwnedEntitiesRecursively(realm);
    }

    if (m_nextSibling != nullptr)
    {
        m_nextSibling->DestroyOwnedEntitiesRecursively(realm);
    }
}

eastl::vector<EntityBus*> EntityBus::GetAllChildBusses() const
{
    eastl::vector<EntityBus*> busses;

    EntityBus* child = m_firstChild;
    while (child != nullptr)
    {
        busses.push_back(child);

        auto childBusses = child->GetAllChildBusses();
        busses.insert(busses.end(), childBusses.begin(), childBusses.end());

        child = child->m_nextSibling;
    }

    return busses;
}

EntityBase* EntityBus::GetExposedPeer() const
{
    if (uintptr_t entityBusBridge = GetEntityBusBridge())
    {
        uintptr_t addr = (entityBusBridge + 0x18) & ~uintptr_t(3);
        return reinterpret_cast<EntityBase*>(addr);
    }
    else if (DataContainer* exposed = GetExposedObject())
    {
        return EntityBus_convertDataToEntity(this, exposed, false);
    }

    return nullptr;
}

DataContainer* EntityBus::GetExposedPeerData() const
{
    if (uintptr_t entityBusBridge = GetEntityBusBridge())
    {
        return *reinterpret_cast<DataContainer**>(entityBusBridge + 0x10);
    }
    else if (DataContainer* exposed = GetExposedObject())
    {
        return exposed;
    }

    return nullptr;
}

EntityEvent::EntityEvent(const char* event)
    : eventId(StringUtils::HashHexCheck(event))
    , sender(Sender_Child)
{}

std::string ToString(Realm realm)
{
    switch (realm)
    {
    case Realm_Client:
        return "Client";
    case Realm_Server:
        return "Server";
    case Realm_ClientAndServer:
        return "ClientAndServer";
    case Realm_None:
        return "None";
    case Realm_Pipeline:
        return "Pipeline";
    case Realm_Count:
        break;
    }

    return "Unknown";
}
} // namespace Kyber
