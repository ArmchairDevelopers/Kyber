// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#pragma once

#include <Core/EventManager.h>

#include <EASTL/unordered_map.h>
#include <EASTL/vector.h>

namespace Kyber
{
class ServerPlayer;

class ServerSquadManager : EventListener
{
public:
    using GroupId = uint64_t;
    using PlayerId = uint64_t;

    ServerSquadManager(EventManager* eventManager);
    ~ServerSquadManager() override = default;

    void OnEvent(const Event& event) override;
    void SetPlayerGroup(const ServerPlayer* player, GroupId groupId);
    void RemovePlayerFromGroup(const ServerPlayer* player, GroupId groupId);
    bool GroupHasPlayer(const ServerPlayer* player, const GroupId groupId);
    GroupId FindPlayerGroup(const ServerPlayer* player);
    void SendGroupUpdatedEvent(const ServerPlayer* player);
    eastl::vector<PlayerId> GetPlayersInGroup(GroupId groupId);

    static void InitializeHooks();

private:
    static void** ServerSquadEventSystemCtorHk(void* inst);

    static void* s_squadEventSystem;

    void RemovePlayerFromGroup(PlayerId playerId, GroupId groupId);

    // Map of group id to list of players in that group
    eastl::unordered_map<GroupId, eastl::vector<PlayerId>> m_activeGroups;
};
} // namespace Kyber