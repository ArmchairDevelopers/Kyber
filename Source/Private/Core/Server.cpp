// Copyright BattleDash. All Rights Reserved.

#define _WINSOCKAPI_
#include <Core/Server.h>

#include <Core/Program.h>
#include <Hook/HookManager.h>
#include <Base/Log.h>
#include <Utilities/ErrorUtils.h>
#include <Utilities/MemoryUtils.h>
#include <Utilities/PlatformUtils.h>
#include <SDK/TypeInfo.h>
#include <SDK/SDK.h>

#include <ws2tcpip.h>
#include <iomanip>
#include <iostream>
#include <minhook/MinHook.h>
#include <sstream>
#include <stdio.h>
#include <thread>

#define OFFSET_SERVER_CONSTRUCTOR HOOK_OFFSET(0x140BC6370)
#define OFFSET_SERVER_START HOOK_OFFSET(0x140BD17E0)

#define OFFSET_SERVERPLAYER_SETTEAMID HOOK_OFFSET(0x140BE9C10)
#define OFFSET_SERVERPLAYER_LEAVEINGAME HOOK_OFFSET(0x146876310)
#define OFFSET_SERVERPLAYER_DISCONNECT HOOK_OFFSET(0x140BDDBE0)

#define OFFSET_SERVERPEER_DELETECONNECTION HOOK_OFFSET(0x140D5C9A0)
#define OFFSET_SERVERPEER_CONNECTIONFORPLAYER HOOK_OFFSET(0x140BEFFB0)

#define OFFSET_SERVERCONNECTION_DISCONNECT HOOK_OFFSET(0x140BF01D0)
#define OFFSET_SERVERCONNECTION_KICKPLAYER HOOK_OFFSET(0x14688DB50)

#define OFFSET_SERVERPLAYERMANAGER_DELETEPLAYER HOOK_OFFSET(0x140BDD950)

#define OFFSET_APPLY_SETTINGS HOOK_OFFSET(0x1401B31B0)
#define OFFSET_CLIENT_INIT_NETWORK HOOK_OFFSET(0x140A8DE80)
#define OFFSET_CLIENT_CONNECTTOADDRESS HOOK_OFFSET(0x140CB3990)

#define OFFSET_SERVER_PATCH 0x140A92F71

