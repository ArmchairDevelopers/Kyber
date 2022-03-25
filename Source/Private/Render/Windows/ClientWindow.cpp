// Copyright BattleDash. All Rights Reserved.

#include <Render/Windows/ClientWindow.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <Render/Windows/MainWindow.h>
#include <Utilities/ErrorUtils.h>
#include <SDK/Modes.h>

#include <Windows.h>
#include <chrono>

namespace Kyber
{
ClientWindow::ClientWindow() {}

bool ClientWindow::IsEnabled()
{
    return g_mainWindow->IsEnabled() && m_isEnabled;
}

void DrawJoinModal(ServerModel server)
{
    ImVec2 center = ImGui::GetMainViewport()->GetCenter();
    ImGui::SetNextWindowPos(center, ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));

    if (ImGui::BeginPopupModal(("Connect##" + server.name).c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize))
    {
        ImGui::Text("Are you sure you want to join %s?\nIt requires the following mods:\n\n", server.name.c_str());
        for (const auto& mod : server.mods)
        {
            ImGui::Text(mod.c_str());
        }
        ImGui::Separator();

        if (ImGui::Button("OK", ImVec2(120, 0)))
        {
            ImGui::CloseCurrentPopup();
            // Yes, this causes a memory leak. Too bad!
            char* serverName = new char[server.name.size() + 1];
            char* proxyAddress = new char[server.proxy.ip.size() + 1];
            strcpy(serverName, server.name.c_str());
            strcpy(proxyAddress, server.proxy.ip.c_str());
            Settings<ClientSettings>("Client")->ServerIp = proxyAddress;
            g_program->m_server->m_socketSpawnInfo = SocketSpawnInfo(true, proxyAddress, serverName);
            g_program->m_joining = true;
            g_program->ChangeClientState(ClientState_Startup);
        }
        ImGui::SetItemDefaultFocus();
        ImGui::SameLine();
        if (ImGui::Button("Cancel", ImVec2(120, 0)))
        {
            ImGui::CloseCurrentPopup();
        }
        ImGui::EndPopup();
    }
}

void DrawServerList()
{
    static std::optional<std::vector<ServerModel>> serverList;
    static long long lastUpdate = 0; // Epoch seconds that the server list was last updated.
    static int page = 1;
    static int lastPage = 1; // The last page that was displayed.
    if (lastUpdate == 0 || (std::chrono::system_clock::now().time_since_epoch().count() - lastUpdate > 25000000) || lastPage != page)
    {
        KYBER_LOG(LogLevel::Info, "Updating server list... " << lastUpdate);
        if (lastPage != page)
        {
            serverList = std::optional<std::vector<ServerModel>>(std::vector<ServerModel>());
        }
        g_program->m_api->GetServerList(page, [&](int responsePage, std::optional<std::vector<ServerModel>> servers) {
            if (responsePage == page)
            {
                serverList = servers;
            }
        });
        lastUpdate = std::chrono::system_clock::now().time_since_epoch().count();
        lastPage = page;
    }
    if (!serverList.has_value())
    {
        ImGui::Text("Server list failed to load.");
        return;
    }
    ImGui::Columns(4, "serverListColumn");
    ImGui::Separator();
    ImGui::Text("Name");
    ImGui::NextColumn();
    ImGui::Text("Mode");
    ImGui::NextColumn();
    ImGui::Text("Map");
    ImGui::NextColumn();
    ImGui::Text("Host");
    ImGui::NextColumn();
    ImGui::Separator();
    for (ServerModel server : serverList.value())
    {
        if (ImGui::Selectable(server.name.c_str(), false, ImGuiSelectableFlags_SpanAllColumns))
        {
            KYBER_LOG(LogLevel::Info, "Clicked server " << server.name);
            ImGui::OpenPopup(("Connect##" + server.name).c_str());
        }
        ImGui::NextColumn();
        GameMode mode = GetGameMode(server.mode.c_str());
        ImGui::Text(mode.name);
        ImGui::NextColumn();
        ImGui::Text(GetGameLevel(server.level.c_str()).name);
        ImGui::NextColumn();
        ImGui::Text(server.host.c_str());
        ImGui::NextColumn();
        DrawJoinModal(server);
    }
    if (page > 1)
    {
        if (ImGui::Button(("Last Page (" + std::to_string(page - 1) + ")").c_str()))
        {
            page--;
        }
    }
    ImGui::NextColumn();
    ImGui::NextColumn();
    ImGui::NextColumn();
    if (ImGui::Button(("Next Page (" + std::to_string(page + 1) + ")").c_str()))
    {
        page++;
    }
    ImGui::Columns(1);
    ImGui::Separator();
}

void ClientWindow::Draw()
{
    ImGui::Begin("Client Settings", &m_isEnabled);
    if (!g_program->m_server->m_running)
    {
        static char address[15] = "127.0.0.1";
        ClientSettings* clientSettings = Settings<ClientSettings>("Client");
        ImGui::InputText("Server IP", address, IM_ARRAYSIZE(address));
        if (ImGui::Button("Connect##1") && strlen(address) > 0)
        {
            SocketSpawnInfo info(false, "", "");
            clientSettings->ServerIp = address;
            g_program->m_server->m_natClient->Send(reinterpret_cast<uint8_t*>(address), strlen(address) + 1);
            g_program->m_server->m_socketSpawnInfo = info;
            g_program->m_joining = true;
            g_program->ChangeClientState(ClientState_Startup);
        }
        ImGui::Separator();
        static char serverName[20] = "";
        ImGui::InputText("Proxied Server Name", serverName, IM_ARRAYSIZE(serverName));
        if (ImGui::Button("Connect##2") && strlen(serverName) > 0)
        {
            SocketSpawnInfo info(true, "65.108.70.186", serverName);
            clientSettings->ServerIp = const_cast<char*>(info.proxyAddress);
            g_program->m_server->m_socketSpawnInfo = info;
            g_program->m_joining = true;
            g_program->ChangeClientState(ClientState_Startup);
        }
        DrawServerList();
    }
    else
    {
        ImGui::Text("Please stop your server in order to join one.");
        ImGui::Text("You can do so by pressing 'Quit' in the pause menu.");
    }
    ImGui::End();
}
} // namespace Kyber