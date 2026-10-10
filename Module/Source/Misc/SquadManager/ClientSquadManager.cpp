// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#include <Misc/SquadManager/ClientSquadManager.h>

#include <Base/Log.h>
#include <SDK/SDK.h>
#include <Hook/HookManager.h>
#include <Core/Program.h>
#include <Utilities/MemoryUtils.h>
#include <Network/StreamManager.h>
#include <SDK/Fb/GameServer.h>
#include <SDK/Fb/WS.h>
#include <Misc/SquadManager/KyberSetGroupMembersEvent.h>

namespace Kyber
{
struct GameEventSquadChange
{
    uint8_t eventType;
    OnlineId onlineId;
    uint64_t groupId;
    uint64_t groupSize;
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
        KYBER_LOG(Debug, "Got KyberSetGroupMembersEvent");
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
    char pad_00[0x28];                           // 0x00
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