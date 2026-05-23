// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <winsock2.h>
#include <ws2tcpip.h>

#include <Network/LanNetworkInterfaces.h>

#include <Utilities/PlatformUtils.h>
#include <Utilities/StringUtils.h>

#include <Base/Log.h>

#include <iphlpapi.h>

#include <algorithm>
#include <array>
#include <cwctype>
#include <unordered_map>
#include <vector>

namespace Kyber
{
namespace
{
constexpr ULONG kIfTypeEthernet = 6;
constexpr ULONG kIfTypeWiFi = 71;

bool EnvIncludesVirtualInterfaces()
{
    const std::string value = PlatformUtils::GetEnv("KYBER_LAN_INCLUDE_VIRTUAL", "");
    if (value.empty())
    {
        return false;
    }

    return value == "1" || value == "true" || value == "TRUE" || value == "yes" || value == "YES";
}

std::wstring ToLower(std::wstring value)
{
    for (wchar_t& ch : value)
    {
        ch = static_cast<wchar_t>(std::towlower(ch));
    }

    return value;
}

bool ContainsInsensitive(const std::wstring& haystack, const wchar_t* needle)
{
    return ToLower(haystack).find(needle) != std::wstring::npos;
}

bool MatchesVirtualAdapterName(const std::wstring& friendlyName, const std::wstring& description)
{
    static constexpr std::array<const wchar_t*, 18> kVirtualPatterns = {
        L"wsl",
        L"hyper-v",
        L"vethernet",
        L"docker",
        L"virtualbox",
        L"vmware",
        L"npcap",
        L"tap",
        L"tun",
        L"vpn",
        L"wireguard",
        L"tailscale",
        L"zerotier",
        L"hamachi",
        L"logmein",
        L"radmin",
        L"virtual",
        L"loopback",
    };

    for (const wchar_t* pattern : kVirtualPatterns)
    {
        if (ContainsInsensitive(friendlyName, pattern) || ContainsInsensitive(description, pattern))
        {
            return true;
        }
    }

    return false;
}

bool IsPhysicalIfType(ULONG ifType)
{
    return ifType == kIfTypeEthernet || ifType == kIfTypeWiFi;
}

bool IsApipa(in_addr address)
{
    const uint8_t first = address.S_un.S_un_b.s_b1;
    const uint8_t second = address.S_un.S_un_b.s_b2;
    return first == 169 && second == 254;
}

bool IsLoopback(in_addr address)
{
    return (ntohl(address.S_un.S_addr) >> 24) == 127;
}

in_addr MaskFromPrefixLength(UINT8 prefixLength)
{
    in_addr mask{};
    if (prefixLength == 0 || prefixLength > 32)
    {
        return mask;
    }

    if (prefixLength == 32)
    {
        mask.S_un.S_addr = INADDR_NONE;
        return mask;
    }

    const uint32_t hostMask = static_cast<uint32_t>(0xFFFFFFFFu << (32 - prefixLength));
    mask.S_un.S_addr = htonl(hostMask);
    return mask;
}

bool IsHostOnlyMask(in_addr mask)
{
    return mask.S_un.S_addr == INADDR_NONE;
}

in_addr BroadcastAddress(in_addr address, in_addr mask)
{
    in_addr broadcast{};
    broadcast.S_un.S_addr = address.S_un.S_addr | ~mask.S_un.S_addr;
    return broadcast;
}

uint32_t SubnetKey(in_addr address, in_addr mask)
{
    return address.S_un.S_addr & mask.S_un.S_addr;
}

int InterfacePriority(ULONG ifType)
{
    if (ifType == kIfTypeEthernet)
    {
        return 0;
    }

    if (ifType == kIfTypeWiFi)
    {
        return 1;
    }

    return 2;
}

int AddressClassPriority(in_addr address)
{
    const uint32_t host = ntohl(address.S_un.S_addr);
    const uint8_t first = static_cast<uint8_t>((host >> 24) & 0xFF);
    const uint8_t second = static_cast<uint8_t>((host >> 16) & 0xFF);

    if (first == 192 && second == 168)
    {
        return 0;
    }

    if (first == 10)
    {
        return 1;
    }

    if (first == 172 && second >= 16 && second <= 31)
    {
        return 2;
    }

    return 3;
}

bool IsBetterEndpoint(const LanIpv4Endpoint& candidate, const LanIpv4Endpoint& current)
{
    const int candidateClass = AddressClassPriority(candidate.address);
    const int currentClass = AddressClassPriority(current.address);
    if (candidateClass != currentClass)
    {
        return candidateClass < currentClass;
    }

    const int candidateIf = InterfacePriority(candidate.ifType);
    const int currentIf = InterfacePriority(current.ifType);
    if (candidateIf != currentIf)
    {
        return candidateIf < currentIf;
    }

    return ntohl(candidate.address.S_un.S_addr) < ntohl(current.address.S_un.S_addr);
}

std::string AddressToString(in_addr address)
{
    char buffer[INET_ADDRSTRLEN]{};
    inet_ntop(AF_INET, &address, buffer, sizeof(buffer));
    return buffer;
}

std::vector<LanIpv4Endpoint> CollectEligibleEndpoints()
{
    std::vector<LanIpv4Endpoint> endpoints;
    const bool includeVirtual = EnvIncludesVirtualInterfaces();

    ULONG bufferSize = 0;
    if (GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER, nullptr, nullptr, &bufferSize) !=
        ERROR_BUFFER_OVERFLOW)
    {
        KYBER_LOG(Warning, "[LAN] Failed to query adapter buffer size: " << GetLastError());
        return endpoints;
    }

