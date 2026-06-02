// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Proto/kyber_interface.grpc.pb.h>

#include <grpcpp/support/server_callback.h>
#include <grpcpp/server_context.h>

namespace Kyber
{
using grpc::CallbackServerContext;
using grpc::ServerUnaryReactor;

class ServerInterfaceService : public kyber_interface::Server::CallbackService
{
public:
    ServerUnaryReactor* StartServer(CallbackServerContext* context, const kyber_interface::StartServerRequest* request,
        kyber_interface::ServerState* response) override;
    ServerUnaryReactor* LoadLevel(
        CallbackServerContext* context, const kyber_interface::LoadLevelRequest* request, kyber_common::Empty* response) override;
};
} // namespace Kyber
