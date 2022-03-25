// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Network/SocketManager.h>
#include <SDK/SDK.h>
#include <SDK/TypeInfo.h>

#include <Windows.h>
#include <string>

#define OFFSET_SERVERGAMECONTEXT_INSTANCE 0x143EC7238

namespace Kyber
{
void ServerPlayerSetTeamIdHk(ServerPlayer* inst, int teamId);
void ServerPlayerLeaveIngameHk(ServerPlayer* inst);
void ServerPlayerDisconnectHk(ServerPlayer* inst, __int64 reason, const std::string& reasonText);
void ServerPeerDeleteConnectionHk(__int64 inst, __int64 serverConnection, __int64 reason, char* reasonText);
__int64 ServerPeerConnectionForPlayerHk(__int64 inst, ServerPlayer* player);
void ServerConnectionDisconnectHk(__int64 inst, __int64 reason, char* reasonText);
void ServerConnectionKickPlayerHk(__int64 inst, __int64 reason, const std::string& reasonText);
void ServerPlayerManagerDeletePlayerHk(ServerPlayerManager* inst, ServerPlayer* player);

class Server
{
public:
    Server();
    ~Server();

    DWORD WINAPI PortForwardingThread();
    void InitializeGameHooks();
    void EnableGameHooks();
    void DisableGameHooks();
    void InitializeGamePatches();
    void InitializeGameSettings();

    void Start(const char* level, const char* mode, int maxPlayers, SocketSpawnInfo info);
    void Stop();

    void SetPlayerTeam(ServerPlayer* player, int teamId)
    {
        return ServerPlayerSetTeamIdHk(player, teamId);
    }

    __int64 GetServerGameContext()
    {
        return *reinterpret_cast<__int64*>(OFFSET_SERVERGAMECONTEXT_INSTANCE);
    }

    void KickPlayer(ServerPlayer* player, char* reason)
    {
        __int64 serverPeer = *reinterpret_cast<__int64*>(GetServerGameContext() + 0x60);
        __int64 serverConnection = ServerPeerConnectionForPlayerHk(serverPeer, player);
        ServerConnectionKickPlayerHk(serverConnection, SecureReason_KickedByAdmin, std::string(reason));
    }

    SocketManager* m_socketManager;
    ISocket* m_natClient;
    ServerPlayerManager* m_playerManager;
    SocketSpawnInfo m_socketSpawnInfo;
    __int64 m_serverInstance;
    bool m_running;
    bool m_hooksRemoved;
};
} // namespace Kyber