// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <Core/Console.h>

#include <Hook/HookManager.h>
#include <Base/Log.h>
#include <Utilities/StringUtils.h>
#include <SDK/TypeInfo.h>
#include <Core/Program.h>
#include <Utilities/MemoryUtils.h>
#include <Utilities/PlatformUtils.h>
#include <SDK/Funcs.h>

#include <EASTL/fixed_map.h>

#include <iostream>

using namespace fastdelegate;

namespace Kyber
{
// https://stackoverflow.com/a/13842612
#define SINGLE_ARG(...) __VA_ARGS__

TL_DECLARE_FUNC(0x145478280, void*, AllocatingBuffer_writeEx, void* inst, const void* source, uint64_t size);
TL_DECLARE_FUNC(0x1401B4EB0, void, ConsoleRegistry_registerConsoleMethods, const char* groupName, ConsoleMethod* methods, int count);
TL_DECLARE_FUNC(0x1453ECF10, SINGLE_ARG(eastl::fixed_vector<InstanceMethod, 128>&), ConsoleRegistry_getInstanceMethods);

void ConsoleContext::pushOutput(const std::string& out)
{
    AllocatingBuffer_writeEx(this, out.c_str(), out.size());
}

void ConsoleRegistry_registerInstanceMethod(FastDelegate1<ConsoleContext&, void>& method, const char* name, const char* groupName)
{
    for (InstanceMethod& m : ConsoleRegistry_getInstanceMethods())
    {
        if (strcmp(m.name, name) == 0)
        {
            m.func = method;
            return;
        }
    }

    InstanceMethod& m = ConsoleRegistry_getInstanceMethods().push_back();
    m.description = "";
    m.func = method;
    m.groupName = StringUtils::CopyWithArena(groupName);
    m.name = StringUtils::CopyWithArena(name);
}

void RestartCommand(ConsoleContext& cc)
{
    Server_setCompleted();
}

void LoadLevelCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string level;
    std::string mode;
    stream >> level >> mode;

    g_program->m_server->LoadNextLevel(level.c_str(), mode.c_str());
}

void LoadSPLevelCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string level;
    std::string startPoint;
    std::string initialSubLevel;
    stream >> level >> startPoint >> initialSubLevel;

    g_program->m_server->LoadNextLevel(level.c_str(), "Campaign", startPoint.c_str(), initialSubLevel.c_str());
}

void LoadSPLevel2Command(ConsoleContext& cc)
{
    g_program->m_server->LoadNextLevel(
        "Levels/SP/RootLevel/RootLevel", "Campaign", "S0700_GP_CP02_Escape", "Levels/SP/A2/M2BES/DS02/A2_M2BES_DS02");
}

void AddLevelCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string level;
    std::string mode;
    stream >> level >> mode;

    g_program->m_server->m_mapRotation.AddEntry(level.c_str(), mode.c_str());
    KYBER_LOG(Info, "Added " << level << ":" << mode << " to the map rotation");
}

Message* SendStatProgressMessageCtorHk(void* inst, __int64 category, __int64 type, __int64 localPlayerId)
{
    static auto trampoline = HookManager::Call(SendStatProgressMessageCtorHk);
    return trampoline(inst, category, type, localPlayerId);
}

eastl::string ConsoleRegistryExecuteConsoleCommandHk(const char* cmdString, bool force)
{
    static auto trampoline = HookManager::Call(ConsoleRegistryExecuteConsoleCommandHk);

    if (strcmp(cmdString, "ingame|clear") == 0)
    {
        return "clear";
    }

    return trampoline(cmdString, force);
}

void SendStatsCommand(ConsoleContext& cc)
{
    KYBER_LOG(Info, "Dispatching message");
    void* messageManager = g_program->m_server->GetServerGameContext()->messageManager;
    __int64 test[7];
    SendStatProgressMessageCtorHk(test, 0x7C89B9B7, 0x933E652C, 0xFF);
    *test = (__int64)0x1431E06F0;
    MessageManagerDispatchMessageHk(messageManager, (Message*)test);
    KYBER_LOG(Info, "Dispatched message");
}

