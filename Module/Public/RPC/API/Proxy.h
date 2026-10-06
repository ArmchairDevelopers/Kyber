// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Proto/kyber_api.grpc.pb.h>

#include <grpcpp/channel.h>

#include <memory>
#include <string>
#include <optional>

namespace Kyber
{
using namespace kyber_api;

using grpc::Channel;

class ProxyAPI
{
public:
    ProxyAPI(std::shared_ptr<Channel> channel, std::string token);

    std::vector<ProxyInfo> GetList() const;

private:
    std::shared_ptr<Proxy::Stub> m_stub;
    
    std::string m_token;
};
} // namespace Kyber
