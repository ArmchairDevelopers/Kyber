// Copyright BattleDash. All Rights Reserved.

#include <SDK/Levels.h>

#include <string>

namespace Kyber
{
GameLevel GetGameLevel(const char* level)
{
    for (int i = 0; i < sizeof(s_game_levels) / sizeof(GameLevel); i++)
    {
        if (strcmp(s_game_levels[i].level, level) == 0)
        {
            return s_game_levels[i];
        }
    }
    return { "Unknown", "Unknown" };
}
} // namespace Kyber