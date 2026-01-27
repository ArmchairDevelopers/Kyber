// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Core/Server.h>

#include <Core/Program.h>
#include <Hook/HookManager.h>
#include <Base/Log.h>
#include <Utilities/MemoryUtils.h>
#include <SDK/TypeInfo.h>
#include <SDK/SDK.h>
#include <SDK/Funcs.h>
#include <Utilities/PlatformUtils.h>
#include <Utilities/StringUtils.h>
#include <Entity/KyberSettings.h>

#include <ws2tcpip.h>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <cstdio>
#include <thread>
#include <cstring>

#define OFFSET_SERVER_CONSTRUCTOR HOOK_OFFSET(0x140BC6370)
#define OFFSET_SERVER_START HOOK_OFFSET(0x140BD17E0)
#define OFFSET_SERVER_UPDATEPASSPREFRAME HOOK_OFFSET(0x146860470)
#define OFFSET_SERVERLEVEL_UPDATELOAD HOOK_OFFSET(0x140BD3360)

#define OFFSET_SERVERPLAYER_SETTEAMID HOOK_OFFSET(0x140BE9C10)
#define OFFSET_SERVERPLAYER_LEAVEINGAME HOOK_OFFSET(0x146876310)
#define OFFSET_SERVERPLAYER_DISCONNECT HOOK_OFFSET(0x140BDDBE0)

#define OFFSET_SERVERPEER_DELETECONNECTION HOOK_OFFSET(0x146C3A900)

#define OFFSET_SERVERCONNECTION_DISCONNECT HOOK_OFFSET(0x140BF01D0)
#define OFFSET_SERVERCONNECTION_KICKPLAYER HOOK_OFFSET(0x14688DB50)
#define OFFSET_SERVERCONNECTION_ONCREATEPLAYERMESSAGE HOOK_OFFSET(0x140BF33B0)

#define OFFSET_SERVERPLAYERMANAGER_DELETEPLAYER HOOK_OFFSET(0x140BDD950)

#define OFFSET_APPLY_SETTINGS HOOK_OFFSET(0x1401B31B0)

#define OFFSET_CLIENT_INIT_NETWORK HOOK_OFFSET(0x140A8DE80)
#define OFFSET_CLIENT_CONNECTTOADDRESS HOOK_OFFSET(0x140CB3990)

#define OFFSET_MAINLOOP_INIT HOOK_OFFSET(0x140186B90)
#define OFFSET_MAINLOOP_INITDATAPLATFORM HOOK_OFFSET(0x145315E30)

#define OFFSET_GAMESIMULATION_INIT HOOK_OFFSET(0x145315930)
#define OFFSET_GAMESIMULATION_SPAWNSERVER HOOK_OFFSET(0x14018EE70)

#define OFFSET_SERVER_PATCH 0x140A92F71

namespace Kyber
{
static bool IsOnlineMode()
{
    const char* onlineMode = std::getenv("KYBER_ONLINE_MODE");
    if (onlineMode != nullptr)
    {
        return std::string(onlineMode) == "1";
    }

    return true;
}

void ServerLoadLevelMessagePostHk(LevelSetup* levelSetup, bool fadeOut, bool forceReloadResources)
{
    static const auto trampoline = HookManager::Call(ServerLoadLevelMessagePostHk);

    std::string initialStartPoint = levelSetup->InitialStartPoint ? levelSetup->InitialStartPoint : "";
    std::string initialSubLevel = levelSetup->InitialDSubLevel ? levelSetup->InitialDSubLevel : "";

    if (g_program->m_server != nullptr)
    {
        if (!g_program->m_server->m_levelLoaded)
        {
            MutexGuard<LoadLevelRequest> requestGuard = g_program->m_server->m_latestLoadLevelRequest.Lock();

            requestGuard->level = levelSetup->Name;
            requestGuard->mode = levelSetup->GetInclusionOption("GameMode");

            KYBER_LOG(Debug, "[Server] Put level setup in queue: " << requestGuard->level << " " << requestGuard->mode);
            return;
        }

        g_program->m_server->m_levelLoaded = false;
    }

    KYBER_LOG(Info, "[Server] Loading level " << levelSetup->Name << " [InitialStartPoint: " << initialStartPoint << ", InitialDSubLevel: "
                                              << initialSubLevel << ", LevelSetup: " << std::hex << levelSetup << "]");

    trampoline(levelSetup, fadeOut, forceReloadResources);
}

void InitLevelSetup(LevelSetup* levelSetup, const char* level, const char* mode, const char* startPoint, const char* initialSubLevel)
{
    KYBER_LOG(Info, "[Server] Loading level '" << level << "'"
                                               << " with mode '" << (mode != nullptr ? mode : "none") << "'");

    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->GetEventManager().Fire("Level:Loaded", level, mode);
    }

    g_program->m_server->m_currentLevel = level;
    g_program->m_server->m_currentMode = mode != nullptr ? mode : "";

    levelSetup->Init(0, 0, 0);
    levelSetup->Name = StringUtils::CopyWithArena(level);

    if (mode != nullptr)
    {
        levelSetup->SetInclusionOption("GameMode", mode);
    }
    else
    {
        return;
    }

    // Below is campaign map testing, breaks dedicated server start points
    if (strcmp(mode, "Campaign") != 0)
    {
        return;
    }

