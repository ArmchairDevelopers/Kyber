// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Core/Server.h>
#include <Core/Memory.h>
#include <Utilities/ThreadPool.h>

#include <Proto/kyber_api.grpc.pb.h>

#include <grpcpp/grpcpp.h>

#include <ixwebsocket/IXWebSocket.h>

#include <memory>
#include <string>

namespace Kyber
{
using namespace kyber_api;

using grpc::Channel;

class ServerManagementAPI
{
public:
    ServerManagementAPI(const std::string& apiUri, std::string token);

    void Connect(const std::string& serverId);

    void SendConsoleMessage(const std::string& message);
    void SendKeepAlive();
    void SendPlayerList();

private:
    void Send(const ServerManagementAPIEvent& event);

    void ProcessWriteQueue();
    void ProcessReceivedEvent(const ServerAPIEvent& event);
    void Receive(const ix::WebSocketMessagePtr &msg);

    std::string m_token;
    std::string m_apiUri;
    std::string m_serverId;

    std::shared_ptr<ix::WebSocket> m_webSocket;
    bool m_connectionEstablished;
    std::thread m_writeThread;
    std::mutex m_writeMutex;
    Mutex<std::queue<ServerManagementAPIEvent>> m_writeQueue;
    std::condition_variable m_cv;
};
} // namespace Kyber
