// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <cstddef>
#include <cstdint>
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
TL_DECLARE_FUNC(0x14BEC6FE0, void*, NetworkSettingsMessage_ctor, void* inst);
TL_DECLARE_FUNC(0x1483DBE40, void*, ServerPeerMaybe_updateSyncedGameSettings, void* null, void* serverConnection);
TL_DECLARE_FUNC(0x140BF7070, void*, ServerConnection_sendMessage, void* serverConnection, Message* message);
TL_DECLARE_FUNC(0x141BCE400, void, ServerPlayerExtent4_setActiveKit, ServerPlayerExtent* inst, uint32_t gpId, uint32_t unk0,
    uint32_t vurId, uint32_t skinInfoId);
TL_DECLARE_FUNC(0x141BCFC40, void, ServerPlayerExtent4_updateActiveKit, ServerPlayerExtent* inst, uint32_t gpId, void** selectionInfo, __int64 garbage);
TL_DECLARE_FUNC(0x14D8987B0, void, PlayerAbilityPickedUpMessage_ctor, PlayerAbilityPickedUpMessage* inst, LocalPlayerId localPlayerId);

TL_DECLARE_FUNC(0x14686C3A0, void, ServerPlayer_enableInput, ServerPlayer* m_player, int inputAction, bool enabled);

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

void ServerPlayerEnableInput(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    int inputAction;
    int enabled;
    stream >> playerName >> inputAction >> enabled;

    ServerPlayer* m_player = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    if (m_player == nullptr)
    {
        KYBER_LOG(Debug, "No Player Found");
        cc << "No Player Found";
        return;
    }
    ServerPlayer_enableInput(m_player, inputAction, enabled);
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

// this code is utterly horrific and has no need being such,
// it makes a SendStatProgressMessage that is 0x38 in size and then sets its vtable to whatever that is
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
        KYBER_LOG(Info, "Extent: " << std::hex << extent << " : " << extent->getType()->getName() 
            << " Offset: " << std::hex << extentRegistration[0] <<  " Size: " << std::hex << extentRegistration[1]);
        extentRegistration = *reinterpret_cast<uint32_t**>(reinterpret_cast<uintptr_t>(extentRegistration) + 0x38);
    }
}

void DebugServerPlayerManagerAddressCommand(ConsoleContext& cc)
{
    KYBER_LOG(Info, "Player Manager: " << std::hex << g_program->m_server->m_playerManager);
}

void TestSetPlayerActiveKit(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    int gp;
    int maxCount;
    int vurId;
    int skinInfo;
    stream >> playerName >> gp >> maxCount >> vurId >> skinInfo;

    ServerPlayer* serverPlayer = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    ServerPlayerExtent* extent = serverPlayer->GetExtent(ServerPlayerExtent4::s_registration);
    ServerPlayerExtent4_setActiveKit(extent, gp, maxCount, vurId, skinInfo);
    cc << "Done";
}

void TestUpdateActiveKit(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    uint32_t gp;
    stream >> playerName >> gp;

    ServerPlayer* serverPlayer = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    ServerPlayerExtent* extent = serverPlayer->GetServerPlayerExtent4();

    __int64 data1[6];
    __int64 data2[1];
    void* data1Ptr = &data1[1];
    void* data2Ptr = &data2[0];

    Asset* assets1[3];
    assets1[0] = reinterpret_cast<Asset*>(ResourceManagerLookupDataContainer("Gameplay/Equipment/Abilities/Ability_BattleCommand/SC_Trooper_37"));

    // ServerPlayerExtent4_updateActiveKit(extent, gp, (void**)0x142D6CDE0, (void**)0x142D6CDE0);
    ServerPlayerExtent4_updateActiveKit(extent, 1605240203, reinterpret_cast<void**>(&assets1), (__int64)0x142D6CDE0);
    cc << "Done";
}

void DebugUpdateSyncedGameSettings(ConsoleContext& cc)
{
    void* serverPeer = g_program->m_server->GetServerGameContext()->serverPeer;

    auto& playerList = g_program->m_server->GetServerGameContext()->serverPlayerManager->m_players;
    for (ServerPlayer* player : playerList)
    {
        if (player == nullptr || player->IsAIPlayer())
        {
            continue;
        }

        void* serverConnection = ServerPeer_connectionForPlayer(serverPeer, player);
        *reinterpret_cast<__int64*>((reinterpret_cast<__int64>(serverConnection)) + 0x5FAD) = 0; // idk
        void* out = ServerPeerMaybe_updateSyncedGameSettings(nullptr, serverConnection);
        
        // NetworkSettingsMessage message;
        // NetworkSettingsMessage_ctor(&message);
        // ServerConnection_sendMessage(serverConnection, reinterpret_cast<Message*>(&message));
        cc << "Forced update on " << player->m_name << " " << std::hex << out;
    }
}

TL_DECLARE_FUNC(0x146892CC0, void, ServerPeer_sendMessage, void* serverPeer, void* message);

