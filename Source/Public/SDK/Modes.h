// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <SDK/Levels.h>

#include <string>
#include <vector>

namespace Kyber
{
struct GameMode
{
    const char* mode;
    const char* name;
    std::vector<const char*> levels;
    std::vector<GameLevel> levelOverrides;
};

//clang-format off
// What if you wanted to format something nicely, but clang-format said:
static GameMode s_game_modes[] = {
    {
    "HeroesVersusVillains",
    "HEROES VS. VILLAINS",
    {
        "S5_1/Levels/MP/Geonosis_01/Geonosis_01",
        "Levels/MP/Kamino_01/Kamino_01",
        "Levels/MP/Naboo_02/Naboo_02",
        "Levels/MP/Kashyyyk_01/Kashyyyk_01",
        "S8/Felucia/Levels/MP/Felucia_01/Felucia_01",
        "S7_2/Levels/Naboo_03/Naboo_03",
        "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
        "S3/Levels/Kessel_01/Kessel_01",
        "S9_3/Scarif/Levels/MP/Scarif_02/Scarif_02",
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "Levels/MP/Hoth_01/Hoth_01",
        "S2/Levels/CloudCity_01/CloudCity_01",
        "S2_2/Levels/JabbasPalace_01/JabbasPalace_01",
        "Levels/MP/Endor_01/Endor_01",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "Levels/MP/Jakku_01/Jakku_01",
        "Levels/MP/Takodana_01/Takodana_01",
        "Levels/MP/StarKiller_01/StarKiller_01",
        "S9_3/Crait/Crait_02",
        "S9/Paintball/Levels/MP/Paintball_01/Paintball_01",
        "S9/Takodana_02/Takodana_02",
        "S9/Jakku_02/Jakku_02"
    },
    {
        {
            "Levels/MP/Tatooine_01/Tatooine_01",
            "MOS EISLEY"
        },
        {
            "S7_2/Levels/Naboo_03/Naboo_03",
            "REPUBLIC VENATOR"
        },
        {
            "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
            "SEPARATIST DREADNAUGHT"
        },
        {
            "S9/Jakku_02/Jakku_02",
            "RESURGENT STAR DESTROYER"
        },
        {
            "S9/Takodana_02/Takodana_02",
            "MC85 STAR CRUISER"
        }
    }
},

{
    "PlanetaryBattles",
    "GALACTIC ASSAULT",
    {
        "S5_1/Levels/MP/Geonosis_01/Geonosis_01",
        "Levels/MP/Kamino_01/Kamino_01",
        "Levels/MP/Naboo_01/Naboo_01",
        "Levels/MP/Kashyyyk_01/Kashyyyk_01",
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "Levels/MP/Hoth_01/Hoth_01",
        "Levels/MP/Endor_01/Endor_01",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "Levels/MP/Jakku_01/Jakku_01",
        "Levels/MP/Takodana_01/Takodana_01",
        "Levels/MP/StarKiller_01/StarKiller_01",
        "S1/Levels/Crait_01/Crait_01"
    }
},

{
    "Mode1",
    "SUPREMACY",
    {
        "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
        "S7_1/Levels/Kamino_03/Kamino_03",
        "S7_2/Levels/Naboo_03/Naboo_03",
        "S7/Levels/Kashyyyk_02/Kashyyyk_02",
        "S8/Felucia/Levels/MP/Felucia_01/Felucia_01",
        "S9_3/Scarif/Levels/MP/Scarif_02/Scarif_02",
        "S9_3/Tatooine_02/Tatooine_02",
        "Levels/MP/Yavin_01/Yavin_01",
        "S9_3/Hoth_02/Hoth_02",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "S9/Jakku_02/Jakku_02",
        "S9/Takodana_02/Takodana_02",
        "S9/Paintball/Levels/MP/Paintball_01/Paintball_01"
    }
},

{
    "Mode9",
    "CO-OP ATTACK",
    {
        "S5_1/Levels/MP/Geonosis_01/Geonosis_01",
        "Levels/MP/Kamino_01/Kamino_01",
        "S7_2/Levels/Naboo_03/Naboo_03",
        "S7/Levels/Kashyyyk_02/Kashyyyk_02",
        "S8/Felucia/Levels/MP/Felucia_01/Felucia_01",
        "S7_1/Levels/Kamino_03/Kamino_03",
        "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
        "S3/Levels/Kessel_01/Kessel_01",
        "S9_3/Scarif/Levels/MP/Scarif_02/Scarif_02",
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "Levels/MP/Hoth_01/Hoth_01",
        "S2_2/Levels/JabbasPalace_01/JabbasPalace_01",
        "Levels/MP/Endor_01/Endor_01",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "S9/Jakku_02/Jakku_02",
        "S9/Takodana_02/Takodana_02",
        "S9/StarKiller_02/StarKiller_02",
        "S9/Paintball/Levels/MP/Paintball_01/Paintball_01",
        "S9_3/COOP_NT_MC85/COOP_NT_MC85",
        "S9_3/COOP_NT_FOSD/COOP_NT_FOSD"
    },
    {
        {
            "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
            "SEPARATIST DREADNAUGHT"
        },
        {
            "S7_1/Levels/Kamino_03/Kamino_03",
            "REPUBLIC VENATOR"
        },
        {
            "Levels/MP/Tatooine_01/Tatooine_01",
            "MOS EISLEY"
        }
    }
},

{
    "ModeDefend",
    "CO-OP DEFEND",
    {
        "S5_1/Levels/MP/Geonosis_01/Geonosis_01",
        "Levels/MP/Kamino_01/Kamino_01",
        "S7_2/Levels/Naboo_03/Naboo_03",
        "S7/Levels/Kashyyyk_02/Kashyyyk_02",
        "S8/Felucia/Levels/MP/Felucia_01/Felucia_01",
        "S7_1/Levels/Kamino_03/Kamino_03",
        "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
        "S3/Levels/Kessel_01/Kessel_01",
        "S9_3/Scarif/Levels/MP/Scarif_02/Scarif_02",
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "Levels/MP/Hoth_01/Hoth_01",
        "S2_2/Levels/JabbasPalace_01/JabbasPalace_01",
        "Levels/MP/Endor_01/Endor_01",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "S9/Jakku_02/Jakku_02",
        "S9/Takodana_02/Takodana_02",
        "S9/StarKiller_02/StarKiller_02",
        "S9/Paintball/Levels/MP/Paintball_01/Paintball_01",
        "S9_3/COOP_NT_MC85/COOP_NT_MC85",
        "S9_3/COOP_NT_FOSD/COOP_NT_FOSD"
    },
    {
        {
            "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
            "SEPARATIST DREADNAUGHT"
        },
        {
            "S7_1/Levels/Kamino_03/Kamino_03",
            "REPUBLIC VENATOR"
        },
        {
            "Levels/MP/Tatooine_01/Tatooine_01",
            "MOS EISLEY"
        }
    }
},

{
    "PlanetaryMissions",
    "STRIKE",
    {
        "Levels/MP/Kamino_01/Kamino_01",
        "Levels/MP/Naboo_01/Naboo_01",
        "Levels/MP/Kashyyyk_01/Kashyyyk_01",
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "Levels/MP/Hoth_01/Hoth_01",
        "Levels/MP/Endor_01/Endor_01",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "Levels/MP/Jakku_01/Jakku_01",
        "Levels/MP/Takodana_01/Takodana_01",
        "Levels/MP/StarKiller_01/StarKiller_01",
        "S1/Levels/Crait_01/Crait_01"
    },
    {
        {
            "S1/Levels/Crait_01/Crait_01",
            "CRAIT (WIP)"
        }
    }
},

{
    "Mode5",
    "EXTRACTION",
    {
        "S3/Levels/Kessel_01/Kessel_01",
        "S2_2/Levels/JabbasPalace_01/JabbasPalace_01"
    }
},

{
    "Blast",
    "BLAST",
    {
        "S5_1/Levels/MP/Geonosis_01/Geonosis_01",
        "Levels/MP/Kamino_01/Kamino_01",
        "Levels/MP/Naboo_01/Naboo_01",
        "Levels/MP/Naboo_02/Naboo_02",
        "Levels/MP/Kashyyyk_01/Kashyyyk_01",
        "S3/Levels/Kessel_01/Kessel_01",
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "Levels/MP/Hoth_01/Hoth_01",
        "S2/Levels/CloudCity_01/CloudCity_01",
        "S2_2/Levels/JabbasPalace_01/JabbasPalace_01",
        "Levels/MP/Endor_01/Endor_01",
        "S2_1/Levels/Endor_02/Endor_02",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "Levels/MP/Jakku_01/Jakku_01",
        "Levels/MP/Takodana_01/Takodana_01",
        "Levels/MP/StarKiller_01/StarKiller_01",
        "S1/Levels/Crait_01/Crait_01"
    },
    {
        {
            "Levels/MP/Tatooine_01/Tatooine_01",
            "MOS EISLEY"
        },
        {
            "Levels/MP/Naboo_02/Naboo_02",
            "THEED ROYAL PALACE HANGAR"
        },
        {
            "Levels/MP/Endor_01/Endor_01",
            "RESEARCH STATION 9"
        },
        {
            "S2_1/Levels/Endor_02/Endor_02",
            "EWOK VILLAGE (WIP)"
        },
        {
            "Levels/MP/Naboo_01/Naboo_01",
            "THEED ROYAL PALACE"
        }
    }
},

{
    "Mode3",
    "EWOK HUNT",
    {
        "S2_1/Levels/Endor_02/Endor_02",
        "S8_1/Endor_04/Endor_04"
    }
},

{
    "ModeC",
    "JETPACK CARDO",
    {
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "S2/Levels/CloudCity_01/CloudCity_01"
    }
},

{
    "SpaceBattle",
    "STARFIGHTER ASSAULT",
    {
        "Levels/Space/SB_DroidBattleShip_01/SB_DroidBattleShip_01",
        "Levels/Space/SB_Kamino_01/SB_Kamino_01",
        "Levels/Space/SB_Fondor_01/SB_Fondor_01",
        "Levels/Space/SB_Endor_01/SB_Endor_01",
        "Levels/Space/SB_Resurgent_01/SB_Resurgent_01",
        "S1/Levels/Space/SB_SpaceBear_01/SB_SpaceBear_01"
    }
},

{
    "Mode7",
    "HERO STARFIGHTERS",
    {
        "Levels/Space/SB_DroidBattleShip_01/SB_DroidBattleShip_01",
        "Levels/Space/SB_Kamino_01/SB_Kamino_01",
        "Levels/Space/SB_Fondor_01/SB_Fondor_01",
        "Levels/Space/SB_Endor_01/SB_Endor_01",
        "Levels/Space/SB_Resurgent_01/SB_Resurgent_01",
        "S1/Levels/Space/SB_SpaceBear_01/SB_SpaceBear_01"
    }
},

{
    "Mode6",
    "HERO SHOWDOWN",
    {
        "S5_1/Levels/MP/Geonosis_01/Geonosis_01",
        "Levels/MP/Kamino_01/Kamino_01",
        "Levels/MP/Naboo_02/Naboo_02",
        "Levels/MP/Kashyyyk_01/Kashyyyk_01",
        "S8/Felucia/Levels/MP/Felucia_01/Felucia_01",
        "S7_2/Levels/Naboo_03/Naboo_03",
        "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
        "S3/Levels/Kessel_01/Kessel_01",
        "S9_3/Scarif/Levels/MP/Scarif_02/Scarif_02",
        "Levels/MP/Tatooine_01/Tatooine_01",
        "Levels/MP/Yavin_01/Yavin_01",
        "Levels/MP/Hoth_01/Hoth_01",
        "S2/Levels/CloudCity_01/CloudCity_01",
        "S2_2/Levels/JabbasPalace_01/JabbasPalace_01",
        "Levels/MP/Endor_01/Endor_01",
        "Levels/MP/DeathStar02_01/DeathStar02_01",
        "Levels/MP/Jakku_01/Jakku_01",
        "Levels/MP/Takodana_01/Takodana_01",
        "Levels/MP/StarKiller_01/StarKiller_01",
        "S9_3/Crait/Crait_02",
        "S9/Paintball/Levels/MP/Paintball_01/Paintball_01",
        "S9/Takodana_02/Takodana_02",
        "S9/Jakku_02/Jakku_02"
    },
    {
        {
            "Levels/MP/Tatooine_01/Tatooine_01",
            "MOS EISLEY"
        },
        {
            "S7_2/Levels/Naboo_03/Naboo_03",
            "REPUBLIC VENATOR"
        },
        {
            "S6_2/Geonosis_02/Levels/Geonosis_02/Geonosis_02",
            "SEPARATIST DREADNAUGHT"
        },
        {
            "S9/Jakku_02/Jakku_02",
            "RESURGENT STAR DESTROYER"
        },
        {
            "S9/Takodana_02/Takodana_02",
            "MC85 STAR CRUISER"
        }
    }
}
};

GameMode GetGameMode(const char* mode);
GameLevel GetGameLevel(GameMode mode, const char* level);
} // namespace Kyber