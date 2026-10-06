// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Proto/kyber_interface.grpc.pb.h>

#include <grpcpp/channel.h>

namespace Kyber
{
using grpc::CallbackServerContext;
using grpc::ServerUnaryReactor;

class CommonInterfaceService : public kyber_interface::Common::CallbackService
{
public:
    ServerUnaryReactor* GetInfo(
        CallbackServerContext* context, const kyber_common::Empty* request, kyber_interface::CommonState* response) override;
    ServerUnaryReactor* RunCommand(
        CallbackServerContext* context, const kyber_interface::RunCommandRequest* request, kyber_common::Empty* response) override;
};
} // namespace Kyber
