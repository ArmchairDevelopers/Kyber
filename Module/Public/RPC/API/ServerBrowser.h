// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Core/Server.h>
#include <RPC/AsyncRPCManager.h>

#include <Proto/kyber_api.grpc.pb.h>

#include <grpcpp/grpcpp.h>

#include <memory>
#include <string>

namespace Kyber
{
using namespace kyber_api;

using grpc::Channel;

class ServerBrowserAPI
{
public:
    ServerBrowserAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token);

    std::optional<kyber_api::Server> GetServer(const std::string& serverId) const;

    std::optional<std::string> RegisterServer(const ServerCreationInfo& serverInfo) const;
    void HeartbeatServer(const std::string& serverId, std::function<void(grpc::StatusCode)> callback) const;

    void UpdateServerLevelSetup(const std::string& serverId, const std::string& map, const std::string& mode) const;

private:
    std::shared_ptr<ServerBrowser::Stub> m_stub;
    AsyncRPCManager* m_asyncManager;

    std::string m_token;
};
} // namespace Kyber
