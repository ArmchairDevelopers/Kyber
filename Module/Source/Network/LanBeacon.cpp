// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <winsock2.h>
#include <ws2tcpip.h>

#include <Network/LanBeacon.h>

#include <Base/Log.h>
#include <Core/Server.h>

#include <nlohmann/json.hpp>

#include <chrono>

namespace Kyber
{
namespace
{
constexpr int kDiscoveryPort = 25201;
constexpr auto kBeaconInterval = std::chrono::seconds(3);
}

LanBeacon::LanBeacon()
    : m_running(false)
{}

LanBeacon::~LanBeacon()
{
    Stop();
}

void LanBeacon::Start(const ServerCreationInfo& info, int port)
{
    Stop();

    m_running = true;
    m_thread = std::thread(&LanBeacon::Run, this, BuildPayload(info, port));
}

void LanBeacon::Stop()
{
    bool wasRunning = m_running.exchange(false);
    if (wasRunning)
    {
        m_condition.notify_all();
    }
    if (m_thread.joinable())
    {
        m_thread.join();
    }
}

std::string LanBeacon::BuildPayload(const ServerCreationInfo& info, int port) const
{
    nlohmann::json payload = {
        { "type", "kyber_lan_server" },
        { "name", info.name.empty() ? "LAN Server" : info.name },
        { "port", port },
        { "maxPlayers", info.maxPlayers },
        { "requiresPassword", !info.password.empty() },
        { "mods", nlohmann::json::array() },
        { "levelSetup",
            {
                { "map", info.level },
                { "mode", info.mode },
            } },
    };

    return payload.dump();
}

void LanBeacon::Run(std::string payload)
{
    SOCKET socketHandle = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (socketHandle == INVALID_SOCKET)
    {
        KYBER_LOG(Error, "[LAN] Failed to create LAN beacon socket: " << WSAGetLastError());
        m_running = false;
        return;
    }

    BOOL enabled = TRUE;
    if (setsockopt(socketHandle, SOL_SOCKET, SO_BROADCAST, reinterpret_cast<const char*>(&enabled), sizeof(enabled)) == SOCKET_ERROR)
    {
        KYBER_LOG(Error, "[LAN] Failed to enable LAN beacon broadcast: " << WSAGetLastError());
        closesocket(socketHandle);
        m_running = false;
        return;
    }

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_port = htons(kDiscoveryPort);
    address.sin_addr.s_addr = INADDR_BROADCAST;

    KYBER_LOG(Info, "[LAN] Starting LAN beacon on UDP " << kDiscoveryPort);

    while (m_running)
    {
        int sent = sendto(
            socketHandle,
            payload.c_str(),
            static_cast<int>(payload.size()),
            0,
            reinterpret_cast<sockaddr*>(&address),
            sizeof(address));
        if (sent == SOCKET_ERROR)
        {
            KYBER_LOG(Warning, "[LAN] Failed to send LAN beacon: " << WSAGetLastError());
        }

        std::unique_lock<std::mutex> lock(m_mutex);
        m_condition.wait_for(lock, kBeaconInterval, [this] { return !m_running; });
    }

    closesocket(socketHandle);
    KYBER_LOG(Info, "[LAN] Stopped LAN beacon");
}
} // namespace Kyber
