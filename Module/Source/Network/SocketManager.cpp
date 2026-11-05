// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Network/SocketManager.h>

#include <string>
#include <algorithm>

namespace Kyber
{
SocketManager::SocketManager(ProtocolDirection direction, SocketSpawnInfo info)
    : m_direction(direction)
    , m_info(info)
{
    KYBER_LOG(Debug, "Created new SocketManager");
}

SocketManager::~SocketManager() {}

void SocketManager::CloseSockets()
{
    for (UDPSocket* socket : m_sockets)
    {
        socket->Close();
    }
}

void SocketManager::BroadcastMessage(uint8_t* sendBuffer, int size)
{
    for (UDPSocket* socket : m_sockets)
    {
        socket->Send(sendBuffer, size);
    }
}

void SocketManager::Destroy()
{
    KYBER_LOG(Info, "[Network] Destroyed SocketManager [" << (int)m_direction << "]");
    CloseSockets();
    delete this;
}

void SocketManager::Close(UDPSocket* socket)
{
    KYBER_LOG(Debug, "Closing socket");
    if (socket == nullptr)
    {
        return;
    }
    
    if (!m_sockets.empty())
    {
        m_sockets.remove(socket);
    }

    socket->Close();
}

UDPSocket* SocketManager::Listen(const char* name, bool blocking)
{
    auto* socket = new UDPSocket(this, m_direction, m_info);

    std::string addressAndPort = name;
    std::string address = addressAndPort.substr(0, addressAndPort.find(':'));
    if (address.empty())
    {
        address = "0.0.0.0";
    }

    std::string port = addressAndPort.substr(addressAndPort.find(':') + 1);
    if (port.empty() || !std::all_of(port.begin(), port.end(), ::isdigit))
    {
        KYBER_LOG(Error, "Invalid port number");
        return nullptr;
    }

    if (!socket->Listen(SocketAddr(address.c_str(), std::stoi(port)), blocking))
    {
        KYBER_LOG(Error, "Listen failed " << address << ":" << port);
        return nullptr;
    }

    KYBER_LOG(Info, "[Network] Listening on " << address << ":" << port);

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