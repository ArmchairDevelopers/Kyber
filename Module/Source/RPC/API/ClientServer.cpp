// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <optional>
#define _WINSOCKAPI_
#include <RPC/API/ClientServer.h>
#include <Core/ThreadExecutor.h>

#include <Base/Log.h>

namespace Kyber
{
using grpc::ClientContext;
using grpc::Status;

ClientServerAPI::ClientServerAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token)
    : m_stub(ClientServer::NewStub(channel))
    , m_asyncManager(asyncManager)
    , m_token(token)
{}

void ClientServerAPI::ConsumeJoinToken(const std::string& serverId, const std::string& token,
    std::function<void(std::optional<const ConsumeJoinTokenResponse*>)> callback) const
{
    ConsumeJoinTokenRequest request;
    request.set_token(token);
    request.set_server(serverId);

    m_asyncManager->StartCall<ConsumeJoinTokenRequest, ConsumeJoinTokenResponse>(m_stub.get(),
        &ClientServer::Stub::PrepareAsyncConsumeJoinToken, request,
        [callback = std::move(callback)](const ConsumeJoinTokenResponse* response, grpc::Status status) {
            if (status.ok())
            {
                callback(response);
            }
            else
            {
                KYBER_LOG(Error, "[RPC] RPC error while consuming join token (" << status.error_message() << ")");
                callback(std::nullopt);
            }
        },
        { { "authorization", m_token } });
}

std::optional<std::vector<std::string>> ClientServerAPI::GetBlacklist() const
{
    ClientContext context;
    context.AddMetadata("authorization", m_token);

    kyber_common::Empty request;
    EventSyncBlacklistResponse response;

    Status status = m_stub->GetBlacklist(&context, request, &response);
    if (!status.ok())
    {
        KYBER_LOG(Error, "[RPC] RPC error while getting eventsync blacklist (" << status.error_message() << ")");
        return std::nullopt;
    }

    std::vector<std::string> blacklist;
    blacklist.reserve(response.blacklistedevents_size());
    for (const auto& event : response.blacklistedevents())
    {
        blacklist.push_back(event);
    }

    return blacklist;
}

} // namespace Kyber