void ServerPlayerExtentDebugCommand(ConsoleContext& cc)
{
    ServerPlayer* player = g_program->m_server->m_playerManager->m_players[0];
    KYBER_LOG(Info, "----- Server Player Extents -----");

    // Magix forced me to comment what this means:
    // This magic offset is the first node of a linked list
    // of server player extents.

    uint32_t* extentRegistration = reinterpret_cast<uint32_t*>(0x143AB6FA0);
    while (extentRegistration)
    {
        TypeObject* extent = reinterpret_cast<TypeObject*>(reinterpret_cast<__int64>(player) + *extentRegistration);
        KYBER_LOG(Info, "Extent: " << std::hex << extent << " : " << extent->getType()->getName());
        extentRegistration = *reinterpret_cast<uint32_t**>(extentRegistration + 7);
    }
}

void DebugServerPlayerManagerAddressCommand(ConsoleContext& cc)
{
    KYBER_LOG(Info, "Player Manager: " << std::hex << g_program->m_server->m_playerManager);
}

void SaveLocationCommand(ConsoleContext& cc)
{
    // ClientSoldierEntity* entity = ClientGameContext::Get()->GetPlayerManager()->GetLocalPlayer()->controlledControllable;

    ClientSoldierEntity* entity = nullptr;
    if (entity == nullptr)
    {
        return;
    }

    Vec3 location = entity->clientSoldierPrediction->Location;
    KYBER_LOG(Info, "Player X: " << location.x << " Y: " << location.y << " Z: " << location.z);

    std::ofstream outfile;

    outfile.open("PlayerLocations.txt", std::ios_base::app | std::ios_base::app); // append instead of overwrite
    outfile << location.x << "," << location.y << "," << location.z;
    outfile << std::endl;
}

void CrashGameCommand(ConsoleContext& cc)
{
    int* ptr = nullptr;
    *ptr = 1;
}

void SetTeamCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    int team;
    stream >> playerName >> team;

    ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    if (player == nullptr)
    {
        cc << "Couldn't find player " << playerName;
        return;
    }

    player->SetTeam(team);
    cc << "Set " << playerName << " to team " << team;
}

void SetTeamByIndexCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    int index;
    int team;
    stream >> index >> team;

    auto& players = g_program->m_server->m_playerManager->m_players;
    if (players.size() <= index)
    {
        cc << "Player index out of bounds";
        return;
    }

    ServerPlayer* player = players[index];
    if (player == nullptr)
    {
        cc << "Couldn't find player at " << index;
        return;
    }

    player->SetTeam(team);
    cc << "Set " << player->m_name << " to team " << team;
}

void SetTeamByIdCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    uint64_t id;
    int team;
    stream >> id >> team;

    ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayer(id);
    if (player == nullptr)
    {
        cc << "Couldn't find player " << id;
        return;
    }

    player->SetTeam(team);
    cc << "Set " << player->m_name << " to team " << team;
}

void FullTeamSwapCommand(ConsoleContext& cc)
{
    auto& playerList = g_program->m_server->GetServerGameContext()->serverPlayerManager->m_players;
    for (ServerPlayer* player : playerList)
    {
        if (player == nullptr || player->IsAIPlayer())
        {
            continue;
        }
        player->SetTeam(player->m_teamId != 1 ? 1 : 2);
    }

    cc << "Successfully swapped both teams to the opposite side";
}

