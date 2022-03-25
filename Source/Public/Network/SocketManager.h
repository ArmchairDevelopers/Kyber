// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Network/UDPSocket.h>

#include <Network/SocketCreator.h>

#include <list>

namespace Kyber
{
class ISocketManager
{
public:
	virtual void Destroy() = 0;
	virtual ISocket* Connect(const char* address, bool blocking = false) = 0;
	virtual ISocket* Listen(const char* address, bool blocking = false) = 0;
	virtual ISocket* CreateSocket() = 0;
};

class SocketManager : public ISocketManager, public SocketCreator
{
public:
    SocketManager(ProtocolDirection direction, SocketSpawnInfo info);
    __forceinline __int64 getArena()
    {
        return 0;
    }

    virtual void Destroy() override;
    virtual void Close(UDPSocket* socket) override;
    virtual UDPSocket* Connect(const char* address, bool blocking = false) override;
    virtual UDPSocket* Listen(const char* address, bool blocking = false) override;
    virtual UDPSocket* CreateSocket() override;
    void CloseSockets();

    virtual ~SocketManager();

    std::list<UDPSocket*> m_sockets;
    ProtocolDirection m_direction;
    SocketSpawnInfo m_info;
};

class SocketManagerCreator
{
public:
    SocketManagerCreator(SocketSpawnInfo info) : m_info(info) {}

	virtual SocketManager* createSocketManager()
    {
        return new SocketManager(ProtocolDirection::Serverbound, m_info);
    }

    SocketSpawnInfo m_info;
};
} // namespace Kyber