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
TL_DECLARE_FUNC(0x140A7B9D0, uint32_t, PersistentStorageTemplate_getCount, void* inst);
TL_DECLARE_FUNC(0x1467D3220, const char*, PersistentStorageTemplate_getName, void* inst, uint32_t offset);
TL_DECLARE_FUNC(0x1467D32D0, uint32_t, PersistentStorageTemplate_getOffset, void* inst, const char* name);
TL_DECLARE_FUNC(0x1483EFEB0, __int64, ReplicatePersistence, void* inst, ServerPlayer* player);

static const PlayerExtentRegistration* PersistentServerPlayerExtent_extentRegistration = (PlayerExtentRegistration*)0x143AB4900;

void LogPlayerStats(ConsoleContext& cc)
{
    KYBER_LOG(Info, "Player Manager: " << std::hex << g_program->m_server->m_playerManager);
    for (ServerPlayer* player : g_program->m_server->m_playerManager->m_players)
    {
        if (player)
        {
            KYBER_LOG(Info, "Offset: " << PersistentServerPlayerExtent_extentRegistration->offset);
            TypeObject* extent = (TypeObject*)((__int64)player + PersistentServerPlayerExtent_extentRegistration->offset);
            PersistentStorage* storage = *(PersistentStorage**)((__int64)extent + 0x198);
            KYBER_LOG(Info, "Offset: " << offsetof(PersistentStorage, m_template) << " " << std::hex << player << " " << extent << " "
                                       << (((__int64)player) + 10800));

            uint32_t offset = PersistentStorageTemplate_getOffset(storage->m_template, "c_cta__crax_ghva");

            PersistentStorage::Value& value = storage->m_values[offset];
            KYBER_LOG(Info, "Player: " << player->m_name << " " << value.current);
        }
    }
}

__int64 BitArrayCtorHk(__int64 inst)
{
    static const auto trampoline = HookManager::Call(BitArrayCtorHk);
    return trampoline(inst);
}

__int64 BitArrayInitHk(__int64 inst, uint32_t bitCount, MemoryArena* arena)
{
    static const auto trampoline = HookManager::Call(BitArrayInitHk);
    return trampoline(inst, bitCount, arena);
}

__int64 BitArrayDestroyHk(__int64 inst, MemoryArena* arena)
{
    static const auto trampoline = HookManager::Call(BitArrayDestroyHk);
    return trampoline(inst, arena);
}

__int64 ServerGamePlayerExtentSetUnlocksHk(__int64 a1, __int64 a2)
{
    static const auto trampoline = HookManager::Call(ServerGamePlayerExtentSetUnlocksHk);
    return trampoline(a1, a2);
}

void* ServerGamePlayerExtentInitUnlockArrayHk(__int64 inst, uint32_t bitCount)
{
    static const auto trampoline = HookManager::Call(ServerGamePlayerExtentInitUnlockArrayHk);
    return trampoline(inst, bitCount);
}

int32_t ServerPersistenceUnlocksGetBitIndexHk(__int64 inst, const Guid& guid)
{
    static const auto trampoline = HookManager::Call(ServerPersistenceUnlocksGetBitIndexHk);
    return trampoline(inst, guid);
}

void ServerPlayerSetUnlock(ServerPlayer* player, const Guid& guid, bool value)
{
    __int64 extent = (__int64)player->GetExtent("ServerGamePlayerExtent");

    ServerGamePlayerExtentInitUnlockArrayHk(extent, 1217);
    __int64 bitArray = (__int64)new __int64[6];
    BitArrayCtorHk(bitArray);
    BitArrayInitHk(bitArray, 1217, nullptr);
    memcpy(*reinterpret_cast<void**>(bitArray + 8), reinterpret_cast<void*>(extent + 0xE60),
        static_cast<size_t>(4) * *reinterpret_cast<unsigned int*>(bitArray + 0x18));

    uint32_t index = ServerPersistenceUnlocksGetBitIndexHk(*reinterpret_cast<__int64*>(0x143ED4480), guid);

    uint32_t* bits = *(uint32_t**)(bitArray + 8);
    uint32_t elementIndex = index / 32;
    uint32_t bitMask = 1U << (index % 32);
    bits[elementIndex] ^= (bits[elementIndex] ^ static_cast<uint32_t>(-static_cast<int>(value))) & bitMask;

    ServerGamePlayerExtentSetUnlocksHk(extent, bitArray);

    BitArrayDestroyHk(bitArray, nullptr);
    delete[] (__int64*)bitArray;
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

    __int64 extent = (__int64)player->GetExtent("ServerGamePlayerExtent");
    KYBER_LOG(Info, "[Persistence] Initialized unlock array 1 " << player->m_name << " " << std::hex << extent);
    //__int64 result = trampoline(a1, serverPlayer);

    ServerGamePlayerExtentInitUnlockArrayHk(extent, 1217);
    __int64 bitArray = (__int64)new __int64[6];
    BitArrayCtorHk(bitArray);
    BitArrayInitHk(bitArray, 1217, nullptr);
    memset(*(void**)(bitArray + 8), 0xFFFFFFFF, 4 * *(unsigned int*)(bitArray + 0x18));

    ServerGamePlayerExtentSetUnlocksHk(extent, bitArray);

    BitArrayDestroyHk(bitArray, nullptr);
    delete[] (__int64*)bitArray;
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

    TypeObject* extent = (TypeObject*)((__int64)player + PersistentServerPlayerExtent_extentRegistration->offset);
    PersistentStorage* storage = *(PersistentStorage**)((__int64)extent + 0x198);

    uint32_t count = PersistentStorageTemplate_getCount(storage->m_template);
    for (uint32_t i = 0; i < count; i++)
    {
        const char* name = PersistentStorageTemplate_getName(storage->m_template, i);
        uint32_t offset = PersistentStorageTemplate_getOffset(storage->m_template, name);
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
    TypeObject* extent = (TypeObject*)((__int64)player + PersistentServerPlayerExtent_extentRegistration->offset);
    PersistentStorage* storage = *(PersistentStorage**)((__int64)extent + 0x198);
    if (storage == nullptr)
    {
        return;
    }

    for (const auto& entry : stats)
    {
        uint32_t offset = PersistentStorageTemplate_getOffset(storage->m_template, entry.first.c_str());
        if (offset == 0xFFFFFFFF)
        {
            continue;
        }

        PersistentStorage::Value& value = storage->m_values[offset];
        value.current = entry.second;
    }

    ReplicatePersistence(inst, player);
}

void LoadPlayerDataCommand(ConsoleContext& cc)
{
    static const auto trampoline = HookManager::Call(LoadPlayerPersistenceHk);
    // trampoline(persistenceInst, g_program->m_server->m_playerManager->m_players[0]);
}

void SavePlayerDataCommand(ConsoleContext& cc)
{
    static const auto trampoline = HookManager::Call(LoadPlayerPersistenceHk);

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
        { HOOK_OFFSET(0x146872DF0), ServerGamePlayerExtentInitUnlockArrayHk },
        { HOOK_OFFSET(0x14545A710), BitArrayCtorHk },
        { HOOK_OFFSET(0x1454600C0), BitArrayInitHk },
        { HOOK_OFFSET(0x1401E71B0), BitArrayDestroyHk },
        { HOOK_OFFSET(0x146881840), ServerGamePlayerExtentSetUnlocksHk },
        { HOOK_OFFSET(0x1483EA700), ServerPersistenceUnlocksGetBitIndexHk },
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
        RegisterConsoleCommand(&LoadPlayerDataCommand, "LoadData");
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