namespace Kyber
{
Server::Server()
    : m_socketSpawnInfo(SocketSpawnInfo(false, "", ""))
    , m_socketManager(new SocketManager(ProtocolDirection::Clientbound, SocketSpawnInfo(false, "", "")))
    , m_natClient(nullptr)
    , m_playerManager(nullptr)
    , m_running(false)
    , m_hooksRemoved(false)
    , m_serverInstance(0)
{
    InitializeGameHooks();
    DisableGameHooks();
    InitializeGamePatches();

    // new std::thread(&Server::PortForwardingThread, this);
}

Server::~Server()
{
    KYBER_LOG(LogLevel::Debug, "Destroying Server");
}

// NAT Punch-Through using https://github.com/BattleDash/Kyber/blob/main/NATServer
DWORD WINAPI Server::PortForwardingThread()
{
    int port = 10001;
    while (!m_natClient)
    {
        m_natClient = m_socketManager->Listen((":" + std::to_string(port)).c_str(), false);
    }

    // My own hosted instance of Kyber/NATServer
    m_natClient->SetPeerAddress(SocketAddr("65.108.70.186", 10000));

    while (1)
    {
        if (this == nullptr || m_natClient == nullptr)
        {
            break;
        }
        uint8_t* buffer = new uint8_t[1600];
        int length = m_natClient->ReceiveFrom(buffer, 1600);
        if (length > 0)
        {
            KYBER_LOG(LogLevel::Debug, "Received packet: " << reinterpret_cast<char*>(buffer));
            if (m_running)
            {
                // Send an empty packet to the client that wants to connect, to make the router accept the connection
                ISocket* client = m_socketManager->m_sockets.back();
                client->SetPeerAddress(SocketAddr(reinterpret_cast<char*>(buffer), 25100));
                client->Send(buffer, 1);
                KYBER_LOG(LogLevel::Debug, "Sent NAT packet");
            }
        }
        // Keep alive
        m_natClient->Send(reinterpret_cast<uint8_t*>(" "), 1);
        delete[] buffer;
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }

    return 0;
}

void Server::Start(const char* level, const char* mode, int maxPlayers, SocketSpawnInfo info)
{
    EnableGameHooks();

    NetworkSettings* networkSettings = Settings<NetworkSettings>("Network");
    networkSettings->MaxClientCount = maxPlayers;
    networkSettings->ServerPort = 25200;

    NetObjectSystemSettings* netObjectSettings = Settings<NetObjectSystemSettings>("NetObjectSystem");
    netObjectSettings->MaxServerConnectionCount = maxPlayers;

    ClientSettings* clientSettings = Settings<ClientSettings>("Client");
    clientSettings->FastExit = true;
    clientSettings->ServerIp = "";

    GameSettings* gameSettings = Settings<GameSettings>("Game");
    gameSettings->Level = const_cast<char*>(level);

    char* gameMode = new char[strlen(mode) + 11];
    strcpy_s(gameMode, strlen(mode) + 11, "GameMode=");
    strcat_s(gameMode, strlen(mode) + 11, mode);
    gameSettings->DefaultLayerInclusion = gameMode;

    m_socketSpawnInfo = info;
    g_program->ChangeClientState(ClientState_Startup);

    m_running = true;
    m_hooksRemoved = false;
}

__int64 ServerCtorHk(__int64 inst, ServerSpawnInfo& info, SocketManager* socketManager)
{
    static const auto trampoline = HookManager::Call(ServerCtorHk);
    info.isLocalHost = false;
    g_program->m_server->m_playerManager = info.playerManager;
    if (info.playerManager)
    {
        KYBER_LOG(LogLevel::Debug, "PlayerManager: 0x" << std::hex << info.playerManager);
    }
    g_program->m_server->m_serverInstance = inst;
    return trampoline(inst, info, socketManager);
}

__int64 ServerStartHk(__int64 inst, ServerSpawnInfo& info, __int64 spawnOverrides, SocketManager* socketManager)
{
    static const auto trampoline = HookManager::Call(ServerStartHk);
    Server* server = g_program->m_server;
    socketManager = server->m_socketManager;
    socketManager->m_info = server->m_socketSpawnInfo;
    return trampoline(inst, info, spawnOverrides, socketManager);
}

__int64 SettingsManagerApplyHk(__int64 inst, __int64* a2, char* script, BYTE* a4)
{
    static const auto trampoline = HookManager::Call(SettingsManagerApplyHk);
    Server* server = g_program->m_server;
    if (server->m_running && !server->m_hooksRemoved)
    {
        server->m_hooksRemoved = true;
        server->DisableGameHooks();
    }
    KYBER_LOG(LogLevel::DebugPlusPlus, "SettingsManagerApplyHk(" << script << ")");
    if (strstr(script, "InstallationLevel"))
    {
        return 0;
    }
    return trampoline(inst, a2, script, a4);
}

bool ClientInitNetworkHk(__int64 inst, bool singleplayer, bool localhost, bool coop, bool hosted)
{
    static const auto trampoline = HookManager::Call(ClientInitNetworkHk);
    if (g_program->m_server->m_running || strlen(Settings<ClientSettings>("Client")->ServerIp) > 0)
    {
        *reinterpret_cast<__int64*>(inst + 0xA8) =
            reinterpret_cast<__int64>(new SocketManagerCreator(g_program->m_server->m_socketSpawnInfo));
    }
    return trampoline(inst, singleplayer, localhost, coop, hosted);
}

void ClientConnectToAddressHk(__int64 inst, const char* ipAddress, const char* serverPassword)
{
    static const auto trampoline = HookManager::Call(ClientConnectToAddressHk);
    SocketSpawnInfo info = g_program->m_server->m_socketSpawnInfo;
    if (info.isProxied)
    {
        trampoline(inst, (std::string(info.proxyAddress) + ":25200").c_str(), serverPassword);
    }
    else
    {
        trampoline(inst, ipAddress, serverPassword);
    }
}

void ServerPlayerSetTeamIdHk(ServerPlayer* inst, int teamId)
{
    static const auto trampoline = HookManager::Call(ServerPlayerSetTeamIdHk);
    trampoline(inst, teamId);
}

void ServerPlayerLeaveIngameHk(ServerPlayer* inst)
{
    static const auto trampoline = HookManager::Call(ServerPlayerLeaveIngameHk);
    KYBER_LOG(LogLevel::Debug, "ServerPlayerLeaveIngame called");
    trampoline(inst);
}

void ServerPlayerDisconnectHk(ServerPlayer* inst, __int64 reason, const std::string& reasonText)
{
    static const auto trampoline = HookManager::Call(ServerPlayerDisconnectHk);
    KYBER_LOG(LogLevel::Debug, "ServerPlayerDisconnect called 0x" << reason << " 0x" << reasonText.c_str());
    trampoline(inst, reason, reasonText);
}

void ServerPeerDeleteConnectionHk(__int64 inst, __int64 serverConnection, __int64 reason, char* reasonText)
{
    static const auto trampoline = HookManager::Call(ServerPeerDeleteConnectionHk);
    KYBER_LOG(LogLevel::Debug, "ServerPeerDeleteConnection called 0x" << reason << " " << reasonText);
    trampoline(inst, serverConnection, reason, reasonText);
}

__int64 ServerPeerConnectionForPlayerHk(__int64 inst, ServerPlayer* player)
{
    static const auto trampoline = HookManager::Call(ServerPeerConnectionForPlayerHk);
    return trampoline(inst, player);
}

void ServerConnectionDisconnectHk(__int64 inst, __int64 reason, char* reasonText)
{
    static const auto trampoline = HookManager::Call(ServerConnectionDisconnectHk);
    KYBER_LOG(LogLevel::Debug, "ServerConnectionDisconnect called 0x" << reason << " " << reasonText);
    trampoline(inst, reason, reasonText);
}

void ServerConnectionKickPlayerHk(__int64 inst, __int64 reason, const std::string& reasonText)
{
    static const auto trampoline = HookManager::Call(ServerConnectionKickPlayerHk);
    KYBER_LOG(LogLevel::Debug, "ServerConnectionKickPlayer called 0x" << reason << " " << reasonText.c_str());
    trampoline(inst, reason, reasonText.c_str());
}

void ServerPlayerManagerDeletePlayerHk(ServerPlayerManager* inst, ServerPlayer* player)
{
    static const auto trampoline = HookManager::Call(ServerPlayerManagerDeletePlayerHk);
    KYBER_LOG(LogLevel::Debug, "ServerPlayerManagerDeletePlayer called");
    trampoline(inst, player);
}

HookTemplate server_hook_offsets[] = {
    { OFFSET_SERVER_CONSTRUCTOR, ServerCtorHk },
    { OFFSET_SERVER_START, ServerStartHk },
    { OFFSET_SERVERPLAYER_SETTEAMID, ServerPlayerSetTeamIdHk },
    { OFFSET_SERVERPLAYER_LEAVEINGAME, ServerPlayerLeaveIngameHk },
    { OFFSET_SERVERPEER_DELETECONNECTION, ServerPeerDeleteConnectionHk },
    { OFFSET_SERVERPEER_CONNECTIONFORPLAYER, ServerPeerConnectionForPlayerHk },
    { OFFSET_SERVERPLAYER_DISCONNECT, ServerPlayerDisconnectHk },
    { OFFSET_SERVERCONNECTION_DISCONNECT, ServerConnectionDisconnectHk },
    { OFFSET_SERVERCONNECTION_KICKPLAYER, ServerConnectionKickPlayerHk },
    { OFFSET_SERVERPLAYERMANAGER_DELETEPLAYER, ServerPlayerManagerDeletePlayerHk },
    { OFFSET_APPLY_SETTINGS, SettingsManagerApplyHk },
    { OFFSET_CLIENT_INIT_NETWORK, ClientInitNetworkHk },
    { OFFSET_CLIENT_CONNECTTOADDRESS, ClientConnectToAddressHk },
};

void Server::InitializeGameHooks()
{
    for (HookTemplate& hook : server_hook_offsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }
    Hook::ApplyQueuedActions();
    KYBER_LOG(LogLevel::Debug, "Initialized Server Hooks");
}

void Server::EnableGameHooks()
{
    HookManager::EnableHook(OFFSET_SERVER_CONSTRUCTOR);
    HookManager::EnableHook(OFFSET_SERVER_START);
    HookManager::EnableHook(HOOK_OFFSET(0x140CB3990));
    Hook::ApplyQueuedActions();
    KYBER_LOG(LogLevel::Debug, "Enabled Server Hooks");
}

void Server::DisableGameHooks()
{
    HookManager::DisableHook(OFFSET_SERVER_CONSTRUCTOR);
    HookManager::DisableHook(OFFSET_SERVER_START);
    HookManager::DisableHook(reinterpret_cast<void*>(0x140CB3990));
    Hook::ApplyQueuedActions();
    KYBER_LOG(LogLevel::Debug, "Disabled Server Hooks");
}

void Server::InitializeGamePatches()
{
    BYTE ptch[] = { 0xB9, 0x01, 0x00, 0x00, 0x00 };
    MemoryUtils::Patch((void*)OFFSET_SERVER_PATCH, (void*)ptch, sizeof(ptch));
    BYTE ptch2[] = { 0x90, 0x90 };
    MemoryUtils::Patch((void*)(OFFSET_SERVER_PATCH + 0x5), (void*)ptch2, sizeof(ptch2));
}

void Server::InitializeGameSettings()
{
    WSGameSettings* wsSettings = Settings<WSGameSettings>("Whiteshark");
    wsSettings->AutoBalanceTeamsOnNeutral = true;

    AutoPlayerSettings* aiSettings = Settings<AutoPlayerSettings>("AutoPlayers");
    aiSettings->AllowSuicide = false;
}

void Server::Stop()
{
    m_running = false;
    m_playerManager = nullptr;
    UDPSocket* socket = m_socketManager->m_sockets.back();
    if (socket != m_natClient)
    {
        m_socketManager->Close(socket);
        socket->Close();
    }
}
} // namespace Kyber
