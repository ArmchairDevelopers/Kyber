// Copyright BattleDash. All Rights Reserved.

#include <Render/Windows/ServerWindow.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <Render/Windows/MainWindow.h>
#include <SDK/Modes.h>

#include <vector>
#include <algorithm>
#include <map>

namespace Kyber
{
ServerWindow::ServerWindow() {
    g_program->m_api->GetProxies([&](std::optional<std::vector<KyberProxy>> kyberProxies) {
        std::sort(kyberProxies->begin(), kyberProxies->end(), [](const KyberProxy& a, const KyberProxy& b) {
            return a.ping < b.ping;
        });
        kyberProxies->push_back(KyberProxy{ "", "", "", "No Proxy", 0 });
        m_proxies = kyberProxies;
    });
}

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
    if (ImGui::SmallButton(("SWAP TEAM##" + std::string(player->m_name)).c_str()))
    {
        g_program->m_server->SetPlayerTeam(player, player->m_teamId == 1 ? 2 : 1);
    }
    ImGui::SameLine();
    if (ImGui::SmallButton(("KICK##" + std::string(player->m_name)).c_str()))
    {
        g_program->m_server->KickPlayer(player, "You have been kicked.");
    }
    return true;
}

void ServerWindow::Draw()
{
    ImGui::Begin("SERVER SETTINGS", &m_isEnabled, ImGuiWindowFlags_AlwaysAutoResize);
    GameSettings* gameSettings = Settings<GameSettings>("Game");
    ImGui::Text("GAME MODE:");
    ImGui::SameLine();
    ImGui::Text(gameSettings->DefaultLayerInclusion);
    ImGui::Text("LEVEL:");
    ImGui::SameLine();
    ImGui::Text(gameSettings->Level);
    ImGui::Separator();
    if (!g_program->m_server->m_running)
    {
        static GameMode currentMode = { "", "Mode", {}, {} };
        static GameLevel currentLevel = { "", "Level" };
        static KyberProxy currentProxy = m_proxies->at(0);
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

        if (m_proxies && ImGui::BeginCombo("##proxyCombo", currentProxy.displayName.c_str()))
        {
            for (int i = 0; i < m_proxies->size(); i++)
            {
                KyberProxy proxy = m_proxies->at(i);
                bool selected = currentProxy.ip == proxy.ip;
                if (ImGui::Selectable(proxy.displayName.c_str(), selected))
                {
                    currentProxy = proxy;
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
                    currentLevel.level, currentMode.mode, maxPlayers, SocketSpawnInfo(currentProxy.displayName != "No Proxy", currentProxy.ip.c_str(), "Test Server"));
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
        if (ImGui::Button("START GAME"))
        {
            // These bots don't actually exist, it just tricks the server into thinking they do.
            aiSettings->ForceFillGameplayBotsTeam1 = 20;
            aiSettings->ForceFillGameplayBotsTeam2 = 19;
        }
        ImGui::Separator();
        ImGui::Text("AI SETTINGS");
        ImGui::SliderInt("AI COUNT", &aiSettings->ForcedServerAutoPlayerCount, -1, 64);
        ImGui::Checkbox("UPDATE AI", &aiSettings->UpdateAI);
        ImGui::SameLine();
        ImGui::Checkbox("AI IGNORE PLAYERS", &aiSettings->ServerPlayersIgnoreClientPlayers);
        ImGui::Checkbox("AUTO BALANCE TEAMS", &Settings<WSGameSettings>("Whiteshark")->AutoBalanceTeamsOnNeutral);
        ImGui::Separator();
        ImGui::Text("PLAYER LIST");
        ServerPlayerManager* playerManager = g_program->m_server->m_playerManager;
        if (playerManager)
        {
            std::map<int32_t, std::vector<ServerPlayer*>> players;
            // Bleh
            players[1] = std::vector<ServerPlayer*>();
            players[2] = std::vector<ServerPlayer*>();
            for (ServerPlayer* player : playerManager->m_players)
            {
                if (player && !player->m_isAIPlayer)
                {
                    players[player->m_teamId].push_back(player);
                }
            }
            if (ImGui::BeginTable("PLAYER LIST", 2, ImGuiTableFlags_SizingFixedFit))
            {
                ImGui::TableNextRow();
                ImGui::TableNextColumn();
                ImGui::Text("LIGHT SIDE");
                ImGui::TableNextColumn();
                ImGui::Text("DARK SIDE");
                for (int i = 0; i < 64; i++)
                {
                    ImGui::TableNextRow();
                    int drew = 0;
                    for (int j = 1; j <= players.size(); j++)
                    {
                        ImGui::TableNextColumn();
                        if (DrawScoreboardPlayer(players[j], i))
                        {
                            drew++;
                        }
                    }
                    if (!drew)
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