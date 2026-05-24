// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <winsock2.h>
#include <ws2tcpip.h>

#include <Network/LanBeacon.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <Core/Server.h>
#include <Network/LanNetworkInterfaces.h>

#include <nlohmann/json.hpp>

#include <chrono>
#include <sstream>

namespace Kyber
{
namespace
{
constexpr int kDiscoveryPort = 25201;
constexpr size_t kRecommendedBeaconPayloadSize = 1400;
constexpr auto kBeaconInterval = std::chrono::seconds(3);
constexpr char kLanBeaconMagic[] = { 'K', 'Y', 'B', 'R' };
constexpr size_t kLanBeaconMagicSize = sizeof(kLanBeaconMagic);

std::string FormatEndpoint(const LanIpv4Endpoint& endpoint)
{
    char localAddress[INET_ADDRSTRLEN]{};
    char broadcastAddress[INET_ADDRSTRLEN]{};
    inet_ntop(AF_INET, &endpoint.address, localAddress, sizeof(localAddress));
    inet_ntop(AF_INET, &endpoint.broadcast, broadcastAddress, sizeof(broadcastAddress));
    return std::string(localAddress) + " -> " + broadcastAddress + " (" + endpoint.adapterName + ")";
}

bool SendBeaconPayload(const std::string& payload, const LanIpv4Endpoint& endpoint)
{
    SOCKET socketHandle = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (socketHandle == INVALID_SOCKET)
    {
        KYBER_LOG(Warning, "[LAN] Failed to create LAN beacon socket: " << WSAGetLastError());
        return false;
    }

    BOOL enabled = TRUE;
    if (setsockopt(socketHandle, SOL_SOCKET, SO_BROADCAST, reinterpret_cast<const char*>(&enabled), sizeof(enabled)) == SOCKET_ERROR)
    {
        KYBER_LOG(Warning, "[LAN] Failed to enable LAN beacon broadcast: " << WSAGetLastError());
        closesocket(socketHandle);
        return false;
    }

    sockaddr_in bindAddress{};
    bindAddress.sin_family = AF_INET;
    bindAddress.sin_addr = endpoint.address;
    bindAddress.sin_port = 0;
    if (bind(socketHandle, reinterpret_cast<sockaddr*>(&bindAddress), sizeof(bindAddress)) == SOCKET_ERROR)
    {
        KYBER_LOG(Warning, "[LAN] Failed to bind LAN beacon socket to " << FormatEndpoint(endpoint) << ": " << WSAGetLastError());
        closesocket(socketHandle);
        return false;
    }

    sockaddr_in destination{};
    destination.sin_family = AF_INET;
    destination.sin_addr = endpoint.broadcast;
    destination.sin_port = htons(kDiscoveryPort);

    const int sent = sendto(
        socketHandle,
        payload.c_str(),
        static_cast<int>(payload.size()),
        0,
        reinterpret_cast<sockaddr*>(&destination),
        sizeof(destination));
    closesocket(socketHandle);

    if (sent == SOCKET_ERROR)
    {
        KYBER_LOG(Warning, "[LAN] Failed to send LAN beacon on " << FormatEndpoint(endpoint) << ": " << WSAGetLastError());
        return false;
    }

    return true;
}
} // namespace

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
    nlohmann::json mods = nlohmann::json::array();
    for (const auto& mod : g_program->m_modData.serverMods)
    {
        mods.push_back({
            { "name", mod.name() },
            { "version", mod.version() },
        });
    }

    nlohmann::json payload = {
        { "type", "kyber_lan_server" },
        { "name", info.name.empty() ? "LAN Server" : info.name },
        { "port", port },
        { "maxPlayers", info.maxPlayers },
        { "requiresPassword", !info.password.empty() },
        { "mods", mods },
        { "levelSetup",
            {
                { "map", info.level },
                { "mode", info.mode },
            } },
    };

    const std::string jsonPayload = payload.dump();
    const size_t totalPayloadSize = kLanBeaconMagicSize + jsonPayload.size();
    if (totalPayloadSize > kRecommendedBeaconPayloadSize)
    {
        KYBER_LOG(
            Warning,
            "[LAN] Beacon payload is "
                << totalPayloadSize
                << " bytes (recommended max "
                << kRecommendedBeaconPayloadSize
                << "). Some networks may drop or fragment the discovery packet. Prefer collapsed mod collections in serverMods.");
    }
    std::string finalPayload;
    finalPayload.reserve(kLanBeaconMagicSize + jsonPayload.size());
    finalPayload.append(kLanBeaconMagic, kLanBeaconMagicSize);
    finalPayload.append(jsonPayload);
    return finalPayload;
}

void LanBeacon::Run(std::string payload)
{
    KYBER_LOG(Info, "[LAN] Starting LAN beacon on UDP " << kDiscoveryPort);

    std::string lastTargetSummary;
    while (m_running.load())
    {
        const std::vector<LanIpv4Endpoint> targets = EnumerateLanBroadcastTargets();
        if (targets.empty())
        {
            KYBER_LOG(Warning, "[LAN] No eligible LAN interfaces for beacon (set KYBER_LAN_INCLUDE_VIRTUAL=1 to include virtual adapters)");
        }
        else
        {
            std::ostringstream summary;
            for (size_t index = 0; index < targets.size(); ++index)
            {
                if (index > 0)
                {
                    summary << "; ";
                }
                summary << FormatEndpoint(targets[index]);
            }

            const std::string targetSummary = summary.str();
            if (targetSummary != lastTargetSummary)
            {
                KYBER_LOG(Info, "[LAN] Beacon targets: " << targetSummary);
                lastTargetSummary = targetSummary;
            }

            for (const LanIpv4Endpoint& target : targets)
            {
                SendBeaconPayload(payload, target);
            }
        }

        std::unique_lock<std::mutex> lock(m_mutex);
        m_condition.wait_for(lock, kBeaconInterval, [this] { return !m_running.load(); });
    }

    KYBER_LOG(Info, "[LAN] Stopped LAN beacon");
}
} // namespace Kyber
