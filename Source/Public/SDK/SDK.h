// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <stddef.h>
#include <string>
#include <vector>

namespace Kyber
{
struct LevelSetup
{
    std::string name;
};

class ServerPlayerManager
{
public:
    char pad_0000[8];                  // 0x0000
    class PlayerData* m_playerData;    // 0x0008
    uint32_t m_maxPlayerCount;         // 0x0010
    uint32_t m_playerCountBitCount;    // 0x0014
    uint32_t m_playerIdBitCount;       // 0x0018
    char pad_001C[212];                // 0x001C
    class ServerPlayer* m_players[64]; // 0x00F0
    char pad_02F0[1276];               // 0x02F0
};                                     // Size: 0x07EC

class ServerPlayer
{
public:
    void* vfunc;                      // 0x0000
    class PlayerData* m_data;         // 0x0008
    class MemoryArena* m_memoryArena; // 0x0010
    char* m_name;                     // 0x0018
    char pad_0020[24];                // 0x0020
    bool m_isAIPlayer;                // 0x0038
    char pad_0039[31];                // 0x0039
    int32_t m_teamId;                 // 0x0058
    char pad_005C[496];               // 0x005C

}; // Size: 0x024C

class MemoryArena
{
public:
    char pad_0000[136]; // 0x0000
};                      // Size: 0x0088

struct ServerSpawnInfo
{
    ServerSpawnInfo(LevelSetup& setup)
        : levelSetup(setup)
    {}

    void* fileSystem = nullptr;
    void* damageArbitrator = nullptr;
    ServerPlayerManager* playerManager = nullptr;
    LevelSetup& levelSetup;
    unsigned int tickFrequency = 0;
    bool isSinglePlayer = false;
    bool isLocalHost = false;
    bool isDedicated = false;
    bool isEncrypted = false;
    bool isCoop = false;
    bool isMenu = false;
    bool keepResources = false;
    void* saveData;
    void* serverCallbacks = nullptr;
    void* runtimeModules = nullptr;
};

struct SocketSpawnInfo
{
    SocketSpawnInfo(bool isProxied, const char* proxyAddress, const char* serverName)
        : isProxied(isProxied)
        , proxyAddress(proxyAddress)
        , serverName(serverName)
    {}

    bool isProxied;
    const char* proxyAddress;
    const char* serverName;
    const char* serverMode;
    const char* serverLevel;
};
} // namespace Kyber