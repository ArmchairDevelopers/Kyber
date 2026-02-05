// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Core/Program.h>

#include <SDK/SDK.h>
#include <Base/Log.h>
#include <Base/Logo.h>
#include <Base/Version.h>
#include <Core/DebugHooks.h>
#include <Core/Memory.h>
#include <Core/Sentry.h>
#include <Hook/HookManager.h>
#include <Utilities/ErrorUtils.h>
#include <Utilities/MemoryUtils.h>
#include <Utilities/StringUtils.h>
#include <Utilities/PlatformUtils.h>
#include <Core/ThreadExecutor.h>
#include <Entity/KyberSettings.h>

#include <MinHook.h>

#include <process.h>
#include <spdlog/sinks/daily_file_sink.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>

#include <ixwebsocket/IXNetSystem.h>

#include <cstdio>
#include <stdlib.h>
#include <string.h>
#include <thread>
#include <memory>
#include <mutex>

#define OFFSET_GET_SETTINGS_OBJECT HOOK_OFFSET(0x1401F7BD0)
#define OFFSET_ENVIRONMENT_GET_HOST_ID HOOK_OFFSET(0x1454D5900)
#define OFFSET_ENVIRONMENT_GET_HOST_IDENTIFIER HOOK_OFFSET(0x1454D59E0)
#define OFFSET_MESSAGEMANAGER_QUEUE_MESSAGE HOOK_OFFSET(0x1401F8950)
#define OFFSET_MESSAGEMANAGER_DISPATCH_MESSAGE HOOK_OFFSET(0x1401F6CA0)
#define OFFSET_STREAMMANAGERMOVECLIENT_TRANSMIT HOOK_OFFSET(0x140D538E0)
#define OFFSET_STREAMMANAGERMOVESERVER_RECEIVE HOOK_OFFSET(0x140D51E40)
#define OFFSET_STREAMMANAGERCHAT_TRANSMIT HOOK_OFFSET(0x1419411C0)
#define OFFSET_ENTRYINPUTSTATENETWORKMOVE_MOVEREAD HOOK_OFFSET(0x146A42250)
#define OFFSET_ENTRYINPUTSTATENETWORKMOVE_MOVEWRITE HOOK_OFFSET(0x146A43020)
#define OFFSET_ORIGINSDK_INITIALIZE HOOK_OFFSET(0x14138D070)
#define OFFSET_MEMORYARENA_ALLOC HOOK_OFFSET(0x14541CD00)
#define OFFSET_MEMORYARENA_LOG HOOK_OFFSET(0x14019AAA0)
#define OFFSET_READOBFUSCATED HOOK_OFFSET(0x1454DC150)
#define OFFSET_GETLOCALIZEDSTRING HOOK_OFFSET(0x147792030)
#define OFFSET_FILESUPERBUNDLEMANAGER_UPDATECONFIG HOOK_OFFSET(0x14024CA10)
#define OFFSET_KICK_DISCONNECTED_PLAYERS HOOK_OFFSET(0x140D5F330)
#define OFFSET_MAINLOOP_INIT HOOK_OFFSET(0x140186B90)
#define OFFSET_MAINLOOP_INITDATAPLATFORM HOOK_OFFSET(0x145315E30)
#define OFFSET_GAMESIMULATION_INIT HOOK_OFFSET(0x145315930)
#define OFFSET_GAMESIMULATION_SPAWNSERVER HOOK_OFFSET(0x14018EE70)

using namespace fastdelegate;

