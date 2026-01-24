// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Network/SocketManager.h>
#include <SDK/SDK.h>
#include <SDK/TypeInfo.h>
#include <SDK/Types.h>
#include <Core/Settings.h>
#include <Persistence/PersistenceManager.h>
#include <Core/EventManager.h>

#include <Windows.h>
#include <optional>
#include <string>

#define OFFSET_SERVERGAMECONTEXT_INSTANCE 0x143EC7238

namespace Kyber
{
extern void* s_mainLoop;

struct ServerCreationInfo
{
    std::string name;
    std::string description;
    std::string password;

    std::string level;
    std::string mode;
    int maxPlayers;

    // Commands executed on server load
    std::vector<std::string> loadCommands;
};

class ServerPlayerAuthenticatedEvent : public Event
{
public:
    uint64_t userId;

    void* connection;
    NetworkCreatePlayerMessage* message;
};

class MainLoopInitStartServerEvent : public Event
{
public:
    ServerCreationInfo info;
};

class MainLoopInitJoinServerEvent : public Event
{
public:
    std::string id;
    std::string ip;
    uint16_t port;
    std::string password;
    bool spectate;
    bool proxied;
};

struct LoadLevelRequest
{
    std::string level;
    std::string mode;
};

class Server : public EventListener
{
public:
    Server();
    ~Server();

    bool IsRunning();

    void Initialize();
    void InitializeGameHooks();
    void EnableGameHooks();
    void DisableGameHooks();
    void InitializeGamePatches();
    void InitializeGameSettings();
    void OnClientStartup();
    void SendConsoleMessage(const std::string& message);

    void Start(const ServerCreationInfo& info, bool changeState = true);
    void Stop();

    void Heartbeat(const UpdateParameters& params);
    void Register(bool force = false);

    void OnEvent(const Event& event) override;

    void OnSettingsRegistered();
    void OnLevelLoaded();

    ServerGameContext* GetServerGameContext()
    {
        return *reinterpret_cast<ServerGameContext**>(OFFSET_SERVERGAMECONTEXT_INSTANCE);
    }

    void KickPlayer(ServerPlayer* player, const char* reason);
    void LoadNextLevel(const char* level, const char* mode, const char* startPoint = "", const char* initialSubLevel = "",
        bool updateServerBrowser = true);
    void BroadcastMessage(const std::string& message, const std::string& username = "ADMIN", ChatChannel channel = ChatChannel_All);

    void SetDedicatedCreationInfo(const ServerCreationInfo& info);

    // The events in this manager are processed once on MainLoop::init
    EventManager* m_mainLoopInitEventManager;

    SocketManager* m_socketManager;
    ISocket* m_natClient;
    ServerPlayerManager* m_playerManager;
    PersistenceManager* m_persistenceManager;
    SocketSpawnInfo m_socketSpawnInfo;
    MapRotation m_mapRotation;
    std::string m_currentLevel;
    std::string m_currentMode;

    void* m_serverInstance;

    std::optional<ServerCreationInfo> m_creationInfo;
    std::string m_serverId;
    bool m_onlineMode;

    // This means the server is running in Client-As-Server.
    // This isn't true if this is a dedicated server, use Program::m_isDedicatedServer.
    bool m_runningHosted;

    bool m_restarting;
    bool m_hooksRemoved;
    bool m_levelLoaded;
    Mutex<LoadLevelRequest> m_latestLoadLevelRequest;
};
} // namespace Kyber