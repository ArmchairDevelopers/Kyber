// Copyright BattleDash. All Rights Reserved.

#include <Render/Windows/MainWindow.h>

#include <Core/Program.h>
#include <Render/Windows/ServerWindow.h>
#include <Render/Windows/ClientWindow.h>
#include <Render/Windows/CreditsWindow.h>
#include <Utilities/ErrorUtils.h>

#include <Windows.h>

Kyber::MainWindow* g_mainWindow;

namespace Kyber
{
MainWindow::MainWindow()
{
    if (g_mainWindow)
    {
        ErrorUtils::ThrowException("MainWindow is already initialized.");
    }
    m_serverWindow = new ServerWindow();
    m_clientWindow = new ClientWindow();
    m_creditsWindow = new CreditsWindow();
}

bool MainWindow::IsEnabled()
{
    return m_isEnabled;
}

void MainWindow::Draw()
{
    ImGui::Begin("Kyber", &m_isEnabled, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::Checkbox("Show Menu [INSERT]", &m_isEnabled);
    ImGui::Checkbox("Show Credits", &m_creditsWindow->m_isEnabled);
    ImGui::Separator();
    if (!g_program->m_server->m_running)
    {
        if (ImGui::Button("Start a Server"))
        {
            m_serverWindow->m_isEnabled = true;
        }
    }
    else
    {
        if (ImGui::Button("Server Settings"))
        {
            m_serverWindow->m_isEnabled = true;
        }
    }
    if (ImGui::Button("Join a Server"))
    {
        m_clientWindow->m_isEnabled = true;
    }
    ImGui::End();
}
} // namespace Kyber