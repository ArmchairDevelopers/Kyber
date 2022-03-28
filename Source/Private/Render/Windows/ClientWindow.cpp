// Copyright BattleDash. All Rights Reserved.

#include <Render/Windows/ClientWindow.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <Render/Windows/MainWindow.h>
#include <Utilities/ErrorUtils.h>
#include <SDK/Modes.h>

#include <Windows.h>

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

    if (ImGui::BeginPopupModal(("CONNECT##" + server.name).c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize))
    {
        ImGui::Text("Are you sure you want to join %s?\n\n", server.name.c_str());
        ImGui::Separator();

        if (ImGui::Button("CONNECT", ImVec2(120, 0)))
        {
            ImGui::CloseCurrentPopup();
            SocketSpawnInfo info(true, "65.108.70.186", server.name.c_str());
            ClientSettings* clientSettings = Settings<ClientSettings>("Client");
            clientSettings->ServerIp = const_cast<char*>(info.proxyAddress);
            g_program->m_server->m_socketSpawnInfo = info;
            g_program->m_joining = true;
            g_program->ChangeClientState(ClientState_Startup);
        }
        ImGui::SetItemDefaultFocus();
        ImGui::SameLine();
        if (ImGui::Button("CANCEL", ImVec2(120, 0)))
        {
            ImGui::CloseCurrentPopup();
        }
        ImGui::EndPopup();
    }
}

void DrawServerList(int page)
{
    std::vector<ServerModel> serverList = g_program->m_api->GetServerList(page);
    ImGui::Columns(4, "serverListColumn"); // 4-ways, with border
    ImGui::Separator();
    ImGui::Text("NAME");
    ImGui::NextColumn();
    ImGui::Text("MODE");
    ImGui::NextColumn();
    ImGui::Text("MAP");
    ImGui::NextColumn();
    ImGui::Text("HOST");
    ImGui::NextColumn();
    ImGui::Separator();
    for (ServerModel server : serverList)
    {
        if (ImGui::Selectable(server.name.c_str(), false, ImGuiSelectableFlags_SpanAllColumns))
        {
            KYBER_LOG(LogLevel::Info, "Clicked server " << server.name);
            ImGui::OpenPopup(("Connect##" + server.name).c_str());
        }
        ImGui::NextColumn();
        ImGui::Text(server.mode.c_str());
        ImGui::NextColumn();
        ImGui::Text(server.level.c_str());
        ImGui::NextColumn();
        ImGui::Text(server.host.c_str());
        ImGui::NextColumn();
        DrawJoinModal(server);
    }
    ImGui::Columns(1);
    ImGui::Separator();
}

void ClientWindow::Draw()
{
    ImGui::Begin("SERVER BROWSER", &m_isEnabled);
    if (!g_program->m_server->m_running)
    {
        static char address[15] = "127.0.0.1";
        ClientSettings* clientSettings = Settings<ClientSettings>("Client");
        ImGui::InputText("SERVER IP", address, IM_ARRAYSIZE(address));
        if (ImGui::Button("DIRECT CONNECT##1") && strlen(address) > 0)
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
        ImGui::InputText("SERVER NAME", serverName, IM_ARRAYSIZE(serverName));
        if (ImGui::Button("SEARCH & CONNECT##2") && strlen(serverName) > 0)
        {
            SocketSpawnInfo info(true, "65.108.70.186", serverName);
            clientSettings->ServerIp = const_cast<char*>(info.proxyAddress);
            g_program->m_server->m_socketSpawnInfo = info;
            g_program->m_joining = true;
            g_program->ChangeClientState(ClientState_Startup);
        }
        static int page = 0;
        DrawServerList(page);
    }
    else
    {
        ImGui::Text("Please stop your server in order to join one.");
        ImGui::Text("You can do so by pressing 'Quit' in the pause menu.");
    }
    ImGui::End();
}
} // namespace Kyber