namespace Kyber
{
TL_DECLARE_FUNC(0x14131AB20, void*, DirtySockSocketManager_ctor, void* inst, MemoryArena* arena, uint32_t maxPacketSize);

Program* g_program;

Program::Program(HMODULE module)
    : m_module(module)
    , m_api(nullptr)
    , m_client(nullptr)
    , m_server(nullptr)
    , m_console(nullptr)
    , m_entityManager(nullptr)
    , m_scriptManager(nullptr)
    , m_settingsManager(nullptr) 
    , m_startupInitialized(false)
    , m_allowInteraction(true)
    , m_isDedicatedServer(false)
    , m_messageDebugEnabled(false)
{
    if (g_program || MH_Initialize() != MH_OK)
    {
        ErrorUtils::ThrowException("Initialization failed. Please restart Battlefront and try again.");
    }

    new std::thread(&Program::InitializationThread, this);
}

Program::~Program()
{
    KYBER_LOG(Info, "Destroying Kyber");
}

void Program::Uninitialize() const
{
    HookManager::RemoveHooks();
    delete m_server;
}

spdlog::level::level_enum DecideLogLevel()
{
    std::string level = PlatformUtils::GetEnv("KYBER_LOG_LEVEL", "info");
    std::transform(level.begin(), level.end(), level.begin(), [](unsigned char c) { return std::tolower(c); });

    if (level == "debug")
    {
        return spdlog::level::debug;
    }
    else if (level == "trace")
    {
        return spdlog::level::trace;
    }

    return spdlog::level::info;
}

void MainInitHk()
{
    static const auto trampoline = HookManager::Call(MainInitHk);

    KYBER_LOG(Info, "[Engine] Initializing game, waiting for Kyber...");

    std::unique_lock<std::mutex> lock(g_program->m_startupMutex);
    g_program->m_startupCondition.wait(lock, [] { return g_program->m_startupInitialized; });

    KYBER_LOG(Info, "[Engine] Finished initializing");

    trampoline();
}

void Program::InitializationThread()
{
    HookManager::CreateHook(HOOK_OFFSET(0x1401898A0), MainInitHk);
    Hook::ApplyQueuedActions();

    Sentry::Initialize();

    InitializeEASTL();

    bool hideConsole = std::getenv("KYBER_HIDE_CONSOLE") != nullptr;
    bool hideConsoleVisually = std::getenv("KYBER_HIDE_CONSOLE_WINDOW") != nullptr;

    // Open a console
    FILE* consoleFile = nullptr;
    if (!hideConsole)
    {
        AllocConsole();

        if (!hideConsoleVisually)
        {
            freopen_s(&consoleFile, "CONOUT$", "w", stdout);
            freopen_s(&consoleFile, "CONOUT$", "w", stderr);
        }

        HWND hwnd = GetConsoleWindow();
        if (hideConsoleVisually)
        {
            ShowWindow(hwnd, SW_HIDE);
        }
        else
        {
            MoveWindow(hwnd, 100, 100, 1280, 600, true);
        }
    }

    // ANSI Colors
    HANDLE stdoutHandle = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD dwMode;
    GetConsoleMode(stdoutHandle, &dwMode);
    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    SetConsoleMode(stdoutHandle, dwMode);

    m_isDedicatedServer = std::getenv("KYBER_DEDICATED_SERVER") != nullptr;
    m_messageDebugEnabled = std::getenv("KYBER_MESSAGE_DEBUG") != nullptr;

    std::vector<spdlog::sink_ptr> sinks;

    // if (!m_isDedicatedServer)
    {
        sinks.push_back(std::make_shared<spdlog::sinks::stdout_color_sink_mt>());
    }

    std::string logName = "kyber";
    if (m_isDedicatedServer)
    {
        logName += "-server";
    }

    logName += ".log";

    std::filesystem::path logPath = PlatformUtils::GetProgramDataPath() / "Logs" / logName;
    sinks.push_back(std::make_shared<spdlog::sinks::daily_file_sink_mt>(logPath.string(), 23, 59));
    auto combinedLogger = std::make_shared<spdlog::logger>("KYBER", begin(sinks), end(sinks));
    spdlog::register_logger(combinedLogger);
    spdlog::set_default_logger(combinedLogger);

    spdlog::level::level_enum level = DecideLogLevel();
    spdlog::set_level(level);
    spdlog::flush_on(level);

    for (int i = 0; i < sizeof(kLogoArt) / sizeof(*kLogoArt); i++)
    {
        KYBER_LOG(Info, kLogoArt[i] << "\u001b[0m");
    }

    ThreadExecutor::StaticInit();

    // Kyber Mod Loader requires vanilla game data
    _putenv_s("GAME_DATA_DIR", "");

    const char* apiToken = std::getenv("KYBER_API_TOKEN");
    if (apiToken == nullptr)
    {
        ErrorUtils::ThrowException("No API token specified");
        return;
    }

    ix::initNetSystem();

    m_api = std::make_unique<API>(apiToken);

    m_interface = std::make_unique<InterfaceService>();

    m_server = new Server();
    m_client = new Client();
    m_entityManager = new EntityManager();
    m_settingsManager = new KyberSettingsManager();
    m_scriptManager = new ScriptManager();

    if (!m_isDedicatedServer)
    {
        m_client->m_voipManager = new VoipManager();
    }

    std::string title = "KYBER";
    if (m_isDedicatedServer)
    {
        title += " - 24/7 SERVER";
    }
    title += " (" + std::string(KYBER_VERSION) + ")";

    SetConsoleTitleA(title.c_str());

    KYBER_LOG(Info, "[Engine] Initializing KYBER v" << KYBER_VERSION);

    bool useStdinConsole = (m_isDedicatedServer && !hideConsole) || std::getenv("KYBER_STDIN_CONSOLE") != nullptr;
    if (useStdinConsole)
    {
        if (!hideConsole)
        {
            freopen_s(&consoleFile, "CONIN$", "r", stdin);
        }

        std::ios_base::sync_with_stdio(false);
    }

    m_api->GetLauncherInterface()->Initialize();

    using namespace std::chrono_literals;

    std::string line;
    while (true || !(GetAsyncKeyState(VK_END) & 1))
    {
        if (!useStdinConsole)
        {
            std::this_thread::sleep_for(200ms);
            continue;
        }

        std::getline(std::cin, line);

        auto delegate = FastDelegate<void(const char*)>([](const char* result) {
            if (strlen(result) == 0)
            {
                return;
            }

            KYBER_LOG(Info, "[Console] Result: " << result);
        });
        Console_enqueueCommand(line.c_str(), delegate);

        // KYBER_LOG(Info, "Executed command " << line.c_str());
    }

    KYBER_LOG(Info, "Shutting down...");
    // fclose(pFile);
    // FreeConsole();

    Uninitialize();
    FreeLibrary(m_module);
}

void Program::InitializeConsole()
{
    if (m_console != nullptr)
    {
        return;
    }

    m_console = new Console();

    for (const auto& fn : m_consoleRegistrationCallbacks)
    {
        fn();
    }

    m_consoleRegistrationCallbacks.clear();
}

void MemoryArenaLog(__int64 a1, const char* format, ...)
{
    static const auto trampoline = HookManager::Call(MemoryArenaLog);
    KYBER_LOG(Info, "Memory Arena: " << format);
}

void FbCoreInitHk(void* a1, bool a2, __int64 a3, unsigned __int8(__fastcall* a4)(__int64))
{
    static const auto trampoline = HookManager::Call(FbCoreInitHk);
    KYBER_LOG(Info, "[Engine] Initializing FB Core");
    trampoline(a1, a2, a3, a4);
}

// Need to bypass signature verification to run under wine
uint8_t* ReadObfuscatedHk(uint8_t* data, uint32_t* size)
{
    *size -= 0x22C;
    return data + 0x22C;
}

__int64 OriginSDKInitializeHk(void* inst, int a2, uint16_t lsxPort, void* a4, void* a5)
{
    static const auto trampoline = HookManager::Call(OriginSDKInitializeHk);

    const char* lsxPortVar = std::getenv("EALsxPort");
    if (lsxPortVar != nullptr)
    {
        lsxPort = atoi(lsxPortVar);
    }

    return trampoline(inst, a2, lsxPort, a4, a5);
}

TL_DECLARE_FUNC(0x146C5EF40, __int64, __unkServerGhosts, __int64*);
// Server Message Manager
void MessageManagerDispatchMessageHk(void* inst, Message* message)
{
    static const auto trampoline = HookManager::Call(MessageManagerDispatchMessageHk);
    if (message == nullptr)
    {
        trampoline(inst, message);
        return;
    }

    TypeInfo* type = message->getType();
    if (type == nullptr || type->typeInfoData == nullptr)
    {
        trampoline(inst, message);
        return;
    }

    eastl::string name = type->getName();

    if (g_program->m_messageDebugEnabled)
    {
        if (name == "ClientInputUnchangedInputMessage" || name == "StreamInstallRequestSuspendMessage")
        {
            return;
        }

        KYBER_LOG(Info, "Dispatched message " << type->getName());
    }

    if (name == "ServerPlayerAboutToCreateForConnectionMessage")
    {
        ServerPlayerAboutToCreateForConnectionMessage* msg = (ServerPlayerAboutToCreateForConnectionMessage*)message;

        if (g_program->m_server->IsRunning())
        {
            KYBER_LOG(Info, msg->requestedName << " joined the server");
        }
    }
    else if (name == "ServerLevelCompletedMessage")
    {
        KYBER_LOG(Info, "[Server] Game ended, moving to next level");

        if (g_program->m_scriptManager != nullptr)
        {
            g_program->m_scriptManager->GetEventManager().Fire("Level:Complete");
        }

        MapRotationEntry rotation = g_program->m_server->m_mapRotation.GetNextEntry();
        g_program->m_server->LoadNextLevel(rotation.level.c_str(), rotation.mode.c_str());
    }
    else if (name == "ServerLevelLoadedMessage")
    {
        KYBER_LOG(Info, "[Server] Server level loaded");

        g_program->m_server->OnLevelLoaded();
    }
    else if (name == "ServerLevelSpawnEntitiesBeginMessage")
    {
        KYBER_LOG(Info, "[Server] Spawning server entities...");
    }
    else if (name == "ServerPlayerDisconnectMessage")
    {
        ServerPlayerDisconnectMessage* msg = (ServerPlayerDisconnectMessage*)message;

        if (g_program->m_server->IsRunning())
        {
            g_program->m_server->m_persistenceManager->SavePlayerStats(msg->m_player);

            g_program->GetAPI()->GetServerManagement()->SendPlayerList();
            g_program->GetAPI()->GetServerManagement()->SendConsoleMessage(
                StringUtils::Format("%s (%llu) left the server", msg->m_player->m_name, msg->m_player->m_onlineId.m_nativeData));

            if (g_program->m_scriptManager != nullptr)
            {
                g_program->m_scriptManager->GetEventManager().Fire("ServerPlayer:Disconnect", msg->m_player);
            }
        }
    }
    else if (name == "ServerPlayerChatMessage")
    {
        ServerPlayerChatMessage* msg = (ServerPlayerChatMessage*)message;

        std::string log = std::string(msg->m_sender->m_name) + ": " + msg->m_message;
        g_program->GetAPI()->GetServerManagement()->SendConsoleMessage(log);
    }
    else if (name == "ServerPeerInitializedMessage")
    {
        KYBER_LOG(Debug, "ServerPeerInitializedMessage: " << std::hex << message);
    }
    else if (name == "ServerPlayerKilledMessage")
    {
        ServerPlayerKilledMessage* msg = (ServerPlayerKilledMessage*)message;
        KYBER_LOG(Debug, "ServerPlayerKilledMessage EXECUTED: " << std::hex << msg);
        if (g_program->m_scriptManager != nullptr)
        {
            char* killerWeaponName = msg->m_deathInfo && msg->m_deathInfo->killerWeapon && msg->m_deathInfo->killerWeapon->Name
                ? msg->m_deathInfo->killerWeapon->Name : nullptr;

            g_program->m_scriptManager->GetEventManager().Fire(
                "ServerPlayer:Killed", msg->m_victimPlayer, msg->m_inflictorPlayer, killerWeaponName);
        }
    }
    else if (name == "PlayerAbilityPickedUpMessage")
    {
        KYBER_LOG(Debug, "PlayerAbilityPickedUpMessage: " << std::hex << message);
    }
    else if (name == "NetworkOnPlayerSpawnedMessage")
    {
        KYBER_LOG(Debug, "Player spawned: " << std::hex << message);
        if (g_program->m_scriptManager != nullptr)
        {
            g_program->m_scriptManager->GetEventManager().Fire("ClientPlayer:Spawned");
        }
    }
    else if (name == "ServerPlayerRespawnMessage")
    {
        KYBER_LOG(Debug, "Server Player spawned: " << std::hex << message);
        ServerPlayerRespawnMessage* msg = (ServerPlayerRespawnMessage*)message;
        if (g_program->m_scriptManager != nullptr)
        {
            g_program->m_scriptManager->GetEventManager().Fire("ServerPlayer:Spawned", msg->player);
        }
    }
    //else if (name == "ServerSoldierFiringMessage")
    //{
    //    KYBER_LOG(Debug, "Server Player Firing: " << std::hex << message);
    //    KYBER_LOG(Debug, "BREAKME");
    //}
    else if (name == "WSServerBattlepointsChangedMessage")
    {
        KYBER_LOG(Debug, "Server Battlepoints Changed: " << std::hex << message);
        // In case it has future use...
        //WSServerBattlepointsChangedMessage* msg = (WSServerBattlepointsChangedMessage*)message;
        //if (!msg->player->IsAIPlayer())
        //{
        //    KYBER_LOG(Info, "Player " << msg->player->m_name << " just got " << msg->changeAmount << " battlepoints. Debug: " << std::hex << msg->player << " " << //msg->player->GetBattlepoints());
        //}
    }

    trampoline(inst, message);
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
    g_program->m_server->m_eventManager->ProcessEventQueue();
    g_program->m_client->m_eventManager->ProcessEventQueue();

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

const char* GetHostIdHk(__int64 inst)
{
    return std::getenv("EALaunchEAID");
}

const char* GetLocalizedStringInternalHk(const char* inst, const char* id)
{
    static const auto trampoline = HookManager::Call(GetLocalizedStringInternalHk);
    const char* res = trampoline(inst, id);
    if (res != nullptr && res[0] != '\0')
    {
        if (strcmp(res, "You've been kicked by Fairfight") == 0)
        {
            res = StringUtils::CopyWithArena("You've been kicked by KYBER");
        }
    }
    return res;
}

void FileSuperBundleManagerUpdateConfigHk(FileSuperBundleManager* inst)
{
    static const auto trampoline = HookManager::Call(FileSuperBundleManagerUpdateConfigHk);
    KYBER_LOG(Debug, "Updating SuperBundle config");

    if (std::getenv("KYBER_DISABLE_MODLOADER") == nullptr)
    {
        g_modLoader = new ModLoader(inst, g_program->m_modData);
    }

    trampoline(inst);
    KYBER_LOG(Debug, "SuperBundle config loaded");
}

__int64 TeamInfo__isFriendlyHk(int teamA, int teamB)
{
    static const auto trampoline = HookManager::Call(TeamInfo__isFriendlyHk);
    __int64 result = trampoline(teamA, teamB);

    SyncedGameSettings* syncedGame = Settings<SyncedGameSettings>("SyncedGame");
    if (syncedGame != nullptr && syncedGame->EnableFriendlyFire)
    {
        return 2; // override
    }

    return result;
}

void DummyLuaTable(void** table)
{
    void* patchValue = reinterpret_cast<void*>(0x1401840C0); // general null sub
    for (; table[1]; table += 2)
    {
        char* str = reinterpret_cast<char*>(table[0]);
        if (strstr(str, "time") == nullptr)
        {
            MemoryUtils::Patch(&table[1], &patchValue, sizeof(void*));
        }
    }
}

void Program::InitializeGameHooks()
{
    static void* LuaDummy = HOOK_OFFSET(0x1401840C0);

    // clang-format off
    HookTemplate hookOffsets[] = {
        { OFFSET_ENVIRONMENT_GET_HOST_ID, GetHostIdHk },
        { OFFSET_ENVIRONMENT_GET_HOST_IDENTIFIER, GetHostIdHk },
        { OFFSET_ORIGINSDK_INITIALIZE, OriginSDKInitializeHk },
        { OFFSET_MESSAGEMANAGER_DISPATCH_MESSAGE, MessageManagerDispatchMessageHk },
        { OFFSET_MAINLOOP_INIT, MainLoopInitHk },
        //{ OFFSET_MAINLOOP_INITDATAPLATFORM, MainLoopInitDataPlatform },
        { OFFSET_GAMESIMULATION_INIT, GameSimulationInitHk },
        { OFFSET_GAMESIMULATION_SPAWNSERVER, GameSimulationSpawnServerHk },
        { OFFSET_READOBFUSCATED, ReadObfuscatedHk },
        { OFFSET_GETLOCALIZEDSTRING, GetLocalizedStringInternalHk },
        { OFFSET_FILESUPERBUNDLEMANAGER_UPDATECONFIG, FileSuperBundleManagerUpdateConfigHk },
        { OFFSET_MEMORYARENA_LOG, MemoryArenaLog },
        { HOOK_OFFSET(0x146A4BA30), TeamInfo__isFriendlyHk },

        // Dummy out unsafe built-in lua functions
        { HOOK_OFFSET(0x1477C4B00), LuaDummy }, // package.loadlib()
        { HOOK_OFFSET(0x1477B22F0), LuaDummy }, // dofile()
        { HOOK_OFFSET(0x1477B2140), LuaDummy }, // loadfile()
        { HOOK_OFFSET(0x1477B14D0), LuaDummy }, // getfenv()
        { HOOK_OFFSET(0x1477B1610), LuaDummy }, // setfenv()
        { HOOK_OFFSET(0x1477B1790), LuaDummy }, // rawequal()
        { HOOK_OFFSET(0x1477B1900), LuaDummy }, // rawget()
        { HOOK_OFFSET(0x1477B1B60), LuaDummy }, // rawset()
    };
    // clang-format on

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }

    Hook::ApplyQueuedActions();

    InitializeDebugHooks();
    // InitializeMemory();
}

void Program::InitializeGamePatches()
{
    // MemoryUtils::Nop(HOOK_OFFSET(0x140D61FB4), 9);  // TEMP Dedicated Server packet hash check
    // MemoryUtils::Nop(HOOK_OFFSET(0x146C3E027), 13); // TEMP Dedicated Server packet hash check

    MemoryUtils::Nop(HOOK_OFFSET(0x14018B133), 6); // Allow Multiple Game Instances
    MemoryUtils::Nop(HOOK_OFFSET(0x140235C2E), 6); // Enable All Console Commands

    // Null out built-in Lua function tables
    static intptr_t tables[] = { 
        0x14308A430, // debug
        0x143089BB0, // os
        0x1430898A0, // io
        0x143089960, // file
        0 // null term
    };

    for (void*** i = reinterpret_cast<void***>(tables); *i; i++)
    {
        DummyLuaTable(*i);
    }
}

void Program::Initialize()
{
    InitializeGameHooks();
    InitializeGamePatches();

    m_server->Initialize();
    m_client->Initialize();

    KYBER_LOG(Info, "[Engine] Kyber post-initialized");
}
} // namespace Kyber
