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

class VoipAPI
{
public:
    VoipAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token);

    void Login(std::function<void(std::optional<const VoipLoginResponse*>)> callback) const;
    void JoinChannel(const std::string& serverId, std::function<void(std::optional<const VoipJoinChannelResponse*>)> callback) const;

private:
    std::shared_ptr<Voip::Stub> m_stub;
    AsyncRPCManager* m_asyncManager;

    std::string m_token;
};
} // namespace Kyber
