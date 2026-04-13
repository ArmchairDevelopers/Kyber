// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#include <Misc/SquadManager.h>

#include <Base/Log.h>
#include <SDK/SDK.h>
#include <Hook/HookManager.h>
#include <Core/Program.h>
#include <Utilities/MemoryUtils.h>
#include <Network/StreamManager.h>
#include <SDK/Fb/GameServer.h>
#include <SDK/Fb/WS.h>

#include <winuser.h>

namespace Kyber
{
void* ServerSquadManager::s_squadEventSystem = nullptr;

struct GameEventSquadChange
{
    uint8_t eventType;
    OnlineId onlineId;
    uint64_t groupId;
    uint64_t groupSize;
};

class KyberSetGroupMembersEvent : public KyberStreamedEvent
{
public:
    void Write(BitStreamWrite* stream) override
    {
        stream->WriteUnsignedLimit(m_groupMembers.size(), 0, 64);
        for (int i = 0; i < m_groupMembers.size(); i++)
        {
            stream->WriteUnsigned64(m_groupMembers[i], 64);
        }
    }

    void Read(BitStreamRead* stream) override
    {
        int32_t memberCount = stream->ReadUnsignedLimit(0, 64);
        m_groupMembers.reserve(memberCount);
        for (int i = 0; i < memberCount; i++)
        {
            m_groupMembers.push_back(stream->ReadUnsigned64(64));
        }
    }

