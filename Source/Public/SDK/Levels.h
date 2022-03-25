// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <string>

namespace Kyber
{
struct GameLevel
{
    const char* level;
    const char* name;
};

static GameLevel s_game_levels[] = {
    { "S5_1/Levels/MP/Geonosis_01/Geonosis_01", "Geonosis" },
    { "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02", "Geonosis" },
    { "Levels/MP/Kamino_01/Kamino_01", "Kamino" },
    { "S7_1/Levels/Kamino_03/Kamino_03", "Kamino" },
    { "Levels/MP/Naboo_01/Naboo_01", "Naboo" },
    { "Levels/MP/Naboo_02/Naboo_02", "Naboo" },
    { "S7_2/Levels/Naboo_03/Naboo_03", "Naboo" },
    { "Levels/MP/Kashyyyk_01/Kashyyyk_01", "Kashyyyk" },
    { "S7/Levels/Kashyyyk_02/Kashyyyk_02", "Kashyyyk" },
    { "S8/Felucia/Levels/MP/Felucia_01/Felucia_01", "Felucia" },
    { "S3/Levels/Kessel_01/Kessel_01", "Kessel" },
    { "S9_3/Scarif/Levels/MP/Scarif_02/Scarif_02", "Scarif" },
    { "Levels/MP/Tatooine_01/Tatooine_01", "Tatooine" },
    { "S9_3/Tatooine_02/Tatooine_02", "Tatooine" },
    { "Levels/MP/Yavin_01/Yavin_01", "Yavin" },
    { "Levels/MP/Hoth_01/Hoth_01", "Hoth" },
    { "S9_3/Hoth_02/Hoth_02", "Hoth" },
    { "S2/Levels/CloudCity_01/CloudCity_01", "Bespin" },
    { "S2_2/Levels/JabbasPalace_01/JabbasPalace_01", "Tatooine - Jabba's Palace" },
    { "Levels/MP/Endor_01/Endor_01", "Endor" },
    { "S2_1/Levels/Endor_02/Endor_02", "Endor - Ewok Village" },
    { "S8_1/Endor_04/Endor_04", "Endor - Research Station 9" },
    { "Levels/MP/DeathStar02_01/DeathStar02_01", "Death Star II" },
    { "Levels/MP/Jakku_01/Jakku_01", "Jakku" },
    { "S9/Jakku_02/Jakku_02", "Jakku" },
    { "Levels/MP/Takodana_01/Takodana_01", "Takodana" },
    { "S9/Takodana_02/Takodana_02", "Takodana" },
    { "Levels/MP/StarKiller_01/StarKiller_01", "StarKiller Base" },
    { "S9/StarKiller_02/StarKiller_02", "StarKiller Base" },
    { "S1/Levels/Crait_01/Crait_01", "Crait" },
    { "S9_3/Crait/Crait_02", "Crait" },
    { "S9/Paintball/Levels/MP/Paintball_01/Paintball_01", "Ajan Kloss" },
    { "S9_3/COOP_NT_MC85/COOP_NT_MC85", "MC85 Star Cruiser" },
    { "S9_3/COOP_NT_FOSD/COOP_NT_FOSD", "First Order Star Destroyer" },
    { "Levels/Space/SB_DroidBattleShip_01/SB_DroidBattleShip_01", "Ryloth" },
    { "Levels/Space/SB_Kamino_01/SB_Kamino_01", "Kamino" },
    { "Levels/Space/SB_Fondor_01/SB_Fondor_01", "Fondor" },
    { "Levels/Space/SB_Endor_01/SB_Endor_01", "Endor" },
    { "Levels/Space/SB_Resurgent_01/SB_Resurgent_01", "Unknown Regions" },
    { "S1/Levels/Space/SB_SpaceBear_01/SB_SpaceBear_01", "D'Qar" },
};

GameLevel GetGameLevel(const char* level);
} // namespace Kyber