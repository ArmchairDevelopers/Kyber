// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <RPC/API/Voip.h>

#include <Base/Log.h>

namespace Kyber
{
using grpc::ClientContext;
using grpc::Status;

VoipAPI::VoipAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token)
    : m_stub(Voip::NewStub(channel))
    , m_asyncManager(asyncManager)
    , m_token(token)
{}

void VoipAPI::Login(std::function<void(std::optional<const VoipLoginResponse*>)> callback) const
{
    kyber_common::Empty request;

    m_asyncManager->StartCall<kyber_common::Empty, VoipLoginResponse>(m_stub.get(), &Voip::Stub::PrepareAsyncLogin, request,
        [callback = std::move(callback)](const VoipLoginResponse* response, grpc::Status status) {
            if (!status.ok())
            {
                KYBER_LOG(Error, "[RPC] RPC error while logging into VoIP (" << status.error_message() << ")");
                callback(std::nullopt);
                return;
            }

            callback(response);
        },
        { { "authorization", m_token } });
}

void VoipAPI::JoinChannel(const std::string& serverId, std::function<void(std::optional<const VoipJoinChannelResponse*>)> callback) const
{
    VoipJoinChannelRequest request;
    request.set_server(serverId);

    m_asyncManager->StartCall<VoipJoinChannelRequest, VoipJoinChannelResponse>(m_stub.get(), &Voip::Stub::PrepareAsyncJoinChannel, request,
        [callback = std::move(callback)](const VoipJoinChannelResponse* response, grpc::Status status) {
            if (!status.ok())
            {
                KYBER_LOG(Error, "[RPC] RPC error while joining VoIP channel (" << status.error_message() << ")");
                callback(std::nullopt);
                return;
            }

            callback(response);
        },
        { { "authorization", m_token } });
}
} // namespace Kyber
