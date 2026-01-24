// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <RPC/AsyncRPCManager.h>

#include <Proto/kyber_api.grpc.pb.h>

#include <grpcpp/grpcpp.h>

#include <memory>
#include <string>
#include <optional>

namespace Kyber
{
using namespace kyber_api;

using grpc::Channel;

class ClientServerAPI
{
public:
    ClientServerAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token);

    void ConsumeJoinToken(const std::string& serverId, const std::string& token,
        std::function<void(std::optional<const ConsumeJoinTokenResponse*>)> callback) const;
    std::optional<std::vector<std::string>> GetBlacklist() const;
    
private:
    std::shared_ptr<ClientServer::Stub> m_stub;
    AsyncRPCManager* m_asyncManager;

    std::string m_token;
};
} // namespace Kyber
