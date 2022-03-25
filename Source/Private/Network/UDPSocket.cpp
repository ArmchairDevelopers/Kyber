// Copyright BattleDash. All Rights Reserved.

#include <Network/SocketManager.h>

#include <Network/UDPSocket.h>
#include <Utilities/PlatformUtils.h>
#include <Base/Log.h>

#define _WINSOCKAPI_
#include <Windows.h>
#include <ws2tcpip.h>

namespace Kyber
{
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
{}

UDPSocket::~UDPSocket() {}

void UDPSocket::Close()
{
    KYBER_LOG(LogLevel::Debug, "[" << DirectionToString(m_direction) << "] Closing socket");
    if (m_socketHandle != INVALID_SOCKET)
    {
        closesocket(m_socketHandle);
    }

    m_socketHandle = INVALID_SOCKET;
}

void ProxifyBuffer(uint8_t*& buffer, int& bufferSize, sockaddr* addr)
{
	bufferSize += 2;
	uint8_t* proxyBuffer = new uint8_t[bufferSize];
	proxyBuffer[0] = ((sockaddr_in*)addr)->sin_port >> 8;
	proxyBuffer[1] = ((sockaddr_in*)addr)->sin_port;
	for (int i = 0; i < bufferSize - 2; i++)
	{
		proxyBuffer[i + 2] = buffer[i];
	}
    // We don't need to worry about freeing the original buffer here, Frostbite's networking engine does it for us.
    buffer = proxyBuffer;
}

bool UDPSocket::Send(uint8_t* buffer, int bufferSize, unsigned int flags)
{
    sockaddr* addr = (sockaddr*)m_peerAddress.Data();;

    if (m_info.isProxied)
    {
        if (m_direction == ProtocolDirection::Clientbound)
        {
            ProxifyBuffer(buffer, bufferSize, addr);
        }
        addr = (sockaddr*)SocketAddr(m_info.proxyAddress, 25200).Data();
    }

    if (sendto(m_socketHandle, reinterpret_cast<const char*>(buffer), bufferSize, 0, addr, sizeof(sockaddr_in)) < 0)
    {
        int error = WSAGetLastError();
        if (error != WSAEWOULDBLOCK)
        {
            KYBER_LOG(LogLevel::Error, "[" << DirectionToString(m_direction) << "] Failed to send data: " << error);
            return false;
        }
        return true;
    }

    KYBER_LOG(LogLevel::DebugPlusPlus, "[" << DirectionToString(m_direction) << "] Sent " << bufferSize << " bytes");

    return true;
}

int UDPSocket::ReceiveFrom(uint8_t* buffer, int bufferSize)
{
    int addressSize = sizeof(sockaddr_in);
    sockaddr_in addr;

    int recvSize = recvfrom(m_socketHandle, (char*)buffer, bufferSize, 0, (sockaddr*)&addr, &addressSize);
    if (recvSize < 0)
    {
        int error = WSAGetLastError();
        if (error != WSAEWOULDBLOCK)
        {
            KYBER_LOG(LogLevel::Warning, "Error receiving data: " << error);
        }
        return recvSize;
    }

    if (m_info.isProxied && m_direction == ProtocolDirection::Clientbound)
    {
        addr.sin_port = buffer[0] << 8 | buffer[1];
        for (int i = 0; i < bufferSize - 2; i++)
        {
            buffer[i] = buffer[i + 2];
        }
        recvSize -= 2;
    }

    m_peerAddress.SetData(&addr, sizeof(sockaddr_in));
    m_peerAddressIsValid = true;

    KYBER_LOG(LogLevel::DebugPlusPlus, "[" << DirectionToString(m_direction) << "] Received " << recvSize << " bytes");

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
        KYBER_LOG(LogLevel::Error, "Failed to create socket (" << WSAGetLastError() << ")");
        return false;
    }

    if (bind(m_socketHandle, (sockaddr*)addr, sizeof(sockaddr_in)) != 0)
    {
        Close();
        KYBER_LOG(LogLevel::Error, "Failed to bind socket (" << WSAGetLastError() << ")");
        return false;
    }

    if (!SetBlockingMode(blocking))
    {
        Close();
        KYBER_LOG(LogLevel::Error, "Failed to set blocking mode of socket");
        return false;
    }

    m_port = ntohs(addr->sin_port);
    m_address = address;

    KYBER_LOG(LogLevel::DebugPlusPlus, "Created listening socket");

    if (m_info.isProxied)
    {
        KYBER_LOG(LogLevel::Debug, "Proxied socket, sending handshake");
        SendProxyHandshake();
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
    if (m_socketHandle != INVALID_SOCKET)
    {
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
    }

    m_blockingMode = blocking;
    return true;
}

void UDPSocket::SendProxyHandshake()
{
    std::stringstream handshake;
    handshake << "PROXY_HANDSHAKE|";
    handshake << (m_direction == ProtocolDirection::Clientbound ? "SERVER" : "CLIENT") << "|";
    handshake << m_info.serverName << "|";
    handshake << std::getenv("EALaunchEAID") << "|";
    handshake << PlatformUtils::GetFrostyMods();
    std::string str = handshake.str();
    KYBER_LOG(LogLevel::Debug, "Sending handshake: " << str);
    Send(const_cast<uint8_t*>(reinterpret_cast<const uint8_t*>(str.c_str())), str.length());
}

void UDPSocket::SetPeerAddress(const SocketAddr& address)
{
    sockaddr_in* addr = (sockaddr_in*)address.Data();
    KYBER_LOG(LogLevel::DebugPlusPlus, "[" << DirectionToString(m_direction) << "] Setting peer address (" << ntohs(addr->sin_port) << ")");
    m_peerAddress = address;
    m_peerAddressIsValid = true;
}

SocketAddr UDPSocket::PeerAddress() const
{
    return m_peerAddress;
}

bool UDPSocket::SetBroadcast(uint16_t port)
{
    KYBER_LOG(LogLevel::DebugPlusPlus, "Setting broadcast port to " << port);
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
        KYBER_LOG(LogLevel::Error, "Invalid packet info");
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