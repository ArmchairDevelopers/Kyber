// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <RPC/Interface/ClientState.h>
#include <RPC/Interface/ServerState.h>
#include <RPC/Interface/Common.h>

#include <grpcpp/server.h>
#include <grpcpp/server_builder.h>
#include <grpcpp/security/credentials.h>

#include <memory>

namespace Kyber
{
class InterfaceService
{
public:
    InterfaceService();

    const CommonInterfaceService* GetCommon() const
    {
        return m_common.get();
    }

private:
    std::unique_ptr<grpc::Server> m_server;

    std::unique_ptr<ClientInterfaceService> m_clientState;
    std::unique_ptr<ServerInterfaceService> m_serverState;
    std::unique_ptr<CommonInterfaceService> m_common;
};
} // namespace Kyber