    if (strlen(initialSubLevel) != 0)
    {
        levelSetup->InitialStartPoint = StringUtils::CopyWithArena(startPoint);
    }

    levelSetup->InitialDSubLevel = StringUtils::CopyWithArena(initialSubLevel);
}

Server::Server()
    : m_mainLoopInitEventManager(new EventManager())
    , m_socketManager()
    , m_natClient(nullptr)
    , m_playerManager(nullptr)
    , m_persistenceManager(new PersistenceManager())
    , m_socketSpawnInfo(SocketSpawnInfo(false, "", "", ""))
    , m_serverInstance(nullptr)
    , m_onlineMode(IsOnlineMode())
    , m_runningHosted(false)
    , m_restarting(false)
    , m_hooksRemoved(false)
    , m_levelLoaded(false)
    , m_latestLoadLevelRequest(LoadLevelRequest())
{
    m_mainLoopInitEventManager->RegisterListener<MainLoopInitStartServerEvent>(this);
    m_mainLoopInitEventManager->RegisterListener<MainLoopInitJoinServerEvent>(this);

    // Using the dirty sock socket manager makes KYBER servers compatible with non-kyber battlefront clients
    bool useDirtySockSocketManager = std::getenv("KYBER_USE_DIRTY_SOCK") != nullptr;
    if (useDirtySockSocketManager)
    {
        // Lazy loaded in InitDedicatedServer
        m_socketManager = nullptr;
    }
    else
    {
        m_socketManager = new SocketManager(ProtocolDirection::Clientbound, SocketSpawnInfo());
    }
}

Server::~Server()
{
    KYBER_LOG(Debug, "[Server] Destroying");
}

bool Server::IsRunning()
{
    return m_runningHosted || g_program->m_isDedicatedServer;
}

void Server::Initialize()
{
    InitializeGameHooks();

    if (!g_program->m_isDedicatedServer)
    {
        DisableGameHooks();
    }

    InitializeGamePatches();

    m_persistenceManager->Initialize();
}

void Server::Start(const ServerCreationInfo& info, bool changeState)
{
    EnableGameHooks();

    NetworkSettings* networkSettings = Settings<NetworkSettings>("Network");
    networkSettings->MaxClientCount = info.maxPlayers;
    networkSettings->ServerPort = 25200;
    // networkSettings->UseFrameManager = false;

    KYBER_LOG(Info, "[Server] Protocol Version " << networkSettings->ProtocolVersion << " TitleId " << networkSettings->TitleId);

    NetObjectSystemSettings* netObjectSettings = Settings<NetObjectSystemSettings>("NetObjectSystem");
    netObjectSettings->MaxServerConnectionCount = info.maxPlayers;
    // netObjectSettings->DeltaCompressionSettings.IsEnabled = false;

    ClientSettings* clientSettings = Settings<ClientSettings>("Client");
    clientSettings->FastExit = true;
    clientSettings->ServerIp = StringUtils::CopyWithArena("");

    GameSettings* gameSettings = Settings<GameSettings>("Game");
    gameSettings->Level = StringUtils::CopyWithArena(info.level);
    gameSettings->MaxSpectatorCount = 4;

    char* gameMode = StringUtils::CopyWithArena("GameMode=" + info.mode);
    gameSettings->DefaultLayerInclusion = gameMode;

    m_creationInfo = info;

    g_program->m_server->Register(true);


    if (m_serverId.empty())
    {
        m_onlineMode = false;
    }

    m_socketSpawnInfo = SocketSpawnInfo(false, "", m_serverId, "");

    if (m_runningHosted)
    {
        m_restarting = true;
    }

    if (changeState)
    {
        // Force
        m_levelLoaded = true;
        LoadNextLevel(info.level.c_str(), info.mode.c_str());
        // g_program->ChangeClientState(ClientState_Startup);
    }

    m_hooksRemoved = false;
    m_runningHosted = true;
}

void Server::KickPlayer(ServerPlayer* player, const char* reason)
{
    void* serverPeer = GetServerGameContext()->serverPeer;
    ServerConnection* serverConnection = ServerPeer_connectionForPlayer(serverPeer, player);
    serverConnection->SafeDisconnect(reason, SecureReason_KickedByAdmin);

    SendConsoleMessage(
        "Kicked " + std::string(player->m_name) + " (" + std::to_string(player->m_onlineId.m_nativeData) + ") from the server");
}

void Server::LoadNextLevel(
    const char* level, const char* mode, const char* startPoint, const char* initialSubLevel, bool updateServerBrowser)
{
    LevelSetup levelSetup;
    InitLevelSetup(&levelSetup, level, mode, startPoint, initialSubLevel);
    ServerLoadLevelMessage_post(&levelSetup, true, true);

    if (!updateServerBrowser || m_serverId.empty())
    {
        return;
    }

    g_program->GetAPI()->GetServerBrowser()->UpdateServerLevelSetup(m_serverId, level, mode);
}

