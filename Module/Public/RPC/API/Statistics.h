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

typedef std::map<std::string, float> PlayerStatsMap;

class StatisticsAPI
{
public:
    StatisticsAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token);

    void GetStats(StatsSource source, const std::string& userId, std::function<void(std::optional<PlayerStatsMap>)> callback) const;
    void UpdateStats(StatsSource source, const std::string& userId, const PlayerStatsMap& stats) const;

private:
    std::shared_ptr<Statistics::Stub> m_stub;
    AsyncRPCManager* m_asyncManager;

    std::string m_token;
};
} // namespace Kyber
