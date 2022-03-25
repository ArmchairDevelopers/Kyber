// Copyright BattleDash. All Rights Reserved.

#include <Network/SocketManager.h>

#include <Network/UDPSocket.h>
#include <Base/Log.h>

#define _WINSOCKAPI_
#include <Windows.h>
#include <ws2tcpip.h>
#include <string>
#include <algorithm>

namespace Kyber
{
SocketManager::SocketManager(ProtocolDirection direction, SocketSpawnInfo info)
    : m_sockets()
    , m_direction(direction)
    , m_info(info)
{
    KYBER_LOG(LogLevel::Debug, "Created new SocketManager");
}

SocketManager::~SocketManager() {}

void SocketManager::CloseSockets()
{
    for (UDPSocket* socket : m_sockets)
    {
        socket->Close();
    }
}

void SocketManager::Destroy()
{
    KYBER_LOG(LogLevel::Debug, "Destroyed SocketManager");
    CloseSockets();
    delete this;
}

void SocketManager::Close(UDPSocket* socket)
{
    KYBER_LOG(LogLevel::Debug, "Closing socket");
    if (!m_sockets.empty())
    {
        m_sockets.remove(socket);
    }
}

UDPSocket* SocketManager::Listen(const char* name, bool blocking)
{
    UDPSocket* socket = new UDPSocket(this, m_direction, m_info);

    std::string addressAndPort = std::string(name);
    std::string address = addressAndPort.substr(0, addressAndPort.find(':'));
    if (address.empty())
    {
        address = "0.0.0.0";
    }

    std::string port = addressAndPort.substr(addressAndPort.find(':') + 1);
    if (port.empty() || !std::all_of(port.begin(), port.end(), ::isdigit))
    {
        KYBER_LOG(LogLevel::Error, "Invalid port number");
        return nullptr;
    }

    if (!socket->Listen(SocketAddr(address.c_str(), std::stoi(port.c_str())), blocking))
    {
        KYBER_LOG(LogLevel::Error, "Listen failed " << address << ":" << port);
        return nullptr;
    }

    KYBER_LOG(LogLevel::Info, "SocketManager listening on " << address << ":" << port);

    m_sockets.push_back(socket);
    return socket;
}

UDPSocket* SocketManager::Connect(const char* address, bool blocking)
{
    return nullptr;
}

UDPSocket* SocketManager::CreateSocket()
{
    return nullptr;
}
} // namespace Kyber