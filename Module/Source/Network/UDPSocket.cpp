// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Network/UDPSocket.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <Network/SocketManager.h>
#include <Utilities/ErrorUtils.h>
#include <Utilities/PlatformUtils.h>
#include <Utilities/StringUtils.h>

#include <ws2tcpip.h>

#ifdef SIMULATE_OLD_PROXY
    #include <nlohmann/json.hpp>
#endif

namespace Kyber
{
static uint8_t s_proxifyBuffer[3072];

std::string DirectionToString(ProtocolDirection direction)
{
    switch (direction)
    {
    case ProtocolDirection::Serverbound:
        return "Client";
    case ProtocolDirection::Clientbound:
        return "Server";
    }

    return "";
}

UDPSocket::UDPSocket(SocketCreator* creator, ProtocolDirection direction, SocketSpawnInfo info)
    : m_creator(creator)
    , m_socketHandle(INVALID_SOCKET)
    , m_port(0)
    , m_isBroadcasting(false)
    , m_blockingMode(false)
    , m_peerAddressIsValid(false)
    , m_direction(direction)
    , m_info(info)
{
    m_proxyQueue = std::make_shared<WebSocket::ReceiveQueue>();
}

UDPSocket::~UDPSocket() {}

void UDPSocket::Close()
{
    KYBER_LOG(Info, "[" << DirectionToString(m_direction) << "] Closing socket");

    if (m_socketHandle != INVALID_SOCKET)
    {
        shutdown(m_socketHandle, SD_BOTH);
        closesocket(m_socketHandle);
    }

    m_socketHandle = INVALID_SOCKET;
}

uint8_t* ProxifyBuffer(uint8_t* buffer, int& bufferSize, sockaddr* addr)
{
    bufferSize += 2;

    s_proxifyBuffer[0] = ((sockaddr_in*)addr)->sin_port >> 8;
    s_proxifyBuffer[1] = ((sockaddr_in*)addr)->sin_port;
    memcpy(s_proxifyBuffer + 2, buffer, bufferSize - 2);

    return s_proxifyBuffer;
}

bool UDPSocket::Send(uint8_t* buffer, int bufferSize, unsigned int flags)
{
    sockaddr* addr = (sockaddr*)m_peerAddress.Data();

    // KYBER_LOG(Info, "[" << DirectionToString(m_direction) << "] Sending " << bufferSize << " bytes to "
    //                     << inet_ntoa(((sockaddr_in*)addr)->sin_addr) << ":" << ntohs(((sockaddr_in*)addr)->sin_port));

    const char* ip = nullptr;
    if (m_info.isProxied || (m_direction == ProtocolDirection::Clientbound && (ip = inet_ntoa(((sockaddr_in*)addr)->sin_addr)) &&
                                strstr(ip, "0.1.1.") != nullptr))
    {
        int proxyIndex = 0;

        bool proxify = m_direction == ProtocolDirection::Clientbound;
        if (proxify)
        {
            buffer = ProxifyBuffer(buffer, bufferSize, addr);

            const char* finalSection = ip + 6;
            proxyIndex = atoi(finalSection);

            if (proxyIndex < 0 || proxyIndex >= m_sockets.size())
            {
                KYBER_LOG(Error, "Invalid proxy index: " << proxyIndex);
                return false;
            }
        }

        bool success = m_sockets[proxyIndex].Send(buffer, bufferSize);
        if (!success)
        {
            // We are probably connecting or reconnecting, so we can just tell the engine this
            // was successful. It's built for UDP, so it'll handle the packet loss for us.

            // In the future, if it becomes a problem, it may be worth implementing a timeout for
            // proxy reconnections, and letting the client bail if things aren't working.
            return true;
        }
        
        return true;
    }

    if (sendto(m_socketHandle, reinterpret_cast<const char*>(buffer), bufferSize, 0, addr, sizeof(sockaddr_in)) < 0)
    {
        int error = WSAGetLastError();
        if (error != WSAEWOULDBLOCK)
        {
            KYBER_LOG(Error, "[" << DirectionToString(m_direction) << "] Failed to send data: " << error);
            return false;
        }

        return true;
    }

#ifdef _DEBUG
    KYBER_LOG(Trace, "[" << DirectionToString(m_direction) << "] Sent " << bufferSize << " bytes");
#endif

    return true;
}

int UDPSocket::ReceiveFrom(uint8_t* buffer, int bufferSize)
{
    int addressSize = sizeof(sockaddr_in);
    sockaddr_in addr = *(sockaddr_in*)m_peerAddress.Data();

    // KYBER_LOG(Info, "[" << DirectionToString(m_direction) << "] Receiving data");

    int proxyId = -1;
    int recvSize = 0;

    std::optional<WebSocketMessage> data = m_proxyQueue->tryDequeue();
    if (data)
    {
        recvSize = std::min(bufferSize, static_cast<int>(data->size));
        memcpy(buffer, data->data, recvSize);

        proxyId = data->socketId;
    }
    else if (m_socketHandle != INVALID_SOCKET)
    {
        recvSize = recvfrom(m_socketHandle, (char*)buffer, bufferSize, 0, (sockaddr*)&addr, &addressSize);
        if (recvSize < 0)
        {
            int error = WSAGetLastError();
            if (error != WSAEWOULDBLOCK)
            {
                KYBER_LOG(Debug, "Error receiving data: " << error);
            }

            return recvSize;
        }
    }
    else
    {
        KYBER_LOG(Error, "Invalid socket handle");
        return -1;
    }

    if (proxyId != -1 && m_direction == ProtocolDirection::Clientbound)
    {
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr(("0.1.1." + std::to_string(proxyId)).c_str());
        addr.sin_port = buffer[0] << 8 | buffer[1];

        std::memmove(buffer, buffer + 2, recvSize - 2);
        recvSize -= 2;
    }

    if (proxyId == -1 || m_direction != ProtocolDirection::Serverbound)
    {
        m_peerAddress.SetData(&addr, sizeof(sockaddr_in));
        m_peerAddressIsValid = true;
    }

    // KYBER_LOG(Info, "[" << DirectionToString(m_direction) << "] Received " << recvSize << " bytes from " << inet_ntoa(addr.sin_addr) <<
    // ":"
    //                     << ntohs(addr.sin_port));


#ifdef _DEBUG
    KYBER_LOG(Trace, "[" << DirectionToString(m_direction) << "] Received " << recvSize << " bytes");
#endif

    return recvSize;
}

int ISocket::ReceiveFromWhen(uint8_t* buffer, int maxSize, unsigned int& receivedWhen)
{
    receivedWhen = 0;
    return ReceiveFrom(buffer, maxSize);
}

bool UDPSocket::Listen(const SocketAddr& address, bool blocking)
{
    m_socketHandle = INVALID_SOCKET;

    sockaddr_in* addr = (sockaddr_in*)address.Data();
    if ((m_socketHandle = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == INVALID_SOCKET)
    {
        KYBER_LOG(Error, "Failed to create socket (" << WSAGetLastError() << ")");
        return false;
    }

    if (bind(m_socketHandle, (sockaddr*)addr, sizeof(sockaddr_in)) != 0)
    {
        Close();
        KYBER_LOG(Error, "Failed to bind socket (" << WSAGetLastError() << ")");
        return false;
    }

    if (!SetBlockingMode(blocking))
    {
        Close();
        KYBER_LOG(Error, "Failed to set blocking mode of socket");
        return false;
    }

    m_port = ntohs(addr->sin_port);
    m_address = address;

    KYBER_LOG(Trace, "Created listening socket");

    m_sockets.clear();

    if (m_info.isProxied && m_direction == ProtocolDirection::Serverbound)
    {
        m_sockets.push_back(WebSocket("client", 0, m_proxyQueue));
        m_sockets.back().ConnectAsClient(m_info.proxyAddress, g_program->m_client->m_joinToken);
    }
    else if (m_direction == ProtocolDirection::Clientbound && g_program->m_server->IsRunning() && g_program->m_server->m_onlineMode)
    {
        const char* pinnedProxy = std::getenv("KYBER_PINNED_PROXY");
        if (pinnedProxy != nullptr)
        {
            m_sockets.push_back(WebSocket("pinned", 0, m_proxyQueue));
            m_sockets.back().ConnectAsServer(pinnedProxy, g_program->m_client->m_joinToken);
        }
        else
        {
            auto proxies = g_program->GetAPI()->GetProxy()->GetList();
            m_sockets.reserve(proxies.size());

            uint32_t id = 0;
            for (const auto& proxy : proxies)
            {
                m_sockets.push_back(WebSocket(proxy.id(), id++, m_proxyQueue));
                m_sockets.back().ConnectAsServer(proxy.ip(), g_program->m_client->m_joinToken);
            }
        }
    }

    return true;
}

bool UDPSocket::Connect(const SocketAddr& address, bool blocking)
{
    return false;
}

bool UDPSocket::Create(bool blocking)
{
    return false;
}

bool UDPSocket::SetBlockingMode(bool blocking)
{
    m_blockingMode = blocking;
    if (m_socketHandle == INVALID_SOCKET)
    {
        return true;
    }

    u_long mode = blocking ? 0 : 1;
    if (ioctlsocket(m_socketHandle, FIONBIO, &mode) == SOCKET_ERROR)
    {
        return false;
    }

    int bufferSize = 600000;
    if (setsockopt(m_socketHandle, SOL_SOCKET, SO_SNDBUF, (char*)&bufferSize, sizeof(bufferSize)) == SOCKET_ERROR)
    {
        return false;
    }

    if (setsockopt(m_socketHandle, SOL_SOCKET, SO_RCVBUF, (char*)&bufferSize, sizeof(bufferSize)) == SOCKET_ERROR)
    {
        return false;
    }

    return true;
}

void UDPSocket::SetPeerAddress(const SocketAddr& address)
{
    m_peerAddress = address;
    m_peerAddressIsValid = true;
}

SocketAddr UDPSocket::PeerAddress() const
{
    return m_peerAddress;
}

bool UDPSocket::SetBroadcast(uint16_t port)
{
    KYBER_LOG(Trace, "Setting broadcast port to " << port);
    return false;
}

bool UDPSocket::BlockingMode() const
{
    return false;
}

intptr_t UDPSocket::NativeSocket() const
{
    return m_socketHandle;
}

int UDPSocket::Port() const
{
    return m_port;
}

const SocketAddr* UDPSocket::Address() const
{
    return &m_address;
}

bool UDPSocket::SetDefaultPacketInfo(PacketInfo* info)
{
    if (!info)
    {
        KYBER_LOG(Error, "Invalid packet info");
        return false;
    }

    info->minSize = 1;
    info->maxSize = 1264;
    info->recommendedSize = info->maxSize;
    info->overheadWhenAligned = 28;
    info->alignment = 1;
    return true;
}
} // namespace Kyber
