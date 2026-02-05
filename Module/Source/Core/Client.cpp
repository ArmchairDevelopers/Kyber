// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Core/Client.h>

#include <Core/Program.h>
#include <Hook/HookManager.h>
#include <Base/Log.h>
#include <Utilities/MemoryUtils.h>
#include <SDK/TypeInfo.h>
#include <SDK/SDK.h>
#include <SDK/Funcs.h>

#include <optional>

namespace Kyber
{

Client::Client()
    : m_joining(false)
    , m_spectator(false)
    , m_connected(false)
    , m_voipManager(nullptr)
    , m_socketManager(nullptr)
    , m_eventManager(new EventManager())
    , m_clientState(ClientState_None)
{
    m_eventManager->RegisterListener<MainLoopInitJoinServerEvent>(this);
}

Client::~Client()
{
    KYBER_LOG(Debug, "[Client] Destroying");
}

void Client::HandleClientServerJoin(NetworkCreatePlayerMessage* message)
{
    if (!m_joining && !m_connected && !g_program->m_server->m_runningHosted)
    {
        return;
    }

    if (!g_program->m_server->m_onlineMode)
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

void Client::AttemptJoinVoip()
{
    if (m_voipManager == nullptr || !m_voipManager->IsLoggedIn() ||
        g_program->m_server->m_socketSpawnInfo.serverName.empty() || m_voipManager->IsConnected())
    {
        return;
    }

    KYBER_LOG(Info, "[Client] Joining VoIP");
    g_program->GetAPI()->GetVoip()->JoinChannel(
        g_program->m_server->m_socketSpawnInfo.serverName, [&](std::optional<const VoipJoinChannelResponse*> response) {
            if (!response)
            {
                KYBER_LOG(Error, "[VoIP] Failed to retrieve vivox channel credentials. Proximity chat will not work!");
                return;
            }

            m_voipManager->AddSession((*response)->channel(), (*response)->accesstoken());
        });
}

void Client::JoinServer(const std::string& id, std::string ip, uint16_t port, bool spectate, bool proxied, bool changeState)
{
    if (!id.empty())
    {
        auto server = g_program->GetAPI()->GetServerBrowser()->GetServer(id);
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
    g_program->m_server->m_socketSpawnInfo = info;
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

__int64 ClientCtorHk(__int64 inst, void* a2, __int64 a3)
{
    static const auto trampoline = HookManager::Call(ClientCtorHk);
    KYBER_LOG(Info, "[Client] Creating client");

    if (g_program->m_client->m_voipManager != nullptr)
    {
        g_program->m_client->m_voipManager->Init();
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
    g_program->m_client->m_clientState = currentClientState;
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

        if ((server->m_runningHosted || g_program->m_client->m_connected) && g_program->m_client->m_socketManager)
        {
            // g_program->m_clientSocketManager->CloseSockets();
            g_program->m_client->m_socketManager = nullptr;
        }

        if (g_program->m_client->m_connected)
        {
            KYBER_LOG(Info, "[Client] Leaving server");

            if (g_program->m_client->m_voipManager != nullptr)
            {
                g_program->m_client->m_voipManager->RemoveSession();
            }

            g_program->m_client->m_spectator = false;
        }

        g_program->m_client->m_connected = false;

        if (server->m_runningHosted)
        {
            if (!server->m_restarting)
            {
                KYBER_LOG(Info, "[Server] Stopping server");
                server->Stop();

                if (g_program->m_client->m_voipManager != nullptr)
                {
                    g_program->m_client->m_voipManager->RemoveSession();
                }

                g_program->m_client->m_spectator = false;

                GameSettings* gameSettings = Settings<GameSettings>("Game");
                gameSettings->Level = const_cast<char*>(StringUtils::CopyWithArena("Levels/FrontEnd/FrontEnd"));
                gameSettings->DefaultLayerInclusion = const_cast<char*>(StringUtils::CopyWithArena(""));
            }
            else
            {
                server->m_restarting = false;
            }
        }
        else if (!g_program->m_client->m_joining && !firstStartup)
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
        g_program->m_client->HandleClientServerJoin(msg);
    }
    trampoline(inst, message);
}

bool ClientInitNetworkHk(__int64 inst, bool singleplayer, bool localhost, bool coop, bool hosted)
{
    static const auto trampoline = HookManager::Call(ClientInitNetworkHk);
    KYBER_LOG(Info, "[Client] Client is initializing network, singleplayer: " << singleplayer);
    if (g_program->m_server->m_runningHosted || strlen(Settings<ClientSettings>("Client")->ServerIp) > 0)
    {
        *reinterpret_cast<void**>(inst + 0xA8) =
            reinterpret_cast<void*>(new SocketManagerCreator(&g_program->m_client->m_socketManager, g_program->m_server->m_socketSpawnInfo));
        KYBER_LOG(Info, "[Client] Using custom socket manager");
    }
    return trampoline(inst, singleplayer, localhost, coop, hosted);
}

void ClientConnectToAddressHk(__int64 inst, const char* ipAddress, const char* serverPassword)
{
    static const auto trampoline = HookManager::Call(ClientConnectToAddressHk);
    SocketSpawnInfo info = g_program->m_server->m_socketSpawnInfo;
    if (false && g_program->m_client->m_joining && info.isProxied)
    {
        KYBER_LOG(Info, "[Client] Connecting to server (proxied)");
        trampoline(inst, (std::string(info.proxyAddress) + ":25201").c_str(), serverPassword);
    }
    else
    {
        KYBER_LOG(Info, "[Client] Connecting to server " << ipAddress);
        trampoline(inst, ipAddress, serverPassword);
    }

    if (g_program->m_client->m_joining)
    {
        g_program->m_client->m_connected = true;
        g_program->m_client->m_joining = false;
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

__int64 ClientUpdatePassPreFrameHk(void* inst, const UpdateParameters& params)
{
    static const auto trampoline = HookManager::Call(ClientUpdatePassPreFrameHk);
    __int64 result = trampoline(inst, params);

    if (g_program->m_entityManager != nullptr)
    {
        g_program->m_entityManager->UpdateEntities(Realm_Client, params);
    }

    for (const auto& listener : g_program->m_client->m_updatePassListeners)
    {
        listener->Call(ClientUpdatePass_PreFrame);
    }

    g_threadExecutor->Process(GameThread_Client);
    g_program->m_client->m_eventManager->ProcessEventQueue();

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

    for (const auto& listener : g_program->m_client->m_updatePassListeners)
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

void Client::OnEvent(const Event& event)
{
    if (event.is<MainLoopInitJoinServerEvent>())
    {
        const auto& e = event.as<MainLoopInitJoinServerEvent>();
        JoinServer(e.id, e.ip, e.port, e.spectate, e.proxied, false);
    }
}

void Client::RegisterClientUpdatePassListener(ClientUpdatePassListener* listener)
{
    m_updatePassListeners.push_back(listener);
}

void Client::Initialize()
{
    InitializeHooks();
}

void Client::InitializeHooks()
{
    // clang-format off
    HookTemplate hookOffsets[] = {
        { HOOK_OFFSET(0x140A8C7A0), ClientStateChangeHk },
        { HOOK_OFFSET(0x140CB7800), ClientConnectionOnDisconnectedHk },
        { HOOK_OFFSET(0x140CBA480), ClientConnectionSendMessageHk },
        { HOOK_OFFSET(0x140A874C0), ClientCtorHk },
        { HOOK_OFFSET(0x1465D9FA0), ClientUpdatePassPreFrameHk },
        { HOOK_OFFSET(0x1465D9C30), ClientUpdatePassPostFrameHk },
        { HOOK_OFFSET(0x1418D92B0), ClientAuthHk },
        { HOOK_OFFSET(0x140A8DE80), ClientInitNetworkHk },
        { HOOK_OFFSET(0x140CB3990), ClientConnectToAddressHk },
        { HOOK_OFFSET(0x140CB3640), OnlineManagerConnectHk },
    };
    // clang-format on

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }

    Hook::ApplyQueuedActions();
    KYBER_LOG(Debug, "[Client] Initialized Client Hooks");
}

} // namespace Kyber
