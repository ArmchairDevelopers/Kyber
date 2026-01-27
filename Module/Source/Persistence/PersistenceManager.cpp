// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Persistence/PersistenceManager.h>

#include <Core/Program.h>
#include <Base/Log.h>
#include <Hook/HookManager.h>
#include <Core/Memory.h>
#include <Core/Console.h>
#include <Utilities/MemoryUtils.h>
#include <SDK/SDK.h>

#include <ToolLib/Func.h>

namespace Kyber
{
TL_DECLARE_FUNC(0x1483EFEB0, __int64, ReplicatePersistence, void* inst, ServerPlayer* player);
TL_DECLARE_FUNC(0x1483EA700, int32_t, ServerPersistenceUnlocksGetBitIndex, intptr_t inst, const Guid& guid);

static const PlayerExtentRegistration* PersistentServerPlayerExtent_extentRegistration = (PlayerExtentRegistration*)0x143AB4900;

void LogPlayerStats(ConsoleContext& cc)
{
    KYBER_LOG(Info, "Player Manager: " << std::hex << g_program->m_server->m_playerManager);
    for (ServerPlayer* player : g_program->m_server->m_playerManager->m_players)
    {
        if (player != nullptr)
        {
            KYBER_LOG(Info, "Offset: " << PersistenceServerPlayerExtent::s_registration->offset);
            PersistenceServerPlayerExtent* extent = player->GetPersistenceServerPlayerExtent();
            PersistentStorage* storage = static_cast<PersistentStorage*>(extent->m_persistentStorage);
            KYBER_LOG(Info, "Offset: " << offsetof(PersistentStorage, m_template) << " " << std::hex << player << " " << extent << " "
                                       << (((__int64)player) + 10800)); // no i do not know what +10800 is for

            uint32_t offset = storage->m_template->GetOffset("c_cta__crax_ghva");

            PersistentStorage::Value& value = storage->m_values[offset];
            KYBER_LOG(Info, "Player: " << player->m_name << " " << value.current);
        }
    }
}
void ServerPlayerSetUnlock(ServerPlayer* player, const Guid& guid, bool value)
{
    ServerGamePlayerExtent* extent = player->GetServerGamePlayerExtent();

    extent->InitUnlockArray(1217);
    FbBitArray* bitArray = reinterpret_cast<FbBitArray*>(FB_SERVER_ARENA->alloc(sizeof(FbBitArray)));
    bitArray->Ctor();
    bitArray->Init(1217, nullptr);
    memcpy(bitArray->m_bits, reinterpret_cast<void*>(extent + 0xE60), 4 * bitArray->m_size);

    uint32_t index = ServerPersistenceUnlocksGetBitIndex(*reinterpret_cast<__int64*>(0x143ED4480), guid);

    uint32_t* bits = bitArray->m_bits;
    uint32_t elementIndex = index / 32;
    uint32_t bitMask = 1U << (index % 32);
    bits[elementIndex] ^= (bits[elementIndex] ^ static_cast<uint32_t>(-static_cast<int>(value))) & bitMask;

    extent->SetUnlocks(bitArray);

    bitArray->Destroy(nullptr);
    FB_SERVER_ARENA->free(bitArray);
}

__int64 InitUnlockArrayHk(__int64 a1, ServerPlayer* player)
{
    static const auto trampoline = HookManager::Call(InitUnlockArrayHk);
    if (!g_program->m_server->IsRunning() || player->IsAIPlayer())
    {
        return trampoline(a1, player);
    }

    // Uncomment to disable everything being unlocked
    // return trampoline(a1, player);

    ServerGamePlayerExtent* extent = player->GetServerGamePlayerExtent();
    KYBER_LOG(Debug, "[Persistence] Initialized unlock array " << player->m_name << " " << std::hex << extent);
    //__int64 result = trampoline(a1, serverPlayer);

    extent->InitUnlockArray(1217);
    
    FbBitArray* bitArray = reinterpret_cast<FbBitArray*>(FB_SERVER_ARENA->alloc(sizeof(FbBitArray)));
    bitArray->Ctor();
    bitArray->Init(1217, nullptr);
    memset(bitArray->m_bits, 0xFFFFFFFF, 4 * bitArray->m_size);

    extent->SetUnlocks(bitArray);

    bitArray->Destroy(nullptr);
    FB_SERVER_ARENA->free(bitArray);
    // return result;
    return 0;
}

void LoadPlayerPersistenceHk(void* inst, ServerPlayer* player)
{
    static const auto trampoline = HookManager::Call(LoadPlayerPersistenceHk);
    trampoline(inst, player);

    if (!g_program->m_server->IsRunning() || player->IsAIPlayer() || player->IsSpectator() || !g_program->m_isDedicatedServer)
    {
        return;
    }

    KYBER_LOG(Info, "[Persistence] Loading persistence for player " << player->m_onlineId.m_nativeData << " " << std::hex << player);
    g_program->m_server->m_persistenceManager->LoadPlayerStats(inst, player);
}

PlayerStatsMap ExtractPlayerStats(ServerPlayer* player)
{
    PlayerStatsMap stats;
    if (player->IsAIPlayer() || player->IsSpectator())
    {
        return stats;
    }

    PersistenceServerPlayerExtent* extent = player->GetPersistenceServerPlayerExtent();
    PersistentStorage* storage = static_cast<PersistentStorage*>(extent->m_persistentStorage);

    uint32_t count = storage->m_template->GetCount();
    for (uint32_t i = 0; i < count; i++)
    {
        const char* name = storage->m_template->GetName(i);
        uint32_t offset = storage->m_template->GetOffset(name);
        PersistentStorage::Value& value = storage->m_values[offset];
        if (!(fabsf(value.current - value.reference) > 0.000001))
        {
            continue;
        }

        stats[name] = value.current;
    }

    return stats;
}

void ApplyPlayerStats(void* inst, ServerPlayer* player, const PlayerStatsMap& stats)
{
    PersistenceServerPlayerExtent* extent = player->GetPersistenceServerPlayerExtent();
    PersistentStorage* storage = static_cast<PersistentStorage*>(extent->m_persistentStorage);
    if (storage == nullptr)
    {
        return;
    }

    for (const auto& entry : stats)
    {
        uint32_t offset = storage->m_template->GetOffset(entry.first.c_str());
        if (offset == 0xFFFFFFFF)
        {
            continue;
        }

        PersistentStorage::Value& value = storage->m_values[offset];
        value.current = entry.second;
    }

    ReplicatePersistence(inst, player);
}

void SavePlayerDataCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    stream >> playerName;

    ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    if (player == nullptr)
    {
        KYBER_LOG(Error, "Couldn't find player " << playerName);
        return;
    }

