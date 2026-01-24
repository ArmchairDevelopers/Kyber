// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.
#define _WINSOCKAPI_

#include <RPC/API/ServerManagement.h>
#include <Core/Program.h>

#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXWebSocket.h>
#include <google/protobuf/util/json_util.h>

#include <mutex>
#include <string>

namespace Kyber
{
using grpc::ClientContext;

ServerManagementAPI::ServerManagementAPI(const std::string& apiUri, std::string token)
        : m_token(token)
        , m_apiUri(apiUri)
        , m_connectionEstablished(false)
{
    m_webSocket = std::make_shared<ix::WebSocket>();

    m_writeThread = std::thread(&ServerManagementAPI::ProcessWriteQueue, this);
}

void ServerManagementAPI::Connect(const std::string& serverId)
{
    KYBER_LOG(Info, "[Server] Connecting to server management gateway");
    m_webSocket->stop();

    m_serverId = serverId;

    m_webSocket->setUrl("ws://" + m_apiUri + "/ws/server/" + serverId);

    ix::WebSocketHttpHeaders headers;
    headers["Authorization"] = m_token;
    m_webSocket->setExtraHeaders(headers);

    m_webSocket->disablePong();
    m_webSocket->setOnMessageCallback([this](const ix::WebSocketMessagePtr &msg) { Receive(msg); });

    m_webSocket->start();
}

void ServerManagementAPI::Send(const ServerManagementAPIEvent& event)
{
    {
        auto queueGuard = m_writeQueue.Lock();
        queueGuard->push(event);
    }
    m_cv.notify_one();
}

void ServerManagementAPI::Receive(const ix::WebSocketMessagePtr& msg)
{
    switch (msg->type)
    {
    case ix::WebSocketMessageType::Message: {
        kyber_api::ServerAPIEvent event;
        if (event.ParseFromString(msg->str))
        {
            g_threadExecutor->Queue(GameThread_Server, [this, event]() { ProcessReceivedEvent(event); });
        } 
        else 
        {
            KYBER_LOG(Error, "[Server] Failed to parse incoming message");
        }
        break;
    }
    case ix::WebSocketMessageType::Open:
        KYBER_LOG(Info, "[Network] Server Management Connection Opened");
        m_connectionEstablished = true;
        break;
    case ix::WebSocketMessageType::Close:
        KYBER_LOG(Info, "[Network] Server Management Connection Closed: " << msg->closeInfo.code << " " << msg->closeInfo.reason);
        m_connectionEstablished = false;
        break;
    case ix::WebSocketMessageType::Error:
        KYBER_LOG(Error, "[Network] Server Management Connection Error: " << msg->errorInfo.http_status << " " << msg->errorInfo.reason);
        if (msg->errorInfo.http_status == 410)
        {
            g_threadExecutor->Queue(GameThread_Server, []() { 
                g_program->m_server->Register();
            });
        }
        break;
    case ix::WebSocketMessageType::Ping:
        break;
    case ix::WebSocketMessageType::Pong:
        break;
    case ix::WebSocketMessageType::Fragment:
        break;
    }
}

void ServerManagementAPI::ProcessWriteQueue()
{
    while (true)
    {
        {
            std::unique_lock<std::mutex> writeLock(m_writeMutex);
            m_cv.wait(writeLock, [this] { return !m_writeQueue.Lock()->empty() && m_connectionEstablished; });
        }
        
        auto queueGuard = m_writeQueue.Lock();

        auto event = queueGuard->front();
        queueGuard->pop();

        std::string data;
        if (event.SerializeToString(&data))
        {
            m_webSocket->sendBinary(data);
        }
        else
        {
            KYBER_LOG(Error, "[Server] Failed to serialize message");
        }
    }
}

void ServerManagementAPI::ProcessReceivedEvent(const ServerAPIEvent& event)
{
    switch (event.body_case())
    {
    case kyber_api::ServerAPIEvent::kServerKick: {
        uint64_t playerId = std::stoull(event.serverkick().id());
        ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayerOrSpectator(playerId);
        if (player == nullptr)
        {
            SendConsoleMessage("Failed to kick " + std::to_string(playerId) + ", player not found");
            return;
        }

        g_program->m_server->KickPlayer(player, event.serverkick().reason().c_str());
        break;
    }
    case kyber_api::ServerAPIEvent::kServerBan: {
        uint64_t playerId = std::stoull(event.serverban().id());
        ServerPlayer* player = g_program->m_server->m_playerManager->GetPlayerOrSpectator(playerId);
        if (player == nullptr)
        {
            SendConsoleMessage("Failed to ban " + std::to_string(playerId) + ", player not found");
            return;
        }

        g_program->m_server->KickPlayer(player, event.serverban().reason().c_str());
        break;
    }
    case kyber_api::ServerAPIEvent::kServerMapRotation:
        break;
    case kyber_api::ServerAPIEvent::kServerRunCommand:
        g_program->m_console->EnqueueCommand(event.serverruncommand().command().c_str());
        break;
    case kyber_api::ServerAPIEvent::BODY_NOT_SET:
        break;
    }
}

void ServerManagementAPI::SendConsoleMessage(const std::string& message)
{
    if (!m_connectionEstablished || !g_program->m_server->IsRunning())
    {
        return;
    }

    KYBER_LOG(Info, "[Server] " << message);

    ServerManagementAPIEvent event;
    event.mutable_console()->set_message(message);
    Send(event);
}

void ServerManagementAPI::SendKeepAlive()
{
    if (!m_connectionEstablished || !g_program->m_server->IsRunning())
    {
        return;
    }

    ServerManagementAPIEvent event;
    event.mutable_keepalive(); // Define as a keep alive type
    Send(event);
}

void ServerManagementAPI::SendPlayerList()
{
    if (!m_connectionEstablished || !g_program->m_server->IsRunning())
    {
        return;
    }

    if (g_program->m_server->m_playerManager == nullptr)
    {
        return;
    }

    ServerManagementAPIEvent event;

    // Define as player list event
    event.mutable_players();

    for (ServerPlayer* player : g_program->m_server->m_playerManager->m_players)
    {
        if (player->IsAIPlayer())
        {
            continue;
        }

        kyber_common::ServerPlayer* protoPlayer = event.mutable_players()->add_players();
        protoPlayer->set_id(std::to_string(player->m_onlineId.m_nativeData));
        protoPlayer->set_name(player->m_name);
        protoPlayer->set_teamid(player->m_teamId);
    }

    Send(event);
}
} // namespace Kyber
