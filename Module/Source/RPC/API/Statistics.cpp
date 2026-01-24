// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <RPC/API/Statistics.h>

#include <Base/Log.h>

namespace Kyber
{
using grpc::ClientContext;
using grpc::Status;

StatisticsAPI::StatisticsAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token)
    : m_stub(Statistics::NewStub(channel))
    , m_asyncManager(asyncManager)
    , m_token(token)
{}

std::map<std::string, float> convertProtoToStdMap(const google::protobuf::Map<std::string, float>& protoMap)
{
    std::map<std::string, float> map;
    for (const auto& pair : protoMap)
    {
        map[pair.first] = pair.second;
    }
    return map;
}

void StatisticsAPI::GetStats(
    StatsSource source, const std::string& userId, std::function<void(std::optional<PlayerStatsMap>)> callback) const
{
    StatsRequest request;
    request.set_source(source);
    request.set_user(userId);

    m_asyncManager->StartCall<StatsRequest, StatsResponse>(m_stub.get(), &Statistics::Stub::PrepareAsyncGetStats, request,
        [callback = std::move(callback)](const StatsResponse* response, grpc::Status status) {
            if (response != nullptr)
            {
                callback(convertProtoToStdMap(response->stats()));
            }
            else
            {
                KYBER_LOG(Error, "[RPC] RPC error while retrieving stats (" << status.error_message() << ")");
                callback(std::nullopt);
            }
        },
        { { "authorization", m_token } });
}

void StatisticsAPI::UpdateStats(StatsSource source, const std::string& userId, const PlayerStatsMap& stats) const
{
    UpdateStatsRequest request;
    request.set_source(source);
    request.set_user(userId);
    google::protobuf::Map<std::string, float>& protoMap = *request.mutable_stats();

    for (const auto& pair : stats)
    {
        protoMap[pair.first] = pair.second;
    }

    m_asyncManager->StartCall<UpdateStatsRequest, kyber_common::Empty>(m_stub.get(), &Statistics::Stub::PrepareAsyncUpdateStats, request,
        [](const kyber_common::Empty* response, grpc::Status status) {
            if (!status.ok())
            {
                KYBER_LOG(Error, "[RPC] RPC error while updating stats (" << status.error_message() << ")");
            }
        },
        { { "authorization", m_token } });
}
} // namespace Kyber
