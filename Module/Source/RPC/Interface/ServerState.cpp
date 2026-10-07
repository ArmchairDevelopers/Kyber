// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <RPC/Interface/ServerState.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <Utilities/StringUtils.h>

#include <grpcpp/support/status.h>

namespace Kyber
{
using grpc::Status;

using namespace fastdelegate;
using namespace kyber_interface;

ServerUnaryReactor* ServerInterfaceService::StartServer(
    CallbackServerContext* context, const StartServerRequest* request, ServerState* response)
{
    ServerUnaryReactor* reactor = context->DefaultReactor();

    g_program->m_server->m_mapRotation.Reset();
    for (const auto& entry : request->maprotation())
    {
        g_program->m_server->m_mapRotation.AddEntry(entry.map(), entry.mode());
    }

    ServerCreationInfo info;
    info.name = request->name();
    info.description = request->description();
    info.password = request->password();

    auto entry = g_program->m_server->m_mapRotation.GetNextEntry();
    info.level = entry.level;
    info.mode = entry.mode;

    info.maxPlayers = request->maxplayers();

    g_program->m_server->Start(info);

    reactor->Finish(Status::OK);
    return reactor;
}

ServerUnaryReactor* ServerInterfaceService::LoadLevel(
    CallbackServerContext* context, const kyber_interface::LoadLevelRequest* request, kyber_common::Empty* response)
{
    KYBER_LOG(Info, "[Server] Loading remotely requested level");

    const auto& setup = request->levelsetup();
    g_program->m_server->LoadNextLevel(setup.map().c_str(), setup.mode().c_str());

    ServerUnaryReactor* reactor = context->DefaultReactor();
    reactor->Finish(Status::OK);
    return reactor;
}

ServerUnaryReactor* ServerInterfaceService::SetProxyList(
    CallbackServerContext* context, const kyber_interface::SetProxyListRequest* request, kyber_common::Empty* response)
{
    KYBER_LOG(Info, "[Server] Updating proxy list");

    const auto& list = request->proxylist().proxies();

    // convert to eastl vector as the one above is a grpc type
    eastl::vector<kyber_api::ProxyInfo> copiedList;
    for (const auto& proxyInfo : list)
    {
        copiedList.push_back(proxyInfo);
    }

    // For safety
    g_threadExecutor->Queue(GameThread_Server, [copiedList]() {
        UDPSocket* socket = g_program->m_server->m_socketManager->m_sockets.back();
        if (socket != g_program->m_server->m_natClient)
        {
            g_program->m_server->m_socketManager->Close(socket);
            socket->Close();
        }

        socket->UpdateProxies(copiedList);
    });

    ServerUnaryReactor* reactor = context->DefaultReactor();
    reactor->Finish(Status::OK);
    return reactor;
}
} // namespace Kyber
