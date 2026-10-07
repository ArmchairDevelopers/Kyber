// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Proto/kyber_interface.grpc.pb.h>

#include <grpcpp/channel.h>

namespace Kyber
{
using grpc::CallbackServerContext;
using grpc::ServerUnaryReactor;

class ClientInterfaceService : public kyber_interface::Client::CallbackService
{
public:
    ServerUnaryReactor* JoinServer(
        CallbackServerContext* context, const kyber_interface::JoinServerRequest* request, kyber_common::Empty* response) override;

    ServerUnaryReactor* SetVoipSettings(CallbackServerContext* context, const kyber_interface::SetVoipSettingsRequest* request,
        kyber_common::Empty* response) override;
    ServerUnaryReactor* GetVoipSettings(
        CallbackServerContext* context, const kyber_common::Empty* request, kyber_interface::VoipSettings* response) override;
};
} // namespace Kyber