// This function is not extremely optimized, its meant to be readable
// Logic ported from PluginExamples/BotBalancer
void ShuffleTeamsCommand(ConsoleContext& cc)
{
    // Create new vector of purely real players
    eastl::vector<ServerPlayer*> players;
    players.reserve(64);

    auto& playerList = g_program->m_server->GetServerGameContext()->serverPlayerManager->m_players;
    for (ServerPlayer* player : playerList)
    {
        if (player == nullptr || player->IsAIPlayer())
        {
            continue;
        }
        players.push_back(player);
    }

    uint32_t playerCount = players.size();

    eastl::vector<int> randomTeamList(playerCount);
    for (int i = 0; i < playerCount - (playerCount / 2); i++)
    {
        randomTeamList[i] = 1;
    }

    for (int i = playerCount - (playerCount / 2); i < playerCount; i++)
    {
        randomTeamList[i] = 2;
    }

    // Randomize list with Fisher-Yates (https://en.wikipedia.org/wiki/Fisher%E2%80%93Yates_shuffle)
    for (int i = playerCount - 1; i >= 0; i--) 
    {
        int j = rand() % (i + 1);
        eastl::swap(randomTeamList[i], randomTeamList[j]);
    }

    for (int i = 0; i < playerCount; i++)
    {
        players[i]->SetTeam(randomTeamList[i]);
        KYBER_LOG(Debug, "Player " << players[i]->m_name << " set to team " << players[i]->m_teamId);
    }

    cc << "Successfully shuffled teams.";
}

void TeleportCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    float x, y, z;
    stream >> playerName >> x >> y >> z;

    if (!g_program->m_server->IsRunning())
    {
        cc << "This is a server command, and you aren't running a server!";
        return;
    }

    ServerPlayer* player = g_program->m_server->GetServerGameContext()->serverPlayerManager->GetPlayer(playerName.c_str());
    if (player == nullptr)
    {
        cc << "Couldn't find player " << playerName;
        return;
    }

    LinearTransform transform(x, y, z);
    bool success = player->Teleport(transform);
    if (!success)
    {
        cc << "Failed to teleport " << playerName << ", are they spawned in?";
        return;
    }

    cc << "Teleported " << playerName << " to " << x << "," << y << "," << z;
}

void BroadcastCommand(ConsoleContext& cc)
{
    if (!g_program->m_server->IsRunning())
    {
        cc << "This is a server command, and you aren't running a server!";
        return;
    }

    g_program->m_server->BroadcastMessage(cc.rawArguments, "ADMIN", ChatChannel_Admin);
}

void JoinServerCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string ip;
    uint16_t port;
    stream >> ip >> port;

    cc << "Connecting to " << ip << ":" << port << "...";
    g_program->JoinServer("", ip, port, "", false);
}

void FullEntityBusInternalFireEventHk2(void* inst, const DataContainer* data, const EntityEvent* entityEvent)
{
    static auto trampoline = HookManager::Call(FullEntityBusInternalFireEventHk2);
    if (data != nullptr && entityEvent != nullptr)
    {
        const Guid* guid = data->GetInstanceGuid();
        std::stringstream a;
        if (guid != nullptr)
        {
            a << " (exported: " << guid->ToString() << ")";
        }
        KYBER_LOG(Info, data->getType()->getName() << a.str() << " is calling event " << std::hex << entityEvent->eventId);
    }
    trampoline(inst, data, entityEvent);
}

void* EntityFactoryInternalCreateEntityHk(void* params, void* dc)
{
    static auto trampoline = HookManager::Call(EntityFactoryInternalCreateEntityHk);
    DataContainer* data = *(DataContainer**)((__int64)params + 0x110);
    const char* name = data->getType()->getName();

    if (g_program->m_entityManager != nullptr)
    {
        TypeObject* entityManagerEntity = g_program->m_entityManager->CreateEntity(params, data);
        if (entityManagerEntity != nullptr)
        {
            return entityManagerEntity;
        }
    }

    void* entity = trampoline(params, dc);

    if (entity != nullptr && g_program->m_entityManager != nullptr)
    {
        g_program->m_entityManager->OnEntityCreated(reinterpret_cast<NativeEntity*>(entity));
    }

    return entity;
}

void RegisterConsoleCommand(StaticConsoleMethodPtr_t func, const char* name, const char* description)
{
    ConsoleMethod* method = new ConsoleMethod{ func, name, 0, description };
    ConsoleRegistry_registerConsoleMethods("Kyber", method, 1);
}

