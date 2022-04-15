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
    { "S5_1/Levels/MP/Geonosis_01/Geonosis_01", "GEONOSIS" },
    { "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02", "GEONOSIS" },
    { "Levels/MP/Kamino_01/Kamino_01", "KAMINO" },
    { "S7_1/Levels/Kamino_03/Kamino_03", "KAMINO" },
    { "Levels/MP/Naboo_01/Naboo_01", "NABOO" },
    { "Levels/MP/Naboo_02/Naboo_02", "NABOO" },
    { "S7_2/Levels/Naboo_03/Naboo_03", "NABOO" },
    { "Levels/MP/Kashyyyk_01/Kashyyyk_01", "KASHYYYK" },
    { "S7/Levels/Kashyyyk_02/Kashyyyk_02", "KASHYYYK" },
    { "S8/Felucia/Levels/MP/Felucia_01/Felucia_01", "FELUCIA" },
    { "S3/Levels/Kessel_01/Kessel_01", "KESSEL" },
    { "S9_3/Scarif/Levels/MP/Scarif_02/Scarif_02", "SCARIF" },
    { "Levels/MP/Tatooine_01/Tatooine_01", "TATOOINE" },
    { "S9_3/Tatooine_02/Tatooine_02", "TATOOINE" },
    { "Levels/MP/Yavin_01/Yavin_01", "YAVIN IV" },
    { "Levels/MP/Hoth_01/Hoth_01", "HOTH" },
    { "S9_3/Hoth_02/Hoth_02", "HOTH" },
    { "S2/Levels/CloudCity_01/CloudCity_01", "BESPIN" },
    { "S2_2/Levels/JabbasPalace_01/JabbasPalace_01", "JABBA'S PALACE" },
    { "Levels/MP/Endor_01/Endor_01", "ENDOR" },
    { "S2_1/Levels/Endor_02/Endor_02", "ENDOR - EWOK VILLAGE" },
    { "S8_1/Endor_04/Endor_04", "ENDOR - RESEARCH STATION 9" },
    { "Levels/MP/DeathStar02_01/DeathStar02_01", "DEATH STAR II" },
    { "Levels/MP/Jakku_01/Jakku_01", "JAKKU" },
    { "S9/Jakku_02/Jakku_02", "JAKKU" },
    { "Levels/MP/Takodana_01/Takodana_01", "TAKODANA" },
    { "S9/Takodana_02/Takodana_02", "TAKODANA" },
    { "Levels/MP/StarKiller_01/StarKiller_01", "STARKILLER BASE" },
    { "S9/StarKiller_02/StarKiller_02", "STARKILLER BASE" },
    { "S1/Levels/Crait_01/Crait_01", "CRAIT" },
    { "S9_3/Crait/Crait_02", "CRAIT" },
    { "S9/Paintball/Levels/MP/Paintball_01/Paintball_01", "AJAN KLOSS" },
    { "S9_3/COOP_NT_MC85/COOP_NT_MC85", "MC85 STAR CRUISER" },
    { "S9_3/COOP_NT_FOSD/COOP_NT_FOSD", "RESURGENT START DESTROYER" },
    { "Levels/Space/SB_DroidBattleShip_01/SB_DroidBattleShip_01", "RYLOTH" },
    { "Levels/Space/SB_Kamino_01/SB_Kamino_01", "KAMINO" },
    { "Levels/Space/SB_Fondor_01/SB_Fondor_01", "FONDOR" },
    { "Levels/Space/SB_Endor_01/SB_Endor_01", "ENDOR" },
    { "Levels/Space/SB_Resurgent_01/SB_Resurgent_01", "UNKNOWN REGIONS" },
    { "S1/Levels/Space/SB_SpaceBear_01/SB_SpaceBear_01", "D'QAR" },
};

GameLevel GetGameLevel(const char* level);
} // namespace Kyber