void Server::OnLevelLoaded()
{
    m_levelLoaded = true;
    MutexGuard<LoadLevelRequest> requestGuard = m_latestLoadLevelRequest.Lock();

    if (!requestGuard->level.empty())
    {
        LoadNextLevel(requestGuard->level.c_str(), requestGuard->mode.c_str());

        requestGuard->level = "";
        requestGuard->mode = "";
    }

    KyberSettings* kyberSettings = Settings<KyberSettings>("Kyber");
    if (kyberSettings && kyberSettings->EnableShuffleTeams)
    {
        g_program->m_console->EnqueueCommand("Kyber.ShuffleTeams");
    }
}

const uint32_t kServerTeamAdminMarker = 19472;

bool ServerSendChatMessageHk(ChatChannel channel, const char* message, const ServerPlayer* player)
{
    static const auto trampoline = HookManager::Call(ServerSendChatMessageHk);
    if (message == nullptr || player == nullptr)
    {
        // uh oh?
        return false;
    }

    if (channel == ChatChannel_Admin && player->m_teamId != kServerTeamAdminMarker)
    {
        KYBER_LOG(Warning, "[Server] Player '" << player->m_name << "' (id: " << player->m_onlineId.m_nativeData
                                      << ") attempted to send admin chat message: " << message);
        return false;
    }

    if (g_program->m_scriptManager != nullptr && channel != ChatChannel_Admin)
    {
        g_program->m_scriptManager->GetEventManager().Fire("ServerPlayer:SendMessage", const_cast<ServerPlayer*>(player), message);
        if (g_program->m_scriptManager->GetEventManager().IsEventCancelled())
        {
            KYBER_LOG(Debug, "Lua event ServerPlayer:SendMessage cancelled");
            return false;
        }
    }

    return trampoline(channel, message, player);
}

void Server::BroadcastMessage(const std::string& message, const std::string& username, ChatChannel channel)
{
    char* dummyName = StringUtils::CopyWithArena(username, FB_SERVER_ARENA);

    ServerPlayer dummyPlayer;
    dummyPlayer.m_name = dummyName;
    dummyPlayer.m_teamId = kServerTeamAdminMarker;
    Server_sendChatMessage(channel, message.c_str(), &dummyPlayer);

    FB_SERVER_ARENA->free(dummyName);
}

void Server::SetDedicatedCreationInfo(const ServerCreationInfo& info)
{
    if (!g_program->m_isDedicatedServer)
    {
        return;
    }

    m_creationInfo = info;
}

__int64 ServerCtorHk(void* inst, ServerSpawnInfo& info, SocketManager* socketManager)
{
    static const auto trampoline = HookManager::Call(ServerCtorHk);

    if (g_program->m_server->m_hooksRemoved)
    {
        return trampoline(inst, info, socketManager);
    }

    info.isLocalHost = false;

    if (g_program->m_isDedicatedServer)
    {
        ServerSettings* serverSettings = Settings<ServerSettings>("Server");
        serverSettings->ThreadingEnable = false;
        //  g_program->InitializeConsole();
    }

    g_program->m_server->m_playerManager = info.playerManager;
    g_program->m_server->m_serverInstance = inst;
    KYBER_LOG(Info, "[Server] Constructing a " << info.tickFrequency << "hz server " << info.levelSetup.Name);
    
    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->GetEventManager().Fire("Server:Init");
    }

    return trampoline(inst, info, socketManager);
}

__int64 ServerStartHk(__int64 inst, ServerSpawnInfo& info, __int64 spawnOverrides, SocketManager* socketManager)
{
    static const auto trampoline = HookManager::Call(ServerStartHk);
    Server* server = g_program->m_server;

    KYBER_LOG(Info, "[Server] Starting server " << info.levelSetup.Name << " (Hooked: " << !server->m_hooksRemoved << ")");

    if (server->m_hooksRemoved)
    {
        return trampoline(inst, info, spawnOverrides, socketManager);
    }

    if (!g_program->m_isDedicatedServer && server->m_socketManager != nullptr)
    {
        socketManager = server->m_socketManager;
        socketManager->m_info = server->m_socketSpawnInfo;
        KYBER_LOG(Info, "[Server] Server is using custom socket manager");
    }

    __int64 result = trampoline(inst, info, spawnOverrides, socketManager);

    if (server->m_runningHosted && !server->m_hooksRemoved)
    {
        server->m_hooksRemoved = true;
        server->DisableGameHooks();
    }

    KYBER_LOG(Info, "[Server] Server started");

    return result;
}

