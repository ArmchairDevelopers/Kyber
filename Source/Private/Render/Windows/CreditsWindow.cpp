// Copyright BattleDash. All Rights Reserved.

#include <Render/Windows/CreditsWindow.h>

#include <Render/Windows/MainWindow.h>

#include <Windows.h>

namespace Kyber
{
CreditsWindow::CreditsWindow() {}

bool CreditsWindow::IsEnabled()
{
    return g_mainWindow->IsEnabled() && m_isEnabled;
}

void CreditsWindow::Draw()
{
    ImGui::Begin("SUPPORT & CREDITS", &m_isEnabled, ImGuiWindowFlags_AlwaysAutoResize);    
    {
        for (const char* credit : credits)
        {
            ImGui::SetCursorPosX(ImGui::GetWindowWidth() / 2 - ImGui::CalcTextSize(credit).x / 2);
            ImGui::Text(credit);
        }
    ImGui::Separator();
    ImGui::Text("DISCORD SUPPORT:");
    ImGui::Text("https://discord.gg/kyber");
    }
    ImGui::End();
}
} // namespace Kyber