    eastl::vector<uint64_t> m_groupMembers;
};

KB_REGISTER_STREAMED_EVENT(KyberSetGroupMembersEvent);

TL_DECLARE_FUNC(0x1418CF6E0, void, GroupManager_addEvent, void* inst, GameEventSquadChange& event);
TL_DECLARE_FUNC(0x148E354D0, void, ServerSquadManagerEntity_applyPlayerSquad, NativeEntity* inst, ServerPlayer* player);
TL_DECLARE_FUNC(0x141BC2380, void, ServerSquadManagerEntity_removePlayerFromSquad, NativeEntity* inst, ServerPlayer* player);

ServerSquadManager::ServerSquadManager(EventManager* eventManager) 
{
    eventManager->RegisterListener<ServerPlayerAuthenticatedEvent>(this);

    InitializeHooks();

    KYBER_LOG(Info, "[Server] Initializing Squad Manager");
}

void ServerSquadManager::OnEvent(const Event& event)
{
    if (event.is<ServerPlayerAuthenticatedEvent>())
    {
        KYBER_LOG(Info, "Got ServerPlayerAuthenticatedEvent");
        const auto& authenticatedEvent = event.as<ServerPlayerAuthenticatedEvent>();
        if (authenticatedEvent.groupId == 0)
        {
            return;
        }

        ServerPlayer* player = authenticatedEvent.connection->GetPlayer();
        if (player == nullptr)
        {
            return;
        }

        SetPlayerGroup(player, authenticatedEvent.groupId);
    }
    else if (event.is<ServerPlayerDisconnectedEvent>())
    {
        KYBER_LOG(Info, "Got ServerPlayerDisconnectedEvent");
        const auto& disconnectedEvent = event.as<ServerPlayerAuthenticatedEvent>();
        ServerPlayer* player = disconnectedEvent.connection->GetPlayer();
        if (player == nullptr)
        {
            return;
        }

        GroupId groupId = FindPlayerGroup(player);
        if (groupId != 0)
        {
            RemovePlayerFromGroup(player, groupId);
        }
    }
}

void ServerSquadManager::SetPlayerGroup(const ServerPlayer* player, GroupId groupId)
{
    if (s_squadEventSystem == nullptr)
    {
        KYBER_LOG(Warning, "error igher0pogjer");
        return;
    }

    GameEventSquadChange event;
    event.eventType = 4;
    event.groupId = groupId;
    event.groupSize = 4;
    event.onlineId = player->m_onlineId;

    GroupManager_addEvent(s_squadEventSystem, event);

    GroupId existingGroupId = FindPlayerGroup(player);
    if (existingGroupId != 0 && existingGroupId != groupId)
    {
        RemovePlayerFromGroup(player, existingGroupId);
        m_activeGroups[groupId].push_back(player->m_onlineId.m_nativeData);
    }

    // Send update to all players in group
    for (uint64_t playerId : m_activeGroups[groupId])
    {
        ServerPlayer* groupPlayer = g_program->m_server->m_playerManager->GetPlayer(playerId);
        if (groupPlayer == nullptr)
        {
            // TODO: remove them from list for not being an active player
            continue;
        }

        SendGroupUpdatedEvent(groupPlayer);
    }
};


void ServerSquadManager::RemovePlayerFromGroup(const ServerPlayer* player, GroupId groupId)
{
    RemovePlayerFromGroup(player->m_onlineId.m_nativeData, groupId);
}

// Function also handles removing empty groups along with removing them from specified group
void ServerSquadManager::RemovePlayerFromGroup(uint64_t playerId, GroupId groupId)
{
    auto& playerList = m_activeGroups[groupId];

    const auto& it = eastl::find(playerList.begin(), playerList.end(), playerId);
    if (it != playerList.end())
    {
        playerList.erase(it);
    }

    if (playerList.empty())
    {
        m_activeGroups.erase(groupId);
    }

    // Not gonna send a group update to other group mates for perf since
    // anything the client does with the list doesnt matter if the player isnt in the game 
}

bool ServerSquadManager::GroupHasPlayer(const ServerPlayer* player, const GroupId groupId)
{
    uint64_t searchValue = player->m_onlineId.m_nativeData;
    auto& playerList = m_activeGroups[groupId];
    for (uint64_t groupMateId : playerList)
    {
        if (groupMateId == searchValue)
        {
            return true;
        }
    }
    return false;
}

GroupId ServerSquadManager::FindPlayerGroup(const ServerPlayer* player)
{
    for (const auto& groupPlayerList : m_activeGroups)
    {
        for (uint64_t playerId : groupPlayerList.second)
        {
            if (player->m_onlineId.m_nativeData == playerId)
            {
                return groupPlayerList.first;
            }
        }
    }
    return 0;
}

void ServerSquadManager::SendGroupUpdatedEvent(const ServerPlayer* player)
{
    if (player == nullptr)
    {
        KYBER_LOG(Error, "Attempted to send group update event to invalid player");
        return;
    }

    GroupId groupId = FindPlayerGroup(player);
    if (!groupId)
    {
        // Not in a group
        return;
    }

    ServerConnection* connection = g_program->m_server->GetServerGameContext()->serverPeer->GetConnectionForPlayer(player);
    KyberSetGroupMembersEvent* groupAssignedEvent = FB_GLOBAL_ARENA->create<KyberSetGroupMembersEvent>();
    groupAssignedEvent->m_groupMembers = m_activeGroups[groupId];
    ServerStreamedEventManager::Send(connection, groupAssignedEvent);
}

eastl::vector<uint64_t> ServerSquadManager::GetPlayersInGroup(GroupId groupId)
{
    const auto& it = m_activeGroups.find(groupId);
    if (it != m_activeGroups.end())
    {
        return it->second;
    }
    return {};
}

void** ServerSquadManager::ServerSquadEventSystemCtorHk(void* inst)
{
    static const auto trampoline = HookManager::Call(ServerSquadEventSystemCtorHk);

    void** result = trampoline(inst);
    ServerSquadManager::s_squadEventSystem = *result;
    
    return result;
}

void ServerAutoTeamEntityEventHk(void* inst, ServerPlayerEvent* event)
{
    static const auto trampoline = HookManager::Call(ServerAutoTeamEntityEventHk);

    static const EventId event_PlayerEnter = StringUtils::HashQuick("PlayerEnter");
    if (event->eventId != event_PlayerEnter || !event->getType()->isKindOf(typeInfo_ServerPlayerEvent))
    {
        return trampoline(inst, event);
    }

    WSGameSettings* wsSettings = Settings<WSGameSettings>("Whiteshark");
    if (!wsSettings->AutoBalanceTeamsOnNeutral)
    {
        return trampoline(inst, event);
    }

    ServerPlayer* player = event->getPlayer();
    if (player == nullptr || player->IsAIPlayer())
    {
        return trampoline(inst, event);
    }

    KYBER_LOG(Debug, "Successfully got player from ServerPlayerEvent! " << player->m_name << " " << std::hex << player);

    ServerSquadManager* manager = g_program->m_server->m_squadManager;
    GroupId playerGroupId = manager->FindPlayerGroup(player);
    if (playerGroupId == 0)
    {
        return trampoline(inst, event);
    }

    bool successfullySetTeam = false;
    eastl::vector<uint64_t> playersInGroup = manager->GetPlayersInGroup(playerGroupId);
    for (uint64_t groupMateId : playersInGroup)
    {
        if (groupMateId == player->m_onlineId.m_nativeData)
        {
            continue;
        }

        // Successfully found a group member to change teams to
        ServerPlayer* groupMate = g_program->m_server->m_playerManager->GetPlayer(groupMateId);
        if (groupMate == nullptr)
        {
            continue;
        }

        player->SetTeam(groupMate->m_teamId);
        successfullySetTeam = true;
        KYBER_LOG(Debug, "Set " << player->m_name << "'s team to " << groupMate->m_name << "'s team of " << groupMate->m_teamId);
        break;
    }

    if (!successfullySetTeam)
    {
        trampoline(inst, event);
    }
}

void ServerSquadManager::InitializeHooks()
{
    HookManager::CreateHook(HOOK_OFFSET(0x1418C5960), ServerSquadEventSystemCtorHk);
    HookManager::CreateHook(HOOK_OFFSET(0x148A4F530), ServerAutoTeamEntityEventHk);

    // Disable blaze communication
    uint8_t zero = 0x00;
    MemoryUtils::Patch(HOOK_OFFSET(0x143FEB970), &zero, 1);

    // MemoryUtils::Nop(HOOK_OFFSET(0x148E355EC), 6); // disable check for if player is already in a squad
};

ClientSquadManager::ClientSquadManager(EventManager* clientEventManager)
{
    clientEventManager->RegisterListener<KyberSetGroupMembersEvent>(this);

    InitializeHooks();

    KYBER_LOG(Info, "[Client] Initializing Squad Manager");
}

void ClientSquadManager::OnEvent(const Event& event)
{
    if (event.is<KyberSetGroupMembersEvent>())
    {
        const auto& groupAssignedEvent = event.as<KyberSetGroupMembersEvent>();

        m_squadMates = groupAssignedEvent.m_groupMembers;
        KYBER_LOG(Info, "!!!!!!!!!!!!!!ClientSquadManager::OnEvent|KyberSetGroupMembersEvent pass");
    }
}

bool ClientSquadEntityPlayerInSquadCheckHk(void* inst, uint64_t* playerId)
{
    static const auto trampoline = HookManager::Call(ClientSquadEntityPlayerInSquadCheckHk);

    auto& squadMates = g_program->m_client->m_squadManager->m_squadMates;
    for (uint64_t squadMateId : squadMates)
    {
        if (squadMateId == *playerId)
        {
            return true;
        }
    }

    return trampoline(inst, playerId);
}

enum GameGroupStatus
{
    GameGroupStatus_None,      // 0x0000
    GameGroupStatus_Creating,  // 0x0001
    GameGroupStatus_Available, // 0x0002
    GameGroupStatus_Leaving    // 0x0003
};

struct ClientGameGroupStatusEntity : NativeEntity
{
    __int64 pad_00[3];
    PropertyWriter<GameGroupStatus> m_status;
};

struct UnkUpdaterItem
{
    ClientGameGroupStatusEntity* m_entity; // 0x00
    uint16_t m_tickCount;                  // 0x08
    uint16_t m_targetTicks;                // 0x0A
    float m_deltaTime;                     // 0x0C
}; // Size: 0x10

struct UnkUpdaterContainer
{
    char pad_00[0x28]; // 0x00
    eastl::vector<UnkUpdaterItem> m_updaterList; // 0x28
};

bool UnkClientGameGroupStatusEntityContainerUpdateHk(UnkUpdaterContainer* container, intptr_t a2)
{
    static const auto trampoline = HookManager::Call(UnkClientGameGroupStatusEntityContainerUpdateHk);

    bool outValue = trampoline(container, a2);
    if (g_program->m_client->m_squadManager->m_squadMates.size() > 0)
    {
        for (const UnkUpdaterItem& item : container->m_updaterList)
        {
            auto& entity = item.m_entity;
            
            // Checks from exe
            if (entity == nullptr || (entity->m_flags & 8) == 0)
            {
                continue;
            }

            // Specific entity check
            if (!entity->getType()->isKindOf(typeInfo_ClientGameGroupStatusEntity))
            {
                continue;
            }

            if (entity->m_status.HasConnectionValue())
            {
                GameGroupStatus value = GameGroupStatus_Available;
                entity->m_status = value;
            }
        }
    }

    return outValue;
}


void ClientSquadManager::InitializeHooks()
{
    HookManager::CreateHook(HOOK_OFFSET(0x148423170), ClientSquadEntityPlayerInSquadCheckHk);
    HookManager::CreateHook(HOOK_OFFSET(0x141D35320), UnkClientGameGroupStatusEntityContainerUpdateHk);
};
} // namespace Kyber