__int64 SettingsManagerApplyHk(__int64 inst, __int64* a2, char* script, BYTE* a4)
{
    static const auto trampoline = HookManager::Call(SettingsManagerApplyHk);
    __int64 result = trampoline(inst, a2, script, a4);

    Settings<MeshStreamingSettings>("MeshStreaming")->PoolSize = 999999;
    
    // Setting designed for bot balancer to ensure that AutoBalanceTeamsOnNeutral is never true.
    KyberSettings* kyberSettings = Settings<KyberSettings>("Kyber");
    if (kyberSettings != nullptr)
    {
        bool enableTeamBalancing = !kyberSettings->DisableTeamBalancing;
        Settings<WSGameSettings>("Whiteshark")->AutoBalanceTeamsOnNeutral = enableTeamBalancing;
    }

    GameRenderSettings* renderSettings = Settings<GameRenderSettings>("Render");
    renderSettings->Dx11Enable = true;
    renderSettings->DLISPEnable = false;
    renderSettings->Dx12UseProfileOptionEnable = false;
    renderSettings->Dx12Enable = false;
    renderSettings->DxrEnable = 0;
    renderSettings->DynamicResolutionScaleTargetTime = -1; // other dx12 stuff
    renderSettings->DynamicResolutionMaxStepCount = 0;
    renderSettings->HdrLiveGradingOverlayOpacity = 0.f;
    renderSettings->HdrOutputPreferCs = false;
    renderSettings->DrawHdrCalibrationScreen = false;

    GlobalPostProcessSettings* postProcessSettings = Settings<GlobalPostProcessSettings>("PostProcess");
    if (postProcessSettings)
    {
        postProcessSettings->ScreenSpaceRaytraceQuality = 4;
        postProcessSettings->ScreenSpaceRaytraceFullresEnable = true;
        postProcessSettings->SpriteDofHalfResolutionEnable = false;
    }

    BaseDisplaySettings* renderDeviceSettings = Settings<BaseDisplaySettings>("RenderDevice");
    if (renderDeviceSettings)
    {
        renderDeviceSettings->DisplayDynamicRange = 0; // DisplayDynamicRange_SDR
    }

    return result;
}

bool ClientInitNetworkHk(__int64 inst, bool singleplayer, bool localhost, bool coop, bool hosted)
{
    static const auto trampoline = HookManager::Call(ClientInitNetworkHk);
    KYBER_LOG(Info, "[Client] Client is initializing network, singleplayer: " << singleplayer);
    if (g_program->m_server->m_runningHosted || strlen(Settings<ClientSettings>("Client")->ServerIp) > 0)
    {
        *reinterpret_cast<void**>(inst + 0xA8) =
            reinterpret_cast<void*>(new SocketManagerCreator(&g_program->m_clientSocketManager, g_program->m_server->m_socketSpawnInfo));
        KYBER_LOG(Info, "[Client] Using custom socket manager");
    }
    return trampoline(inst, singleplayer, localhost, coop, hosted);
}

void ClientConnectToAddressHk(__int64 inst, const char* ipAddress, const char* serverPassword)
{
    static const auto trampoline = HookManager::Call(ClientConnectToAddressHk);
    SocketSpawnInfo info = g_program->m_server->m_socketSpawnInfo;
    if (false && g_program->m_joining && info.isProxied)
    {
        KYBER_LOG(Info, "[Client] Connecting to server (proxied)");
        trampoline(inst, (std::string(info.proxyAddress) + ":25201").c_str(), serverPassword);
    }
    else
    {
        KYBER_LOG(Info, "[Client] Connecting to server " << ipAddress);
        trampoline(inst, ipAddress, serverPassword);
    }

    if (g_program->m_joining)
    {
        g_program->m_connected = true;
        g_program->m_joining = false;
    }
}

void** OnlineManagerConnectHk(void* inst, const SocketAddr& address)
{
    static const auto trampoline = HookManager::Call(OnlineManagerConnectHk);

    StringBuilder builder;
    char buf[256];

    StringBuilder_ctor(&builder, buf, 256);
    networkAddressToString(&address, builder);

    KYBER_LOG(Info, "[Client] Connecting to server (2) " << buf);

    // std::ofstream fout;
    // fout.open("addr.bin", std::ios::binary | std::ios::out);

    // fout.write((char*)&address, sizeof(SocketAddr));
    // fout.close();

    return trampoline(inst, address);
}

void ServerPlayerSetTeamIdHk(ServerPlayer* inst, int teamId)
{
    static const auto trampoline = HookManager::Call(ServerPlayerSetTeamIdHk);
    trampoline(inst, teamId);

    if (!inst->IsAIPlayer())
    {
        g_program->GetAPI()->GetServerManagement()->SendPlayerList();
    }
}

struct MainLoop
{
    char pad_0000[8];       // 0x0000
    bool isDedicatedServer; // 0x0008
};

void* s_mainLoop = nullptr;

bool MainLoopInitHk(MainLoop* inst)
{
    static const auto trampoline = HookManager::Call(MainLoopInitHk);
    s_mainLoop = inst;

    if (g_program->m_isDedicatedServer)
    {
        inst->isDedicatedServer = true;
    }

    g_program->InitializeConsole();

    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->LoadScripts(PluginRealm_Server);
    }

    KYBER_LOG(Info, "[Engine] Initializing Game Loop");
    bool result = trampoline(inst);

    KYBER_LOG(Info, "[Engine] Processing initial events");
    g_program->m_server->m_mainLoopInitEventManager->ProcessEventQueue();

    if (g_program->m_settingsManager != nullptr)
    {
        g_program->m_settingsManager->ApplySettings();
        g_program->m_server->OnSettingsRegistered();
    }

    return result;
}

void MainLoopInitDataPlatform()
{
    static const auto trampoline = HookManager::Call(MainLoopInitDataPlatform);
    trampoline();

    /*const char** dataPlatformPathName = (const char**)0x143AF6010;
    *dataPlatformPathName = "DedicatedServer";

    const char** dataPlatformPathNameLower = (const char**)0x143AF6018;
    *dataPlatformPathNameLower = "dedicatedserver";*/
}

