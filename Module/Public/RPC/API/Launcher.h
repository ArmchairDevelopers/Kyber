// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Core/Server.h>
#include <Proto/kyber_interface.grpc.pb.h>

#include <grpcpp/grpcpp.h>

#include <memory>
#include <tuple>
#include <optional>

namespace Kyber
{
using namespace kyber_interface;

using grpc::Channel;

class LauncherInterface
{
public:
    LauncherInterface(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager);

    void Initialize() const;
    std::optional<std::tuple<std::string, std::string>> GetCustomLevelData(std::string mapId, std::string modeId) const;
    void OnServerJoined() const;
    void OnServerDisconnect() const;

private:
    std::shared_ptr<LauncherCommon::Stub> m_stub;
    AsyncRPCManager* m_asyncManager;
};
} // namespace Kyber