Console::Console()
{
    KYBER_LOG(Info, "[Console] Initializing Console Commands");
    HookManager::CreateHook(HOOK_OFFSET(0x1474DA700), EntityFactoryInternalCreateEntityHk);
    //HookManager::CreateHook(HOOK_OFFSET(0x1473295D0), OnCreateHelperHk);
    //HookManager::CreateHook(HOOK_OFFSET(0x140196CF0), SendStatProgressMessageCtorHk);
    HookManager::CreateHook(HOOK_OFFSET(0x1401A8980), ConsoleRegistryExecuteConsoleCommandHk);
    Hook::ApplyQueuedActions();

    // MemoryUtils::Nop(HOOK_OFFSET(0x14543CFB2), 4);

    BYTE ptch[] = { 0xEB };
    MemoryUtils::Patch(HOOK_OFFSET(0x1401D0D03), (void*)ptch, sizeof(ptch));
    MemoryUtils::Patch(HOOK_OFFSET(0x1401D0D5B), (void*)ptch, sizeof(ptch));

    RegisterConsoleCommand(&RestartCommand, "Restart");
    RegisterConsoleCommand(&LoadLevelCommand, "LoadLevel", "<level> <mode>");
    RegisterConsoleCommand(&LoadSPLevelCommand, "LoadSPLevel", "<level> <startPoint> <initialSubLevel>");
    RegisterConsoleCommand(&LoadSPLevel2Command, "LoadSPLevel2");
    RegisterConsoleCommand(&AddLevelCommand, "AddLevel", "<level> <mode>");
    RegisterConsoleCommand(&SendStatsCommand, "SendStats");
    RegisterConsoleCommand(&ServerPlayerExtentDebugCommand, "ExtentDebug");
    RegisterConsoleCommand(&DebugServerPlayerManagerAddressCommand, "PlayerManagerAddr");
    RegisterConsoleCommand(&SaveLocationCommand, "SaveLocation");
    RegisterConsoleCommand(&CrashGameCommand, "CrashGame");
    RegisterConsoleCommand(&SetTeamCommand, "SetTeam", "<player> <team>");
    RegisterConsoleCommand(&SetTeamByIndexCommand, "SetTeamByIndex", "<playerIndex> <team>");
    RegisterConsoleCommand(&SetTeamByIdCommand, "SetTeamById", "<playerId> <team>");
    RegisterConsoleCommand(&FullTeamSwapCommand, "FullTeamSwap");
    RegisterConsoleCommand(&ShuffleTeamsCommand, "ShuffleTeams");
    RegisterConsoleCommand(&TeleportCommand, "Teleport", "<player> <x> <y> <z>");
    RegisterConsoleCommand(&BroadcastCommand, "Broadcast", "<message>");
    RegisterConsoleCommand(&JoinServerCommand, "JoinServer", "<ip> <port>");

    if (true || !g_program->m_isDedicatedServer)
    {
        return;
    }

    typedef FastDelegate<void(const char*, const char*, uint32_t)> HandlerDelegate_t;
    auto s_outputHandlers = (eastl::vector<HandlerDelegate_t>*)0x143A5B1C0;

    auto delegate = HandlerDelegate_t([](const char* tag, const char* line, uint32_t size) { std::cout << line; });
    s_outputHandlers->push_back(delegate);
}

void Console::UnregisterCommand(const char* name)
{
    eastl::fixed_vector<InstanceMethod, 128>& methods = ConsoleRegistry_getInstanceMethods();
    for (eastl::fixed_vector<InstanceMethod, 128>::iterator it = methods.begin(); it != methods.end();)
    {
        if (strcmp(name, it->name) != 0)
        {
            ++it;
            continue;
        }

        it = methods.erase(it);
        return;
    }
}

void Console::EnqueueCommand(const char* cmd)
{
    auto delegate = fastdelegate::FastDelegate<void(const char*)>([](const char* result) {
        if (strlen(result) == 0)
        {
            return;
        }

        KYBER_LOG(Info, "[Console] " << result);
    });

    KYBER_LOG(Info, "[Console] > " << cmd);
    Console_enqueueCommand(cmd, delegate);
}
} // namespace Kyber
