// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Network/SocketCreator.h>
#include <SDK/SDK.h>
#include <Network/SafeQueue.h>

#include <atomic>
#include <cstdint>

#include <ws2tcpip.h>

#include <ixwebsocket/IXWebSocket.h>

#include <EASTL/vector.h>

namespace Kyber
{
struct WebSocketMessage
{
    uint32_t socketId;
    uint32_t timestamp;
    uint8_t data[2048];
    size_t size;
};

class WebSocket
{
public:
    using ReceiveQueue = SafeQueue<WebSocketMessage*>;

    WebSocket(std::string id, uint32_t index, std::shared_ptr<ReceiveQueue> queue);

    bool ConnectAsServer(const std::string& proxyAddress, const std::string& joinToken);
    bool ConnectAsClient(const std::string& proxyAddress, const std::string& joinToken);

    void Close();
    bool Send(const uint8_t* buffer, int bufferSize, unsigned int flags = 0);

    const std::string& GetId() const
    {
        return m_id;
    }

private:
    void Start();

    void Receive(const ix::WebSocketMessagePtr& msg);

    std::string m_id;
    uint32_t m_index;

    volatile uint32_t m_failedAttempts; // Connects but server closes connection 

    std::shared_ptr<ix::WebSocket> m_socket;
    std::shared_ptr<ReceiveQueue> m_receiveQueue;
};
} // namespace Kyber