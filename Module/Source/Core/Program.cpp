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
#include <Misc/EventSyncListener.h>
#include <Misc/ServerSpawnListener.h>

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

#define OFFSET_CLIENT_CTOR HOOK_OFFSET(0x140A874C0)
#define OFFSET_CLIENT_STATE_CHANGE HOOK_OFFSET(0x140A8C7A0)
#define OFFSET_GET_SETTINGS_OBJECT HOOK_OFFSET(0x1401F7BD0)
#define OFFSET_ENVIRONMENT_GET_HOST_ID HOOK_OFFSET(0x1454D5900)
#define OFFSET_ENVIRONMENT_GET_HOST_IDENTIFIER HOOK_OFFSET(0x1454D59E0)
#define OFFSET_MESSAGEMANAGER_QUEUE_MESSAGE HOOK_OFFSET(0x1401F8950)
#define OFFSET_MESSAGEMANAGER_DISPATCH_MESSAGE HOOK_OFFSET(0x1401F6CA0)
#define OFFSET_CLIENTCONNECTION_ONDISCONNECTED HOOK_OFFSET(0x140CB7800)
#define OFFSET_STREAMMANAGERMOVECLIENT_TRANSMIT HOOK_OFFSET(0x140D538E0)
#define OFFSET_STREAMMANAGERMOVESERVER_RECEIVE HOOK_OFFSET(0x140D51E40)
#define OFFSET_STREAMMANAGERCHAT_TRANSMIT HOOK_OFFSET(0x1419411C0)
#define OFFSET_ENTRYINPUTSTATENETWORKMOVE_MOVEREAD HOOK_OFFSET(0x146A42250)
#define OFFSET_ENTRYINPUTSTATENETWORKMOVE_MOVEWRITE HOOK_OFFSET(0x146A43020)
#define OFFSET_ORIGINSDK_INITIALIZE HOOK_OFFSET(0x14138D070)
#define OFFSET_MEMORYARENA_ALLOC HOOK_OFFSET(0x14541CD00)
#define OFFSET_MEMORYARENA_LOG HOOK_OFFSET(0x14019AAA0)
#define OFFSET_READOBFUSCATED HOOK_OFFSET(0x1454DC150)
#define OFFSET_CLIENTCONNECTION_SENDMESSAGE HOOK_OFFSET(0x140CBA480)
#define OFFSET_GETLOCALIZEDSTRING HOOK_OFFSET(0x147792030)
#define OFFSET_FILESUPERBUNDLEMANAGER_UPDATECONFIG HOOK_OFFSET(0x14024CA10)
#define OFFSET_CLIENT_UPDATEPASSPREFRAME HOOK_OFFSET(0x1465D9FA0)
#define OFFSET_CLIENT_UPDATEPASSPOSTFRAME HOOK_OFFSET(0x1465D9C30)
#define OFFSET_KICK_DISCONNECTED_PLAYERS HOOK_OFFSET(0x140D5F330)

using namespace fastdelegate;

namespace Kyber
{
Program* g_program;

Program::Program(HMODULE module)
    : m_module(module)
    , m_api(nullptr)
    , m_server(nullptr)
    , m_console(nullptr)
    , m_entityManager(nullptr)
    , m_scriptManager(nullptr)
    , m_settingsManager(nullptr)
    //, m_frostyLink(nullptr)
    //, m_replaySystem(nullptr)
    , m_voipManager(nullptr)
    , m_clientSocketManager(nullptr)
    , m_clientState(ClientState_None)
    , m_startupInitialized(false)
    , m_joining(false)
    , m_spectator(false)
    , m_connected(false)
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
    m_entityManager = new EntityManager();
    m_settingsManager = new KyberSettingsManager();
    m_scriptManager = new ScriptManager();