void GameSimulationSpawnServerHk(void* inst, ServerSpawnInfo& createInfo)
{
    static const auto trampoline = HookManager::Call(GameSimulationSpawnServerHk);
    KYBER_LOG(Trace, "[GameSim] Spawning server: " << createInfo.isDedicated);
    return trampoline(inst, createInfo);
}

void GameSimulationInitDedicatedServerHk(void* inst, void* createInfo)
{
    KYBER_LOG(Info, "[GameSim] Initializing Dedicated Server");

    if (!g_program->m_server->m_creationInfo)
    {
        KYBER_LOG(Error, "[GameSim] Failed to find server creation info; halting");
        return;
    }

    if (g_program->m_server->m_socketManager == nullptr)
    {
        g_program->m_server->m_socketManager = (SocketManager*)FB_STATIC_ARENA->alloc(448);
        if (g_program->m_server->m_socketManager == nullptr)
        {
            KYBER_LOG(Error, "[GameSim] Failed to allocate socket manager; halting");
            return;
        }

        DirtySockSocketManager_ctor(g_program->m_server->m_socketManager, FB_STATIC_ARENA, 1168);
    }

    NetworkSettings* networkSettings = Settings<NetworkSettings>("Network");
    networkSettings->MaxClientCount = 64;

    GameSettings* gameSettings = Settings<GameSettings>("Game");
    gameSettings->MaxSpectatorCount = 4;

    NetObjectSystemSettings* netObjectSettings = Settings<NetObjectSystemSettings>("NetObjectSystem");
    netObjectSettings->MaxServerConnectionCount = 64;
    // netObjectSettings->DeltaCompressionSettings.IsEnabled = false;

    if (g_program->m_server->m_onlineMode)
    {
        g_program->m_server->Register();
    }

    g_program->m_server->m_socketSpawnInfo = SocketSpawnInfo(false, "", g_program->m_server->m_serverId, "");

    MapRotationEntry rotation = g_program->m_server->m_mapRotation.GetNextEntry();

    LevelSetup levelSetup;
    InitLevelSetup(
        &levelSetup, g_program->m_server->m_creationInfo->level.c_str(), g_program->m_server->m_creationInfo->mode.c_str(), "", "");

    WSGameSettings* wsSettings = Settings<WSGameSettings>("Whiteshark");
    wsSettings->AutoBalanceTeamsOnNeutral = true;

    ServerSpawnInfo spawnInfo(levelSetup);
    spawnInfo.isSinglePlayer = false;
    spawnInfo.isLocalHost = false;
    spawnInfo.isDedicated = true;
    spawnInfo.saveData.init(0);
    GameSimulationSpawnServerHk(inst, spawnInfo);
}

class GameSimulation
{
public:
    char pad_0000[256];       // 0x0000
    uint32_t unk1;            // 0x0100
    uint32_t m_tickFrequency; // 0x0104
    uint32_t m_looping;       // 0x0108
};

void GameSimulationInitHk(GameSimulation* inst, void* createInfo)
{
    static const auto trampoline = HookManager::Call(GameSimulationInitHk);
    KYBER_LOG(Info, "[GameSim] Initializing Game Simulation");

    if (g_program->m_isDedicatedServer)
    {
        PlatformUtils::HookVTableFunction(inst, &GameSimulationInitDedicatedServerHk, 31);
    }

    // Changeable, but causes some weird things.
    // In Battlefield, this works properly when paired
    // with changing Server.OutgoingHighFrequency,
    // but the equivalent settings (Server.OutgoingFrequency,
    // Server.IncomingFrequency, Client.OutgoingFrequency,
    // Client.IncomingFrequency, GameTime.MaxSimFps,
    // GameTime.ForceSimRate) in battlefront just cause
    // the player to not spawn properly.
    // inst->m_tickFrequency = 30;

    trampoline(inst, createInfo);
    KYBER_LOG(Info, "[GameSim] Game Simulation initialized: " << std::hex << inst);

    // GenericUpdateManager::Get().GameSimInit();
}

void PresenceBackendManagerAddBackendHk(void* inst, TypeObject* backend)
{
    static const auto trampoline = HookManager::Call(PresenceBackendManagerAddBackendHk);
    if (backend == nullptr)
    {
        KYBER_LOG(Debug, "[Presence] Registering null backend");
        return;
    }

    KYBER_LOG(Debug, "[Presence] Registering backend " << backend->getType()->getName());
    trampoline(inst, backend);
}

void LoadSomethingHk(void* a1, __int64 a2, __int64 a3, __int64 a4, __int64 a5, __int64 a6, void(__fastcall*** a7)(__int64), __int64 a8,
    __int64 a9, __int64 a10, char a11)
{
    static const auto trampoline = HookManager::Call(LoadSomethingHk);
    return trampoline(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, false);
}

void* CreatePresenceBackendHk(__int64* a1, __int64 a2, int backend, __int64 a4, __int64 a5)
{
    static const auto trampoline = HookManager::Call(CreatePresenceBackendHk);
    KYBER_LOG(Trace, "[Presence] Creating presence with backend 0x" << std::hex << backend);

    // The game crashes without this, presumably trying to use a
    // Blaze presence backend for dedicated servers or something
    // which has been cooked out
    if (g_program->m_isDedicatedServer)
    {
        backend = 0xB8566ABC; // OnlineBackend_Local
        // backend = 0xDEBD4193; // OnlineBackend_Peer
    }

    // NetObjectSystemSettings* netObjectSettings = Settings<NetObjectSystemSettings>("NetObjectSystem");
    // netObjectSettings->DeltaCompressionSettings.IsEnabled = false;

    return trampoline(a1, a2, backend, a4, a5);
}