    std::vector<BYTE> buffer(bufferSize);
    auto* adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(buffer.data());
    const ULONG result = GetAdaptersAddresses(
        AF_INET,
        GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER,
        nullptr,
        adapters,
        &bufferSize);
    if (result != NO_ERROR)
    {
        KYBER_LOG(Warning, "[LAN] Failed to enumerate adapters: " << result);
        return endpoints;
    }

    for (auto* adapter = adapters; adapter != nullptr; adapter = adapter->Next)
    {
        if (adapter->OperStatus != IfOperStatusUp)
        {
            continue;
        }

        if (!includeVirtual)
        {
            if (!IsPhysicalIfType(adapter->IfType))
            {
                continue;
            }
        }
        else if (adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK)
        {
            continue;
        }

        const std::wstring friendlyName = adapter->FriendlyName != nullptr ? adapter->FriendlyName : L"";
        const std::wstring description = adapter->Description != nullptr ? adapter->Description : L"";
        if (!includeVirtual && MatchesVirtualAdapterName(friendlyName, description))
        {
            continue;
        }

        for (auto* unicast = adapter->FirstUnicastAddress; unicast != nullptr; unicast = unicast->Next)
        {
            if (unicast->Address.lpSockaddr == nullptr || unicast->Address.lpSockaddr->sa_family != AF_INET)
            {
                continue;
            }

            const auto* sockaddr = reinterpret_cast<sockaddr_in*>(unicast->Address.lpSockaddr);
            const in_addr address = sockaddr->sin_addr;
            if (IsLoopback(address) || IsApipa(address))
            {
                continue;
            }

            const UINT8 prefixLength = unicast->OnLinkPrefixLength;
            if (prefixLength == 32)
            {
                continue;
            }

            const in_addr mask = MaskFromPrefixLength(prefixLength);
            if (mask.S_un.S_addr == 0 || IsHostOnlyMask(mask))
            {
                continue;
            }

            LanIpv4Endpoint endpoint{};
            endpoint.address = address;
            endpoint.subnetMask = mask;
            endpoint.broadcast = BroadcastAddress(address, mask);
            endpoint.ifType = adapter->IfType;
            endpoint.adapterName = StringUtils::WideToAscii(friendlyName);
            endpoints.push_back(endpoint);
        }
    }

    return endpoints;
}
} // namespace

std::vector<LanIpv4Endpoint> EnumerateLanBroadcastTargets()
{
    const std::vector<LanIpv4Endpoint> endpoints = CollectEligibleEndpoints();
    std::unordered_map<uint32_t, LanIpv4Endpoint> uniqueSubnets;

    for (const LanIpv4Endpoint& endpoint : endpoints)
    {
        const uint32_t key = SubnetKey(endpoint.address, endpoint.subnetMask);
        const auto existing = uniqueSubnets.find(key);
        if (existing == uniqueSubnets.end() || IsBetterEndpoint(endpoint, existing->second))
        {
            uniqueSubnets[key] = endpoint;
        }
    }

    std::vector<LanIpv4Endpoint> targets;
    targets.reserve(uniqueSubnets.size());
    for (const auto& entry : uniqueSubnets)
    {
        targets.push_back(entry.second);
    }

    std::sort(targets.begin(), targets.end(), [](const LanIpv4Endpoint& a, const LanIpv4Endpoint& b) {
        return AddressToString(a.address) < AddressToString(b.address);
    });

    return targets;
}

std::optional<std::string> SelectPreferredLanAddress()
{
    const std::vector<LanIpv4Endpoint> endpoints = CollectEligibleEndpoints();
    if (endpoints.empty())
    {
        return std::nullopt;
    }

    const LanIpv4Endpoint* best = &endpoints.front();
    for (const LanIpv4Endpoint& endpoint : endpoints)
    {
        if (IsBetterEndpoint(endpoint, *best))
        {
            best = &endpoint;
        }
    }

    return AddressToString(best->address);
}
} // namespace Kyber
