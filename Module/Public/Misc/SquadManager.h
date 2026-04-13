// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#pragma once

#include <Core/EventManager.h>

#include <EASTL/unordered_map.h>
#include <EASTL/vector.h>

#include <cstdint>

namespace Kyber
{
class ServerPlayer;

typedef uint64_t GroupId;

class ServerSquadManager : EventListener
{
public:
    ServerSquadManager(EventManager* eventManager);
    ~ServerSquadManager() override = default;

    void OnEvent(const Event& event) override;
    void SetPlayerGroup(const ServerPlayer* player, GroupId groupId);
    void RemovePlayerFromGroup(const ServerPlayer* player, GroupId groupId);
    bool GroupHasPlayer(const ServerPlayer* player, const GroupId groupId);
    GroupId FindPlayerGroup(const ServerPlayer* player);
    void SendGroupUpdatedEvent(const ServerPlayer* player);
    eastl::vector<uint64_t> GetPlayersInGroup(GroupId groupId);

    static void InitializeHooks();

private:
    static void** ServerSquadEventSystemCtorHk(void* inst);
    
    static void* s_squadEventSystem;

    void RemovePlayerFromGroup(uint64_t playerId, GroupId groupId);

    // Map of group id to list of players in that group
    eastl::unordered_map<GroupId, eastl::vector<uint64_t>> m_activeGroups;
};

class ClientSquadManager : EventListener
{
public:
    ClientSquadManager(EventManager* clientEventManager);
    ~ClientSquadManager() override = default;

    virtual void OnEvent(const Event& event) override;

    static void InitializeHooks();

    eastl::vector<uint64_t> m_squadMates;
};
} // namespace Kyber