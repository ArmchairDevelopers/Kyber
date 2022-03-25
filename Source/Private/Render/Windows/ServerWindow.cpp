// Copyright BattleDash. All Rights Reserved.

#include <Render/Windows/ServerWindow.h>

#include <Core/Program.h>
#include <Render/Windows/MainWindow.h>
#include <Utilities/ErrorUtils.h>
#include <SDK/Modes.h>

#include <Windows.h>

namespace Kyber
{
ServerWindow::ServerWindow() {}

bool ServerWindow::IsEnabled()
{
    return g_mainWindow->IsEnabled() && m_isEnabled;
}

bool DrawScoreboardPlayer(std::vector<ServerPlayer*> playerList, int index)
{
    if (playerList.size() <= index)
    {
        return false;
    }
    ServerPlayer* player = playerList[index];
    ImGui::Text("%s", player->m_name);
    ImGui::SameLine();
    if (ImGui::SmallButton(("Swap Team##" + std::string(player->m_name)).c_str()))
    {
        g_program->m_server->SetPlayerTeam(player, player->m_teamId == 1 ? 2 : 1);
    }
    ImGui::SameLine();
    if (ImGui::SmallButton(("Kick##" + std::string(player->m_name)).c_str()))
    {
        g_program->m_server->KickPlayer(player, "You have been kicked.");
    }
    return true;
}

void ServerWindow::Draw()
{
    ImGui::Begin("Server Settings", &m_isEnabled, ImGuiWindowFlags_AlwaysAutoResize);
    GameSettings* gameSettings = Settings<GameSettings>("Game");
    ImGui::Text("Game Mode:");
    ImGui::SameLine();
    ImGui::Text(gameSettings->DefaultLayerInclusion);
    ImGui::Text("Game Level:");
    ImGui::SameLine();
    ImGui::Text(gameSettings->Level);
    ImGui::Separator();
    if (!g_program->m_server->m_running)
    {
        static GameMode currentMode = { "", "Mode", {}, {} };
        static GameLevel currentLevel = { "", "Level" };
        if (ImGui::BeginCombo("##modeCombo", currentMode.name))
        {
            for (int n = 0; n < IM_ARRAYSIZE(s_game_modes); n++)
            {
                bool selected = (strcmp(currentMode.mode, s_game_modes[n].mode) == 0);
                if (ImGui::Selectable(s_game_modes[n].name, selected))
                {
                    currentMode = s_game_modes[n];
                    currentLevel = { "", "Level" };
                }
                if (selected)
                {
                    ImGui::SetItemDefaultFocus();
                }
            }
            ImGui::EndCombo();
        }
        if (ImGui::BeginCombo("##levelCombo", currentLevel.name))
        {
            for (int i = 0; i < currentMode.levels.size(); i++)
            {
                GameLevel level = GetGameLevel(currentMode, currentMode.levels[i]);
                bool selected = (strcmp(currentLevel.level, level.level) == 0);
                if (ImGui::Selectable(level.name, selected))
                {
                    currentLevel = level;
                }
                if (selected)
                {
                    ImGui::SetItemDefaultFocus();
                }
            }
            ImGui::EndCombo();
        }
        static int maxPlayers = 40;
        ImGui::SliderInt("Max Players", &maxPlayers, 2, 64);
        static bool proxied = true;
        ImGui::Checkbox("Proxied", &proxied);
        if (ImGui::IsItemHovered())
        {
            ImGui::BeginTooltip();
            ImGui::Text("When you use a Kyber Proxy, your server");
            ImGui::Text("will be displayed on the server browser,");
            ImGui::Text("and client/host IPs will be hidden.\n\n");
            ImGui::Text("When you don't use a Kyber Proxy, you will");
            ImGui::Text("need to Port Forward port 25200 in your router");
            ImGui::Text("and have players connect to your IP directly.");
            ImGui::Text("Mod verification is not supported when not using a proxy.");
            ImGui::EndTooltip();
        }
        static int errorTime = 0;
        if (ImGui::Button("Start Server"))
        {
            if (strcmp(currentMode.name, "Mode") != 0 && strcmp(currentLevel.name, "Level") != 0)
            {
                g_program->m_server->Start(
                    currentLevel.level, currentMode.mode, maxPlayers, SocketSpawnInfo(proxied, "65.108.70.186", "Test Server"));
            }
            else
            {
                errorTime = 1000;
            }
        }
        if (errorTime > 0)
        {
            if (ImGui::IsItemHovered())
            {
                ImGui::BeginTooltip();
                ImGui::Text("Please select a game mode and level.");
                ImGui::EndTooltip();
            }
            errorTime--;
        }
    }
    else if (g_program->m_clientState == ClientState_Ingame)
    {
        ImGui::Text("Leave this game to start a new one.");
        ImGui::Separator();
        AutoPlayerSettings* aiSettings = Settings<AutoPlayerSettings>("AutoPlayers");
        if (ImGui::Button("Start Game"))
        {
            // These bots don't actually exist, it just tricks the server into thinking they do.
            aiSettings->ForceFillGameplayBotsTeam1 = 20;
            aiSettings->ForceFillGameplayBotsTeam2 = 19;
        }
        ImGui::Separator();
        ImGui::Text("AI Settings:");
        ImGui::SliderInt("AI Count", &aiSettings->ForcedServerAutoPlayerCount, -1, 64);
        ImGui::Checkbox("Update AI", &aiSettings->UpdateAI);
        ImGui::Checkbox("AI ignore players", &aiSettings->ServerPlayersIgnoreClientPlayers);
        ImGui::Checkbox("Auto Balance Players", &Settings<WSGameSettings>("Whiteshark")->AutoBalanceTeamsOnNeutral);
        ImGui::Separator();
        ImGui::Text("Player List:");
        ServerPlayerManager* playerManager = g_program->m_server->m_playerManager;
        if (playerManager)
        {
            std::vector<ServerPlayer*> players(playerManager->m_players, playerManager->m_players + 64);
            std::vector<ServerPlayer*> team1Players;
            std::vector<ServerPlayer*> team2Players;
            for (ServerPlayer* player : playerManager->m_players)
            {
                if (player && !player->m_isAIPlayer && player->m_name != NULL)
                {
                    if (player->m_teamId == 1)
                    {
                        team1Players.push_back(player);
                    }
                    else if (player->m_teamId == 2)
                    {
                        team2Players.push_back(player);
                    }
                }
            }
            if (ImGui::BeginTable("Scoreboard", 2, ImGuiTableFlags_SizingFixedFit))
            {
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::Text("Team 1");
                ImGui::TableNextColumn();
                ImGui::Text("Team 2");
                for (int i = 0; i < 64; i++)
                {
                    ImGui::TableNextRow();
                    ImGui::TableNextColumn();
                    bool drewPlayer1 = DrawScoreboardPlayer(team1Players, i);
                    ImGui::TableNextColumn();
                    bool drewPlayer2 = DrawScoreboardPlayer(team2Players, i);
                    if (!drewPlayer1 && !drewPlayer2)
                    {
                        break;
                    }
                }
                ImGui::EndTable();
            }
        }
    }
    else
    {
        ImGui::Text("Settings will be available once");
        ImGui::Text("the game is fully loaded.");
    }
    ImGui::End();
}
} // namespace Kyber