SocketManager* GetSocketManagerHk(void* inst)
{
    g_program->m_server->m_socketManager->m_info = g_program->m_server->m_socketSpawnInfo;
    return g_program->m_server->m_socketManager;
}

bool MessageStreamAddMessageHk(void* inst, TypeObject* message)
{
    static const auto trampoline = HookManager::Call(MessageStreamAddMessageHk);
    KYBER_LOG(Debug, "[Engine] Sending message: " << message->getType()->getName());
    return trampoline(inst, message);
}

void ServerUpdatePassPreFrameHk(void* inst, const UpdateParameters& params)
{
    static const auto trampoline = HookManager::Call(ServerUpdatePassPreFrameHk);

    if (g_program->m_entityManager != nullptr)
    {
        g_program->m_entityManager->UpdateEntities(Realm_Server, params);
    }

    g_program->m_server->Heartbeat(params);
    g_threadExecutor->Process(GameThread_Server);

    if (g_program->m_server->IsRunning())
    {
        g_program->GetAPI()->Update();
    }

    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->GetEventManager().Fire("Server:UpdatePre", params.simulationDeltaTime.toSecondsAsFloat());
    }

    GenericUpdateManager::Get().Call(UpdateType_Server_PreFrame, params);
    return trampoline(inst, params);
}

// Only for in-proc servers.
__int64 ServerLevelUpdateLoadHk(void* inst, __int64 loadInfo)
{
    static const auto trampoline = HookManager::Call(ServerLevelUpdateLoadHk);
    __int64 result = trampoline(inst, loadInfo);

    uint32_t loadState = *reinterpret_cast<uint32_t*>(loadInfo + 0x6E8);
    if (loadState == 7 && g_program->m_server->m_creationInfo) // ServerLoadState_Done
    {
        KYBER_LOG(Info, "[Server] Level loaded, executing startup commands");

        if (g_program->m_server->m_runningHosted)
        {
            g_program->m_server->OnLevelLoaded();
        }

        for (const auto& command : g_program->m_server->m_creationInfo->loadCommands)
        {
            g_program->m_console->EnqueueCommand(command.c_str());
        }

        g_program->m_server->m_creationInfo->loadCommands.clear();
    }

    return result;
}

bool ServerConnectionOnCreatePlayerMessageHk(ServerConnection* inst, NetworkCreatePlayerMessage* message)
{
    static const auto trampoline = HookManager::Call(ServerConnectionOnCreatePlayerMessageHk);
    if (!g_program->m_server->m_runningHosted && !g_program->m_isDedicatedServer)
    {
        return trampoline(inst, message);
    }

    if (!g_program->m_server->m_onlineMode)
    {
        KYBER_LOG(Info, "[Server] " << message->playerName << " joined (Spectator: " << message->isSpectator << ")");
        return trampoline(inst, message);
    }

    // TODO: Read KyberAuthentication join token's payload to print the userId of the player joining
    KYBER_LOG(Info, "[Server] Got player join request (Spectator: " << message->isSpectator << ")");

    std::string playerName = message->playerName;
    std::string prefix = "KyberAuthentication:";

    if (playerName.rfind(prefix, 0) != 0)
    {
        KYBER_LOG(Info, "[Server] Kicking " << playerName.c_str() << " as they aren't authenticated");
        inst->SafeDisconnect("KYBER failed to authenticate your connection.\n\nPlease visit discord.gg/kyber for support.");
        return false;
    }

    std::string authToken = playerName.substr(prefix.size());
    NetworkCreatePlayerMessage* copiedMessage = MemoryUtils::Copy(FB_SERVER_ARENA, message, 0x68);

    g_program->GetAPI()->GetClientServer()->ConsumeJoinToken(g_program->m_server->m_serverId, authToken,
        [inst, playerName, copiedMessage](std::optional<const ConsumeJoinTokenResponse*> response) {
            if (!response)
            {
                KYBER_LOG(Info, "[Server] Kicking " << playerName.c_str() << " as their join token was invalid");
                inst->SafeDisconnect("KYBER failed to authenticate your connection.\n\nPlease visit discord.gg/kyber for support.");
                return;
            }

            copiedMessage->playerName = (char*)StringUtils::CopyWithArena((*response)->name(), FB_SERVER_ARENA);
            KYBER_LOG(Info, "[Server] Join token processed, letting user join as '" << copiedMessage->playerName << "'");

            uint64_t userId = stoull((*response)->id());

            // we cant inherit this trampoline due to it being static so we have to make a new one
            static const auto trampoline = HookManager::Call(ServerConnectionOnCreatePlayerMessageHk);
            trampoline(inst, copiedMessage);

            ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayerOrSpectator(copiedMessage->playerName);
            if (player != nullptr)
            {
                player->m_onlineId.m_nativeData = userId;
                strcpy(player->m_onlineId.m_id, player->m_name);

                if (g_program->m_scriptManager != nullptr)
                {
                    g_program->m_scriptManager->GetEventManager().Fire("ServerPlayer:Joined", player);
                }

                g_program->GetAPI()->GetServerManagement()->SendPlayerList();
                g_program->m_server->SendConsoleMessage(StringUtils::Format("%s (%llu) successfully authenticated", player->m_name, userId));
            }

            FB_SERVER_ARENA->free(copiedMessage->playerName);
            FB_SERVER_ARENA->free(copiedMessage);
        });

    return true;
}

