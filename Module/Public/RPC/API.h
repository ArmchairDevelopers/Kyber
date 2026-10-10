// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <RPC/API/ClientServer.h>
#include <RPC/API/Proxy.h>
#include <RPC/API/ServerBrowser.h>
#include <RPC/API/ServerManagement.h>
#include <RPC/API/Statistics.h>
#include <RPC/API/Voip.h>
#include <RPC/API/Launcher.h>
#include <RPC/AsyncRPCManager.h>

#include <memory>

namespace Kyber
{
class API
{
public:
    API(std::string token);

    void Update() const;

    const ClientServerAPI* GetClientServer() const
    {
        return m_clientServer.get();
    }

    const ProxyAPI* GetProxy() const
    {
        return m_proxy.get();
    }

    const ServerBrowserAPI* GetServerBrowser() const
    {
        return m_serverBrowser.get();
    }

    ServerManagementAPI* GetServerManagement()
    {
        return m_serverManagement.get();
    }

    const StatisticsAPI* GetStatistics() const
    {
        return m_statistics.get();
    }

    const VoipAPI* GetVoip() const
    {
        return m_voip.get();
    }

    const LauncherInterface* GetLauncherInterface() const
    {
        return m_launcherInterface.get();
    }

private:
    std::unique_ptr<ClientServerAPI> m_clientServer;
    std::unique_ptr<ProxyAPI> m_proxy;
    std::unique_ptr<ServerBrowserAPI> m_serverBrowser;
    std::unique_ptr<ServerManagementAPI> m_serverManagement;
    std::unique_ptr<StatisticsAPI> m_statistics;
    std::unique_ptr<VoipAPI> m_voip;
    std::unique_ptr<LauncherInterface> m_launcherInterface;

    std::thread m_stateListenerThread;

    AsyncRPCManager m_asyncManager;
};
} // namespace Kyber