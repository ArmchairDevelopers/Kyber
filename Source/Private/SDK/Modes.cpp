// Copyright BattleDash. All Rights Reserved.

#include <SDK/Modes.h>

#include <string>

namespace Kyber
{
GameMode GetGameMode(const char* mode)
{
    for (int i = 0; i < sizeof(s_game_modes) / sizeof(GameMode); i++)
    {
        if (strcmp(s_game_modes[i].mode, mode) == 0)
        {
            return s_game_modes[i];
        }
    }
    return { "Unknown", "Unknown", {}, {} };
}

GameLevel GetGameLevel(GameMode mode, const char* level)
{
    for (int j = 0; j < mode.levelOverrides.size(); j++)
    {
        if (strcmp(mode.levelOverrides[j].level, level) == 0)
        {
            return mode.levelOverrides[j];
        }
    }
    return GetGameLevel(level);
}
} // namespace Kyber