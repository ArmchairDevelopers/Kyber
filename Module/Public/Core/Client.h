// Copyright Armchair Developers. Licensed under GPLv3.

#pragma once

#include <SDK/SDK.h>
#include <SDK/TypeInfo.h>
#include <SDK/Types.h>
#include <Core/EventManager.h>
#include <Network/SocketManager.h>
#include <Voip/VoipManager.h>

#define OFFSET_GET_CLIENT_INSTANCE 0x14659DE50

namespace Kyber
{
__int64 ClientStateChangeHk(__int64 a1, ClientState currentClientState, ClientState lastClientState);

class Client : public EventListener
{
public:
    Client();
    ~Client();

    void Initialize();
    void InitializeHooks();

    void HandleClientServerJoin(NetworkCreatePlayerMessage* message);
    void RegisterClientUpdatePassListener(ClientUpdatePassListener* listener);
    void AttemptJoinVoip();

    // If proxied is true, IP is assumed to be a proxy ID
    void JoinServer(const std::string& id, std::string ip, uint16_t port, bool spectate, bool proxied = false, bool changeState = true);

    __int64 ChangeClientState(ClientState currentClientState)
    {
        return ClientStateChangeHk(
            *reinterpret_cast<__int64*>(*reinterpret_cast<__int64*>(((__int64 (*)(void))OFFSET_GET_CLIENT_INSTANCE)() + 0x20) + 0x28),
            currentClientState, m_clientState);
    }

    void OnEvent(const Event& event) override;

    std::string m_joinToken;

    ClientState m_clientState;

    SocketManager* m_socketManager;
    VoipManager* m_voipManager;
    EventManager* m_eventManager;

    std::vector<ClientUpdatePassListener*> m_updatePassListeners;

    bool m_joining;
    bool m_spectator;
    bool m_connected;
};
} // namespace Kyber