void TestSetAbility(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    uint32_t abilityId;
    uint32_t slot;
    stream >> playerName >> abilityId >> slot;

    ServerPlayer* serverPlayer = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());

    PlayerAbilityPickedUpMessage* message = (PlayerAbilityPickedUpMessage*)FB_SERVER_ARENA->alloc(sizeof(PlayerAbilityPickedUpMessage));
    PlayerAbilityPickedUpMessage_ctor(message, serverPlayer->m_localPlayerId);

    message->playerId = serverPlayer->m_onlineId.m_nativeData;
    message->abilityId = abilityId;
    message->playerAbilityCategory = slot;

    ServerPeer_sendMessage(g_program->m_server->GetServerGameContext()->serverPeer, message);
    MessageManager_queueMessage(g_program->m_server->GetServerGameContext()->messageManager, reinterpret_cast<Message*>(message), 0.0f);

    cc << "Done";
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

// straight from ChatGPT. std::stof() can raise exceptions if given an invalid input and
// we really want to avoid that.
float StrToFloatOrDefault(std::string_view s, float default_value = 0.0f)
{
    float value;
    auto [ptr, ec] = std::from_chars(s.data(), s.data() + s.size(), value);

    // Must consume entire string and succeed
    if (ec != std::errc{} || ptr != s.data() + s.size())
        return default_value;

    return value;
}

void TeleportCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    std::string otherPlayerOrX;
    float y, z = 0.f;
    stream >> playerName >> otherPlayerOrX >> y >> z;

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

    LinearTransform transform;

    ServerPlayer* otherPlayer = g_program->m_server->GetServerGameContext()->serverPlayerManager->GetPlayer(otherPlayerOrX.c_str());
    if (otherPlayer != nullptr)
    {
        SpatialEntity* otherPlayerEntity;
        if ((otherPlayerEntity = (SpatialEntity*)otherPlayer->GetCharacterEntity()) ||
            (otherPlayerEntity = (SpatialEntity*)otherPlayer->GetVehicleEntity()))
        {
            otherPlayerEntity->GetTransform(transform);
            KYBER_LOG(Info, "Character entity debug: " << otherPlayerEntity->getType()->getName() << std::hex << otherPlayerEntity);
        }
    }
    else 
    {
        transform = LinearTransform(StrToFloatOrDefault(otherPlayerOrX), y, z);
    }

    bool success = player->Teleport(transform);
    if (!success)
    {
        cc << "Failed to teleport " << playerName << ", are they spawned in?";
        return;
    }

    cc << "Teleported " << playerName << " to " << transform.trans.x << "," << transform.trans.y << "," << transform.trans.z;
}

void SetBattlepointsCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    int amount;
    stream >> playerName >> amount;

    if (!g_program->m_server->IsRunning())
    {
        cc << "This is a server command, and you aren't running a server!";
        return;
    }

    ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    if (player == nullptr)
    {
        cc << "Couldn't find player " << playerName;
        return;
    }

    player->GetServerPlayerExtent4()->SetBattlepoints(amount);
    cc << "Set " << playerName << "'s battlepoints to " << amount;
}

void GiveBattlepointsCommand(ConsoleContext& cc)
{
    auto stream = cc.stream();
    std::string playerName;
    int amount;
    stream >> playerName >> amount;

    if (!g_program->m_server->IsRunning())
    {
        cc << "This is a server command, and you aren't running a server!";
        return;
    }

    ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayer(playerName.c_str());
    if (player == nullptr)
    {
        cc << "Couldn't find player " << playerName;
        return;
    }

    player->GetServerPlayerExtent4()->AddBattlepoints(amount);
    cc << "Gave " << playerName << " " << amount << " battlepoints, now has " << player->GetServerPlayerExtent4()->m_battlepoints << " total";
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

void HotReloadLuaCommand(ConsoleContext& cc)
{
    if (g_program->m_scriptManager == nullptr)
    {
        return;
    }

    auto stream = cc.stream();
    std::string realm;
    stream >> realm;

    PluginRealm pluginRealm;
    if (realm == "client")
    {
        pluginRealm = PluginRealm_Client;
    }
    else if (realm == "server")
    {
        pluginRealm = PluginRealm_Server;
    }
    else
    {
        cc << "Invalid realm. Options: client/server";
        return;
    }

    g_program->m_scriptManager->Reset();
    g_program->m_scriptManager->LoadScripts(pluginRealm);

    cc << "Hot reloaded scripts for realm [" << realm << "].";
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
    MemoryUtils::Patch(HOOK_OFFSET(0x141BCE55C), (void*)ptch, sizeof(ptch)); // ServerPlayerExtent4::setActiveKit

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
    RegisterConsoleCommand(&SetBattlepointsCommand, "SetBattlepoints", "<player> <amount>");
    RegisterConsoleCommand(&GiveBattlepointsCommand, "GiveBattlepoints", "<player> <amount>");
    RegisterConsoleCommand(&BroadcastCommand, "Broadcast", "<message>");
    RegisterConsoleCommand(&JoinServerCommand, "JoinServer", "<ip> <port>");
    RegisterConsoleCommand(&HotReloadLuaCommand, "HotReloadLua");
    RegisterConsoleCommand(&DebugUpdateSyncedGameSettings, "DebugSynced");
    RegisterConsoleCommand(&TestSetPlayerActiveKit, "TestSetActive", "<player> <gpId> <unknown> <vurId> <skinInfoId>");
    RegisterConsoleCommand(&TestUpdateActiveKit, "TestUpdateActive", "<player> <gpId>");
    RegisterConsoleCommand(&TestSetAbility, "TestSetAbility", "<player> <abilityId> <slot>");
    RegisterConsoleCommand(&ServerPlayerEnableInput, "EnableInput", "<player> <action> <enabled>");

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