    if (!m_isDedicatedServer)
    {
        m_voipManager = new VoipManager();
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

void Program::HandleClientServerJoin(NetworkCreatePlayerMessage* message)
{
    if (!m_joining && !m_connected && !m_server->m_runningHosted)
    {
        return;
    }

    if (!m_server->m_onlineMode)
    {
        return;
    }

    char* name = StringUtils::CopyWithArena("KyberAuthentication:" + m_joinToken);
    message->playerName = name;
    message->isSpectator = m_spectator;

    KYBER_LOG(Info, "[Client] Joining game with authentication");
    KYBER_LOG(Debug, "[Client] Joining game as '" << message->playerName << "'");

    AttemptJoinVoip();
}

void Program::AttemptJoinVoip()
{
    if (m_voipManager == nullptr || !m_voipManager->IsLoggedIn() || m_server->m_socketSpawnInfo.serverName.empty() || m_voipManager->IsConnected())
    {
        return;
    }

    KYBER_LOG(Info, "[Client] Joining VoIP");
    m_api->GetVoip()->JoinChannel(m_server->m_socketSpawnInfo.serverName, [&](std::optional<const VoipJoinChannelResponse*> response) {
        if (!response)
        {
            KYBER_LOG(Error, "[VoIP] Failed to retrieve vivox channel credentials. Proximity chat will not work!");
            return;
        }

        m_voipManager->AddSession((*response)->channel(), (*response)->accesstoken());
    });
}

void Program::JoinServer(const std::string& id, std::string ip, uint16_t port, bool spectate, bool proxied, bool changeState)
{
    if (!id.empty())
    {
        auto server = m_api->GetServerBrowser()->GetServer(id);
        if (!server)
        {
            KYBER_LOG(Error, "[Client] Server " << id << " not found, connection failed!");
            return;
        }

        auto meta = server->meta();
        auto proxy_id_it = meta.find("pinned_proxy_id");
        if (proxy_id_it != meta.end())
        {
            auto proxies = g_program->GetAPI()->GetProxy()->GetList();
            for (const auto& proxy : proxies)
            {
                if (proxy.id() == proxy_id_it->second)
                {
                    ip = proxy.ip();
                    KYBER_LOG(Info, "[Client] Overriding with pinned proxy '" << proxy.id() << "'");
                    break;
                }
            }
        }
    }

    ClientSettings* clientSettings = Settings<ClientSettings>("Client");
    clientSettings->ServerIp = StringUtils::CopyWithArena(ip);

    SocketSpawnInfo info(proxied, proxied ? ip : "", id, "");
    m_server->m_socketSpawnInfo = info;
    m_joining = true;
    m_spectator = spectate;

    KYBER_LOG(Info, "[Client] Joining server " << id << " at " << ip << ":" << port << " [Proxied: " << proxied
                                               << ", Spectate: " << spectate << ", ChangeState: " << changeState << "]");

    Settings<NetworkSettings>("Network")->ServerPort = port;
    if (changeState)
    {
        ChangeClientState(ClientState_Startup);
    }
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

__int64 ClientCtorHk(__int64 inst, void* a2, __int64 a3)
{
    static const auto trampoline = HookManager::Call(ClientCtorHk);
    KYBER_LOG(Info, "[Client] Creating client");

    if (g_program->m_voipManager != nullptr)
    {
        g_program->m_voipManager->Init();
    }

    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->LoadScripts(PluginRealm_Client);
    }

    return trampoline(inst, a2, a3);
}

__int64 ClientStateChangeHk(__int64 inst, ClientState currentClientState, ClientState lastClientState)
{
    static const auto trampoline = HookManager::Call(ClientStateChangeHk);
    g_program->m_clientState = currentClientState;
    KYBER_LOG(Info, "[Client] Client state changed to " << ClientStateToString(currentClientState));
    Server* server = g_program->m_server;
    if (!server)
    {
        return trampoline(inst, currentClientState, lastClientState);
    }

    if (currentClientState == ClientState_Startup)
    {
        static bool firstStartup = true;

        // g_program->m_console->UnregisterCommands();
        g_program->m_allowInteraction = false;

        if ((server->m_runningHosted || g_program->m_connected) && g_program->m_clientSocketManager)
        {
            // g_program->m_clientSocketManager->CloseSockets();
            g_program->m_clientSocketManager = nullptr;
        }

        if (g_program->m_connected)
        {
            KYBER_LOG(Info, "[Client] Leaving server");

            if (g_program->m_voipManager != nullptr)
            {
                g_program->m_voipManager->RemoveSession();
            }

            g_program->m_spectator = false;
        }

        g_program->m_connected = false;

        if (server->m_runningHosted)
        {
            if (!server->m_restarting)
            {
                KYBER_LOG(Info, "[Server] Stopping server");
                server->Stop();

                if (g_program->m_voipManager != nullptr)
                {
                    g_program->m_voipManager->RemoveSession();
                }

                g_program->m_spectator = false;

                GameSettings* gameSettings = Settings<GameSettings>("Game");
                gameSettings->Level = const_cast<char*>(StringUtils::CopyWithArena("Levels/FrontEnd/FrontEnd"));
                gameSettings->DefaultLayerInclusion = const_cast<char*>(StringUtils::CopyWithArena(""));
            }
            else
            {
                server->m_restarting = false;
            }
        }
        else if (!g_program->m_joining && !firstStartup)
        {
            Settings<ClientSettings>("Client")->ServerIp = const_cast<char*>(StringUtils::CopyWithArena(""));
        }

        server->OnClientStartup();

        firstStartup = false;
    }
    else if (currentClientState == ClientState_Ingame)
    {
        g_program->GetAPI()->GetLauncherInterface()->OnServerJoined();
        g_program->m_allowInteraction = true;
        if (server->m_runningHosted)
        {
            server->InitializeGameSettings();
        }
    }

    return trampoline(inst, currentClientState, lastClientState);
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

// TODO: Properly implement the EngineConnection type to not have this garbage
class EngineConnection2
{
public:
    char pad_0000[1544];   // 0x0000
    char* m_reasonText;    // 0x0608
    char pad_0610[24];     // 0x0610
    SecureReason m_reason; // 0x0628
};

void ClientConnectionOnDisconnectedHk(__int64 inst)
{
    static const auto trampoline = HookManager::Call(ClientConnectionOnDisconnectedHk);

    EngineConnection2* connBase = (EngineConnection2*)(inst - 0x10); // ClientConnection -> EngineConnection
    SecureReason reason = connBase->m_reason;
    char* reasonText = connBase->m_reasonText;

    if (reason == SecureReason_TimedOut)
    {
        reason = SecureReason_KickedViaFairFight;
        reasonText = StringUtils::CopyWithArena("Timed out.", FB_CLIENT_ARENA);
    }
    else if (reason == SecureReason_NoReply)
    {
        reason = SecureReason_KickedViaFairFight;
        reasonText = StringUtils::CopyWithArena("The server did not reply.", FB_CLIENT_ARENA);
    }
    else if (reason == SecureReason_KickedByAdmin)
    {
        reason = SecureReason_KickedViaFairFight;
        reasonText =
            StringUtils::CopyWithArena("You were kicked by a server admin.\n\nReason: " + std::string(reasonText), FB_CLIENT_ARENA);
    }

    KYBER_LOG(Info, "[Client] Disconnected from server: " << std::hex << reason << " " << reasonText);

    g_program->GetAPI()->GetLauncherInterface()->OnServerDisconnect();

    connBase->m_reason = reason;
    connBase->m_reasonText = reasonText;
    trampoline(inst);
}

void ClientConnectionSendMessageHk(void* inst, Message* message)
{
    static const auto trampoline = HookManager::Call(ClientConnectionSendMessageHk);
    if (message != nullptr && message->Is("NetworkCreatePlayerMessage"))
    {
        NetworkCreatePlayerMessage* msg = static_cast<NetworkCreatePlayerMessage*>(message);
        g_program->HandleClientServerJoin(msg);
    }
    trampoline(inst, message);
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

        if (g_program->m_isDedicatedServer)
        {
            g_program->m_server->OnLevelLoaded();
        }
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
    else if (name == "ServerSoldierFiringMessage")
    {
        KYBER_LOG(Debug, "Server Player Firing: " << std::hex << message);
        KYBER_LOG(Debug, "BREAKME");
    }
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

__int64 ClientUpdatePassPreFrameHk(void* inst, const UpdateParameters& params)
{
    static const auto trampoline = HookManager::Call(ClientUpdatePassPreFrameHk);
    __int64 result = trampoline(inst, params);

    if (g_program->m_entityManager != nullptr)
    {
        g_program->m_entityManager->UpdateEntities(Realm_Client, params);
    }

    for (const auto& listener : g_program->m_clientUpdatePassListeners)
    {
        listener->Call(ClientUpdatePass_PreFrame);
    }

    g_threadExecutor->Process(GameThread_Client);

    if (!g_program->m_server->IsRunning())
    {
        g_program->GetAPI()->Update();
    }

    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->GetEventManager().Fire("Client:UpdatePre", params.simulationDeltaTime.toSecondsAsFloat());
    }

    GenericUpdateManager::Get().Call(UpdateType_Client_PreFrame, params);
    return result;
}

__int64 ClientUpdatePassPostFrameHk(void* inst, const UpdateParameters& params)
{
    static const auto trampoline = HookManager::Call(ClientUpdatePassPostFrameHk);
    __int64 result = trampoline(inst, params);

    for (const auto& listener : g_program->m_clientUpdatePassListeners)
    {
        listener->Call(ClientUpdatePass_PostFrame);
    }

    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->GetEventManager().Fire("Client:UpdatePost", params.simulationDeltaTime.toSecondsAsFloat());
    }

    GenericUpdateManager::Get().Call(UpdateType_Client_PostFrame, params);
    return result;
}

__int64 ClientAuthHk(__int64 a1, OnlineId* a2, unsigned int a3)
{
    static const auto trampoline = HookManager::Call(ClientAuthHk);
    __int64 result = trampoline(a1, a2, a3);
    KYBER_LOG(Info, "[Client] Joining server authenticated as " << a2->m_nativeData << " " << a2->m_id << " " << a3);
    return result;
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

void Program::RegisterClientUpdatePassListener(ClientUpdatePassListener* listener)
{
    m_clientUpdatePassListeners.push_back(listener);
}

void Program::InitializeGameHooks()
{
    static void* LuaDummy = HOOK_OFFSET(0x1401840C0);

    // clang-format off
    HookTemplate hookOffsets[] = {
        { OFFSET_CLIENT_STATE_CHANGE, ClientStateChangeHk },
        { OFFSET_ENVIRONMENT_GET_HOST_ID, GetHostIdHk },
        { OFFSET_ENVIRONMENT_GET_HOST_IDENTIFIER, GetHostIdHk },
        { OFFSET_ORIGINSDK_INITIALIZE, OriginSDKInitializeHk },
        { OFFSET_MESSAGEMANAGER_DISPATCH_MESSAGE, MessageManagerDispatchMessageHk },
        { OFFSET_CLIENTCONNECTION_ONDISCONNECTED, ClientConnectionOnDisconnectedHk },
        { OFFSET_READOBFUSCATED, ReadObfuscatedHk },
        { OFFSET_CLIENTCONNECTION_SENDMESSAGE, ClientConnectionSendMessageHk },
        { OFFSET_GETLOCALIZEDSTRING, GetLocalizedStringInternalHk },
        { OFFSET_CLIENT_CTOR, ClientCtorHk },
        { OFFSET_FILESUPERBUNDLEMANAGER_UPDATECONFIG, FileSuperBundleManagerUpdateConfigHk },
        { OFFSET_CLIENT_UPDATEPASSPREFRAME, ClientUpdatePassPreFrameHk },
        { OFFSET_CLIENT_UPDATEPASSPOSTFRAME, ClientUpdatePassPostFrameHk },
        { HOOK_OFFSET(0x1418D92B0), ClientAuthHk },
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

    //InitializeEventSyncHook();
    InitializeSpawnListenerHook();
    
    KYBER_LOG(Info, "[Engine] Kyber post-initialized");
}
} // namespace Kyber
