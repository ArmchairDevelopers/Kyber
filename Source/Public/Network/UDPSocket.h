// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Network/SocketCreator.h>
#include <SDK/SDK.h>

#include <stdio.h>
#include <cstring>
#include <cstddef>
#include <stdint.h>
#include <list>

#define _WINSOCKAPI_
#include <ws2tcpip.h>

namespace Kyber
{
class SocketAddr
{
public:
    SocketAddr()
    {
        Clear();
    }

    SocketAddr(const SocketAddr& addr)
    {
        Clear();
        SetData(addr.Data(), addr.Length());
    }

    SocketAddr(const char* address, uint16_t port)
    {
        Clear();
        sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        inet_pton(AF_INET, address, &addr.sin_addr);
        SetData(&addr, sizeof(addr));
    }

    void Clear()
    {
        length = 0;
        memset(address, 0, sizeof(address));
    }

    void SetData(const void* data, int len)
    {
        memcpy(address, data, len);
        length = uint8_t(len);
    }

    const uint8_t* Data() const
    {
        return address;
    }

    int Length() const
    {
        return length;
    }

    bool operator==(const SocketAddr& addr) const
    {
        if (length != addr.length)
            return false;

        for (int i = 0; i < length; i++)
        {
            if (address[i] != addr.address[i])
                return false;
        }
        return true;
    }

    bool operator!=(const SocketAddr& addr) const
    {
        return !(operator==(addr));
    }

    bool operator!() const
    {
        for (int i = 0; i < length; i++)
            if (address[i] != 0)
                return false;
        return true;
    }

    bool operator<(const SocketAddr& addr) const
    {
        if (length < addr.length)
            return true;

        if (length > addr.length)
            return false;

        for (int i = 0; i < length; i++)
        {
            if (address[i] < addr.address[i])
                return true;
            else if (address[i] > addr.address[i])
                return false;
        }

        return false;
    }

    void operator=(const SocketAddr& addr)
    {
        SetData(addr.address, addr.length);
    }

    uint16_t GetPort() const;

    bool IsBroadcasting() const;

    char* GetAddress() const
    {
        sockaddr_in* addr = (sockaddr_in*)address;
        return inet_ntoa(addr->sin_addr);
    }

    uint8_t address[64];
    uint8_t length;
};

struct PacketInfo
{
    int minSize;
    int maxSize;
    int recommendedSize;
    int overheadWhenAligned;
    int alignment;
};

struct ISocket
{
    virtual ~ISocket() {};

    virtual bool Send(uint8_t* sendBuffer, int size, unsigned int flags = 0) = 0;
    virtual int ReceiveFrom(uint8_t* buffer, int bufferSize) = 0;
	virtual int ReceiveFromWhen(uint8_t* receiveBuffer, int maxSize, unsigned int& receivedWhen);
    virtual bool SetBroadcast(uint16_t port) = 0;
    virtual void SetPeerAddress(const SocketAddr& sockAddr) = 0;
    virtual SocketAddr PeerAddress() const = 0;
    virtual bool SetDefaultPacketInfo(PacketInfo* info) = 0;
    virtual bool BlockingMode() const = 0;
    virtual bool SetBlockingMode(bool blocking) = 0;
    virtual void ReceivePulse() = 0;
    virtual void Pulse(float seconds) = 0;
    virtual void SendPulse() = 0;
    virtual intptr_t NativeSocket() const = 0;
    virtual int Port() const = 0;
    virtual const SocketAddr* Address() const = 0;
    virtual void SendProxyHandshake() = 0;
};

class IUDPSocket : public ISocket
{
    virtual bool Connect(const SocketAddr& address, bool blocking = false) = 0;
    virtual bool Listen(const SocketAddr& address, bool blocking = false) = 0;
    virtual bool Create(bool blocking = false) = 0;
};

class UDPSocket : public IUDPSocket
{
public:
    UDPSocket(SocketCreator* creator, ProtocolDirection direction, SocketSpawnInfo info);
    virtual ~UDPSocket();

    virtual bool Connect(const SocketAddr& address, bool blocking = false) override;
    virtual bool Listen(const SocketAddr& address, bool blocking = false) override;
    virtual bool Create(bool blocking = false) override;
    void Close();
    virtual bool Send(uint8_t* buffer, int bufferSize, unsigned int flags = 0) override;
    virtual int ReceiveFrom(uint8_t* buffer, int bufferSize) override;
    virtual bool SetBroadcast(uint16_t port) override;
    virtual void SetPeerAddress(const SocketAddr& sockAddr) override;
    virtual SocketAddr PeerAddress() const override;
    virtual bool SetDefaultPacketInfo(PacketInfo* info) override;
    virtual bool BlockingMode() const override;
    virtual bool SetBlockingMode(bool blocking) override;
    virtual void ReceivePulse() override {}
    virtual void Pulse(float seconds) override {}
    virtual void SendPulse() override {}
    virtual intptr_t NativeSocket() const override;
    virtual int Port() const override;
    virtual const SocketAddr* Address() const override;
    virtual void SendProxyHandshake() override;

private:
    friend class SocketManager;

    void showError();

    SocketAddr m_broadcastAddress;
    SocketAddr m_peerAddress;
    std::list<void*> m_receiveCallbacks;
    SocketCreator* m_creator;
    intptr_t m_socketHandle;
    int m_port;
    SocketAddr m_address;
    unsigned int m_isBroadcasting : 1;
    unsigned int m_blockingMode : 1;
    unsigned int m_peerAddressIsValid : 1;
    ProtocolDirection m_direction;
    SocketSpawnInfo m_info;
};
} // namespace Kyber