    PlayerStatsMap stats = ExtractPlayerStats(player);
    KYBER_LOG(Info, "Stats: " << stats.size());

    g_program->m_server->m_persistenceManager->SavePlayerStats(player, stats);
}

void SetUnlockCommand(ConsoleContext& cc, bool grant)
{
    auto stream = cc.stream();
    std::string playerName;
    std::string assetGuid;
    stream >> playerName >> assetGuid;

    ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    if (player == nullptr)
    {
        KYBER_LOG(Info, "[Persistence] Couldn't find player '" << playerName.c_str() << "'");
        return;
    }

    Guid guid = Guid::FromString(assetGuid);
    ServerPlayerSetUnlock(player, guid, grant);
}

void GrantUnlockCommand(ConsoleContext& cc)
{
    SetUnlockCommand(cc, true);
}

void RevokeUnlockCommand(ConsoleContext& cc)
{
    SetUnlockCommand(cc, false);
}

PersistenceManager::PersistenceManager()
{
    // API db is hardcoded for now, may add more in the future
    m_database = new APIPersistenceDatabase(kyber_api::StatsSource::KYBER);
}

void PersistenceManager::LoadPlayerStats(void* persistenceInst, ServerPlayer* player)
{
    m_database->Load(player->m_onlineId, [persistenceInst, player](PlayerStatsMap stats) {
        KYBER_LOG(Info, "[Persistence] Persistence loaded, applying...");
        ApplyPlayerStats(persistenceInst, player, stats);
    });
}

void PersistenceManager::SavePlayerStats(ServerPlayer* player)
{
    if (player->IsAIPlayer() || player->IsSpectator())
    {
        return;
    }

    SavePlayerStats(player, ExtractPlayerStats(player));
}

void PersistenceManager::SavePlayerStats(ServerPlayer* player, const PlayerStatsMap& stats)
{
    m_database->Save(player->m_onlineId, stats);
}

void PersistenceManager::Initialize()
{
    HookTemplate hookOffsets[] = {
        { HOOK_OFFSET(0x1418A81A0), InitUnlockArrayHk },
        { HOOK_OFFSET(0x1483F0160), LoadPlayerPersistenceHk },
    };

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }

    Hook::ApplyQueuedActions();

    g_program->m_consoleRegistrationCallbacks.push_back([&]() {
        RegisterConsoleCommand(&LogPlayerStats, "LogPlayerStats");
        RegisterConsoleCommand(&GrantUnlockCommand, "GrantUnlock", "<player> <guid>");
        RegisterConsoleCommand(&RevokeUnlockCommand, "RevokeUnlock", "<player> <guid>");
        RegisterConsoleCommand(&SavePlayerDataCommand, "SaveData");
    });

    // Enable stats system
    if (g_program->m_isDedicatedServer)
    {
        BYTE ptch[] = { 0x74 };
        MemoryUtils::Patch(HOOK_OFFSET(0x1418B6ECC), (void*)ptch, sizeof(ptch));
    }

    BYTE ptch2[] = { 0x0F, 0x85 };
    MemoryUtils::Patch(HOOK_OFFSET(0x1418B6ED5), (void*)ptch2, sizeof(ptch2));
}
} // namespace Kyber