void Server::Heartbeat(const UpdateParameters& params)
{
    if (!IsRunning() || !m_onlineMode)
    {
        return;
    }

    // Time between heartbeats
    const float kIntervalSeconds = 10;
    static float timer = 0;

    float deltaTime = params.simulationDeltaTime.toSecondsAsFloat();
    timer += deltaTime;

    if (timer < kIntervalSeconds)
    {
        return;
    }

    timer = 0;

    // TODO: Remove and fix SendPlayerList on disconnect
    g_program->GetAPI()->GetServerManagement()->SendPlayerList();
    
    g_program->GetAPI()->GetServerManagement()->SendKeepAlive();
}

void Server::Register(bool force)
{
    if (!force && (!IsRunning() || !m_creationInfo))
    {
        return;
    }

    if (!m_onlineMode)
    {
        return;
    }

    KYBER_LOG(Info, "[Server] Attempting to register server");

    std::optional<std::string> response = g_program->GetAPI()->GetServerBrowser()->RegisterServer(m_creationInfo.value());
    if (!response)
    {
        KYBER_LOG(Error, "[Server] Failed to register server! Connecting to dummy for automatic reconnection.");
        // Connect to server management with a dummy server id so automatic reconnection occurs.
        g_program->GetAPI()->GetServerManagement()->Connect("DUMMY");
        return;
    }

    m_onlineMode = true;

    m_serverId = response.value();
    KYBER_LOG(Info, "[Server] Registered server successfully, id: " << m_serverId);

    g_program->GetAPI()->GetServerManagement()->Connect(m_serverId);
}

void Server::OnEvent(const Event& event)
{
    if (event.is<MainLoopInitStartServerEvent>())
    {
        const auto& e = event.as<MainLoopInitStartServerEvent>();
        m_creationInfo = e.info;
    }
    else if (event.is<MainLoopInitJoinServerEvent>())
    {
        const auto& e = event.as<MainLoopInitJoinServerEvent>();
        g_program->JoinServer(e.id, e.ip, e.port, e.spectate, e.proxied, false);
    }
}

void Server::OnSettingsRegistered()
{
}

HookTemplate clientServerHookOffsets[] = {
    { OFFSET_MAINLOOP_INIT, MainLoopInitHk },
    { OFFSET_SERVER_CONSTRUCTOR, ServerCtorHk },
    { OFFSET_SERVER_START, ServerStartHk },
    { OFFSET_GAMESIMULATION_INIT, GameSimulationInitHk },
    { OFFSET_SERVERPLAYER_SETTEAMID, ServerPlayerSetTeamIdHk },
    { OFFSET_APPLY_SETTINGS, SettingsManagerApplyHk },
    { OFFSET_CLIENT_INIT_NETWORK, ClientInitNetworkHk },
    { OFFSET_CLIENT_CONNECTTOADDRESS, ClientConnectToAddressHk },
    { HOOK_OFFSET(0x140CB3640), OnlineManagerConnectHk },
    { HOOK_OFFSET(0x1478F8440), PresenceBackendManagerAddBackendHk },
    { HOOK_OFFSET(0x1418CA790), LoadSomethingHk },
    //{ HOOK_OFFSET(0x145FE09E0), ProtoHttpControlHk },
    //{ HOOK_OFFSET(0x145FE1920), ProtoHttpPostHk },
    //{ HOOK_OFFSET(0x145FE2990), ProtoHttpUpdateHk },
    //{ HOOK_OFFSET(0x145FEEA40), ProtoSSLUpdateRecvServerCertHk },
    { HOOK_OFFSET(0x140D4E1D0), MessageStreamAddMessageHk },
    { OFFSET_SERVERCONNECTION_ONCREATEPLAYERMESSAGE, ServerConnectionOnCreatePlayerMessageHk },
    { OFFSET_SERVER_UPDATEPASSPREFRAME, ServerUpdatePassPreFrameHk },
    { OFFSET_SERVERLEVEL_UPDATELOAD, ServerLevelUpdateLoadHk },
    { HOOK_OFFSET(0x140BCF350), ServerLoadLevelMessagePostHk },
    { HOOK_OFFSET(0x14193DA20), ServerSendChatMessageHk },
};

