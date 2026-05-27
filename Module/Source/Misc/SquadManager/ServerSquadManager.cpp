// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#include <Misc/SquadManager/ServerSquadManager.h>

#include <SDK/SDK.h>
#include <Hook/HookManager.h>
#include <Core/Program.h>
#include <Utilities/MemoryUtils.h>
#include <Network/StreamManager.h>
#include <Misc/SquadManager/KyberSetGroupMembersEvent.h>
#include <SDK/Fb/GameServer.h>

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
        KYBER_LOG(Debug, "[SquadManager] Got ServerPlayerAuthenticatedEvent");
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
        KYBER_LOG(Debug, "[SquadManager] Got ServerPlayerDisconnectedEvent");
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
        KYBER_LOG(Warning, "[SquadManager] SquadEventSystem uninitialized!");
        return;
    }

    if (groupId == 0)
    {
        return;
    }

    GameEventSquadChange event;
    event.eventType = 4;
    event.groupId = groupId;
    event.groupSize = 4;
    event.onlineId = player->m_onlineId;

    GroupManager_addEvent(s_squadEventSystem, event);

    GroupId existingGroupId = FindPlayerGroup(player);
    if (existingGroupId != groupId)
    {
        if (existingGroupId != 0)
        {
            RemovePlayerFromGroup(player, existingGroupId);
        }

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

ServerSquadManager::GroupId ServerSquadManager::FindPlayerGroup(const ServerPlayer* player)
{
    return FindPlayerGroup(player->m_onlineId.m_nativeData);
}

ServerSquadManager::GroupId ServerSquadManager::FindPlayerGroup(PlayerId playerId)
{
    for (const auto& groupPlayerList : m_activeGroups)
    {
        for (uint64_t groupPlayerId : groupPlayerList.second)
        {
            if (playerId == groupPlayerId)
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
        KYBER_LOG(Error, "[SquadManager] Attempted to send group update event to invalid player");
        return;
    }

    GroupId groupId = FindPlayerGroup(player);
    if (!groupId)
    {
        KYBER_LOG(Debug, "[SquadManager] Failed to send group update to someone who is not in a group: " << player->m_name);
        // Not in a group
        return;
    }

    KYBER_LOG(Debug, "[SquadManager] Sent group update to: " << player->m_name);

    ServerConnection* connection = g_program->m_server->GetServerGameContext()->serverPeer->GetConnectionForPlayer(player);
    KyberSetGroupMembersEvent* groupAssignedEvent = new (FB_GLOBAL_ARENA) KyberSetGroupMembersEvent();
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

    KYBER_LOG(Debug, "[SquadManager] Successfully got player from ServerPlayerEvent! " << player->m_name << " " << std::hex << player);

    ServerSquadManager* manager = g_program->m_server->m_squadManager;
    ServerSquadManager::GroupId playerGroupId = manager->FindPlayerGroup(player);
    KYBER_LOG(Debug, "[SquadManager] Player group id: " << playerGroupId);
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
        KYBER_LOG(Debug, "[SquadManager] Successfully got group mate (player id): " << groupMateId);

        // Successfully found a group member to change teams to
        ServerPlayer* groupMate = g_program->m_server->m_playerManager->GetPlayer(groupMateId);
        if (groupMate == nullptr)
        {
            continue;
        }
        KYBER_LOG(Debug, "[SquadManager] Successfully got group mate (player name): " << groupMate->m_name);

        if (groupMate->m_teamId == 0)
        {
            continue;
        }

        player->SetTeam(groupMate->m_teamId);
        successfullySetTeam = true;
        KYBER_LOG(Info, "[SquadManager] Set " << player->m_name << "'s team to " << groupMate->m_name << "'s team of " << groupMate->m_teamId);
        break;
    }

    if (!successfullySetTeam)
    {
        trampoline(inst, event);
    }
}

bool ServerInternalChatSystemCheckInSameGroup(void* inst, uint64_t playerA, uint64_t playerB)
{
    ServerSquadManager::GroupId playerAGroupId = g_program->m_server->m_squadManager->FindPlayerGroup(playerA);
    ServerSquadManager::GroupId playerBGroupId = g_program->m_server->m_squadManager->FindPlayerGroup(playerB);

    // If either of the player ids are 0, return false
    // If neither are 0, if they are both the same group id return true
    return !(playerAGroupId == 0 || playerBGroupId == 0) && playerAGroupId == playerBGroupId;
}

void ServerSquadManager::InitializeHooks()
{
    HookManager::CreateHook(HOOK_OFFSET(0x1418C5960), ServerSquadEventSystemCtorHk);
    HookManager::CreateHook(HOOK_OFFSET(0x148A4F530), ServerAutoTeamEntityEventHk);
    HookManager::CreateHook(HOOK_OFFSET(0x148EC1C70), ServerInternalChatSystemCheckInSameGroup);

    // Disable blaze communication
    uint8_t zero = 0x00;
    MemoryUtils::Patch(HOOK_OFFSET(0x143FEB970), &zero, 1);

    // MemoryUtils::Nop(HOOK_OFFSET(0x148E355EC), 6); // disable check for if player is already in a squad
};
} // namespace Kyber