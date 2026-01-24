// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <RPC/API/ServerBrowser.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>

#include <grpcpp/support/status.h>

namespace Kyber
{
using grpc::ClientContext;
using grpc::Status;

using MetaMap = google::protobuf::Map<std::string, std::string>;

static MetaMap ParseMeta()
{
    MetaMap metaMap;

    std::string meta = PlatformUtils::GetEnv("KYBER_SERVER_META");
    std::vector<std::string> pairs = StringUtils::Split(meta, ",");
    for (const std::string& pair : pairs)
    {
        std::vector<std::string> keyValue = StringUtils::Split(pair, "=");
        if (keyValue.size() != 2)
        {
            continue;
        }

        metaMap[keyValue[0]] = keyValue[1];
    }

    return metaMap;
}

ServerBrowserAPI::ServerBrowserAPI(std::shared_ptr<Channel> channel, AsyncRPCManager* asyncManager, std::string token)
    : m_stub(ServerBrowser::NewStub(channel))
    , m_asyncManager(asyncManager)
    , m_token(token)
{}

std::optional<kyber_api::Server> ServerBrowserAPI::GetServer(const std::string& serverId) const
{
    ClientContext context;
    context.AddMetadata("authorization", m_token);

    ServerRequest request;
    request.set_id(serverId);

    kyber_api::Server response;
    Status status = m_stub->GetServer(&context, request, &response);

    if (!status.ok())
    {
        KYBER_LOG(Error, "[RPC] RPC error while getting server (" << status.error_message() << ")");
        return std::nullopt;
    }

    return response;
}

std::optional<std::string> ServerBrowserAPI::RegisterServer(const ServerCreationInfo& serverInfo) const
{
    ClientContext context;
    context.AddMetadata("authorization", m_token);

    RegisterServerRequest request;
    request.set_name(serverInfo.name);
    request.set_description(serverInfo.description);
    request.set_dedicated(g_program->m_isDedicatedServer);
    
    if (!serverInfo.password.empty())
    {
        request.set_password(serverInfo.password);
    }

    kyber_common::LevelSetup* levelSetup = request.mutable_levelsetup();
    levelSetup->set_map(serverInfo.level);
    levelSetup->set_mode(serverInfo.mode);
    auto customNames = g_program->GetAPI()->GetLauncherInterface()->GetCustomLevelData(serverInfo.level, serverInfo.mode);
    if (customNames)
    {
        levelSetup->set_mapname(std::get<0>(*customNames));
        levelSetup->set_modename(std::get<1>(*customNames));
    }

    request.set_maxplayercount(serverInfo.maxPlayers);
    request.set_statssource(kyber_api::StatsSource::KYBER);

    for (const auto& mod : g_program->m_modData.serverMods)
    {
        request.add_mods()->CopyFrom(mod);
    }

    for (const auto& mod : g_program->m_modData.explodedMods)
    {
        request.add_explodedmods()->CopyFrom(mod);
        KYBER_LOG(Info, "Added exploded mod: " << mod.name());
    }

    *request.mutable_meta() = ParseMeta();

    kyber_api::RegisterServerResponse response;
    Status status = m_stub->RegisterServer(&context, request, &response);

    if (!status.ok())
    {
        KYBER_LOG(Error, "[RPC] RPC error while registering server (" << status.error_message() << ")");
        return std::nullopt;
    }

    g_program->m_joinToken = response.proxytoken();

    return response.id();
}

void ServerBrowserAPI::UpdateServerLevelSetup(const std::string& serverId, const std::string& map, const std::string& mode) const
{
    UpdateServerRequest request;
    request.set_id(serverId);

    kyber_common::LevelSetup* levelSetup = request.mutable_levelsetup();
    levelSetup->set_map(map);
    levelSetup->set_mode(mode);

    m_asyncManager->StartCall<UpdateServerRequest, kyber_common::Empty>(m_stub.get(), &ServerBrowser::Stub::PrepareAsyncUpdateServer,
        request,
        [](const kyber_common::Empty* response, grpc::Status status) {
            if (!status.ok())
            {
                KYBER_LOG(Error, "[RPC] RPC error while updating server (" << status.error_code() << ": " << status.error_message() << ")");
            }
        },
        { { "authorization", m_token } });
}
} // namespace Kyber