HookTemplate dedicatedServerHookOffsets[] = {
    { OFFSET_MAINLOOP_INIT, MainLoopInitHk },
    { OFFSET_SERVER_CONSTRUCTOR, ServerCtorHk },
    //{ OFFSET_MAINLOOP_INITDATAPLATFORM, MainLoopInitDataPlatform },
    { OFFSET_GAMESIMULATION_INIT, GameSimulationInitHk },
    { OFFSET_GAMESIMULATION_SPAWNSERVER, GameSimulationSpawnServerHk },
    { OFFSET_SERVERPLAYER_SETTEAMID, ServerPlayerSetTeamIdHk },
    { HOOK_OFFSET(0x1484213F0), GetSocketManagerHk },
    { HOOK_OFFSET(0x1478F8440), PresenceBackendManagerAddBackendHk },
    { HOOK_OFFSET(0x1418CA790), LoadSomethingHk },
    //{ OFFSET_SERVERCONNECTION_KICKPLAYER, ServerConnectionKickPlayerHk },
    { HOOK_OFFSET(0x140D4E1D0), MessageStreamAddMessageHk },
    { HOOK_OFFSET(0x1418D3380), CreatePresenceBackendHk },
    //{ OFFSET_APPLY_SETTINGS, SettingsManagerApplyHk },
    { OFFSET_SERVERCONNECTION_ONCREATEPLAYERMESSAGE, ServerConnectionOnCreatePlayerMessageHk },
    { OFFSET_SERVER_UPDATEPASSPREFRAME, ServerUpdatePassPreFrameHk },
    { HOOK_OFFSET(0x140BCF350), ServerLoadLevelMessagePostHk },
    { HOOK_OFFSET(0x14193DA20), ServerSendChatMessageHk },
};

void Server::InitializeGameHooks()
{
    if (g_program->m_isDedicatedServer)
    {
        for (HookTemplate& hook : dedicatedServerHookOffsets)
        {
            HookManager::CreateHook(hook.offset, hook.hook);
        }
    }
    else
    {
        for (HookTemplate& hook : clientServerHookOffsets)
        {
            HookManager::CreateHook(hook.offset, hook.hook);
        }
    }

    Hook::ApplyQueuedActions();
    KYBER_LOG(Debug, "[Server] Initialized Server Hooks");
}

void Server::EnableGameHooks()
{
    m_hooksRemoved = false;
    return;

    HookManager::EnableHook(OFFSET_SERVER_CONSTRUCTOR);
    HookManager::EnableHook(OFFSET_SERVER_START);
    // HookManager::EnableHook(OFFSET_CLIENT_CONNECTTOADDRESS);
    // HookManager::EnableHook(OFFSET_APPLY_SETTINGS);
    Hook::ApplyQueuedActions();
}

void Server::DisableGameHooks()
{
    m_hooksRemoved = true;
    return;

    HookManager::DisableHook(OFFSET_SERVER_CONSTRUCTOR);
    HookManager::DisableHook(OFFSET_SERVER_START);
    // HookManager::DisableHook(OFFSET_CLIENT_CONNECTTOADDRESS);
    // HookManager::DisableHook(OFFSET_APPLY_SETTINGS);
    Hook::ApplyQueuedActions();
}

void Server::InitializeGamePatches()
{
    BYTE dataPatch[] = { 0xEB };
    MemoryUtils::Patch(HOOK_OFFSET(0x1454DCC9D), (void*)dataPatch, sizeof(dataPatch));

    if (g_program->m_isDedicatedServer)
    {
        MemoryUtils::Nop(HOOK_OFFSET(0x146860582), 3);
        MemoryUtils::Nop(HOOK_OFFSET(0x1418E3F3C), 16);
        MemoryUtils::Nop(HOOK_OFFSET(0x1453B2163), 3);

        BYTE ptch[] = { 0xE9, 0xEF, 0x00 };
        MemoryUtils::Patch(HOOK_OFFSET(0x14183D533), (void*)ptch, sizeof(ptch));
        MemoryUtils::Patch(HOOK_OFFSET(0x140249606), (void*)dataPatch, sizeof(dataPatch));
        return;
    }

    BYTE ptch[] = { 0xB9, 0x01, 0x00, 0x00, 0x00 };
    MemoryUtils::Patch((void*)OFFSET_SERVER_PATCH, (void*)ptch, sizeof(ptch));
    BYTE ptch2[] = { 0x90, 0x90 };
    MemoryUtils::Patch((void*)(OFFSET_SERVER_PATCH + 0x5), (void*)ptch2, sizeof(ptch2));
}

void Server::InitializeGameSettings()
{
    // WSGameSettings* wsSettings = Settings<WSGameSettings>("Whiteshark");
    // wsSettings->AutoBalanceTeamsOnNeutral = true;

    // AutoPlayerSettings* aiSettings = Settings<AutoPlayerSettings>("AutoPlayers");
    // aiSettings->AllowSuicide = false;
}

void Server::OnClientStartup()
{
    static bool firstStartup = true;
    if (!firstStartup)
    {
        return;
    }

    if (!m_creationInfo)
    {
        return;
    }

    firstStartup = false;
    Start(*m_creationInfo, false);
}

void Server::SendConsoleMessage(const std::string& message)
{
    if (!IsRunning())
    {
        return;
    }

    g_program->GetAPI()->GetServerManagement()->SendConsoleMessage(message);
}

void Server::Stop()
{
    KYBER_LOG(Info, "[Server] Stopping Kyber server...");

    m_runningHosted = false;
    m_playerManager = nullptr;
    m_serverInstance = nullptr;

    m_serverId.clear();
    m_onlineMode = IsOnlineMode();

    UDPSocket* socket = m_socketManager->m_sockets.back();
    if (socket != m_natClient)
    {
        m_socketManager->Close(socket);
        socket->Close();
    }
}
} // namespace Kyber
