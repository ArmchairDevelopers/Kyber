// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <optional>
#include <string>
#include <vector>

#include <winsock2.h>

namespace Kyber
{
struct LanIpv4Endpoint
{
    in_addr address{};
    in_addr subnetMask{};
    in_addr broadcast{};
    ULONG ifType = 0;
    std::string adapterName;
};

// One broadcast target per IPv4 subnet (Ethernet preferred over Wi-Fi on the same subnet).
std::vector<LanIpv4Endpoint> EnumerateLanBroadcastTargets();

// Best local IPv4 for display / join hints (aligned with broadcast interface selection).
std::optional<std::string> SelectPreferredLanAddress();
} // namespace Kyber
