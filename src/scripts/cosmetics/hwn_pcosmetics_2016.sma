#include <amxmodx>

#include <hwn>

#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Player Cosmetic 2016"
#define AUTHOR "Hedgehog Fog"

#define UNUSUAL_COLOR Float:{HWN_COLOR_PURPLE_F}

public plugin_precache()
{
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Coffin Pack",
            .modelIndex = precache_model("models/hwn/cosmetics/coffinpack.mdl"),
            .groups = (PCosmetic_Group_Back),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Horns",
            .modelIndex = precache_model("models/hwn/cosmetics/devil_horns.mdl"),
            .groups = (PCosmetic_Group_Mask),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Tail",
            .modelIndex = precache_model("models/hwn/cosmetics/devil_tail.mdl"),
            .groups = (PCosmetic_Group_Fanny),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Wings",
            .modelIndex = precache_model("models/hwn/cosmetics/devil_wings.mdl"),
            .groups = (PCosmetic_Group_Back),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Garlik Flank Stake",
            .modelIndex = precache_model("models/hwn/cosmetics/garlic_flank_stake.mdl"),
            .groups = (PCosmetic_Group_Legs),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Holy Hunter",
            .modelIndex = precache_model("models/hwn/cosmetics/holy_hunter.mdl"),
            .groups = (PCosmetic_Group_Hat),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Pumpkin",
            .modelIndex = precache_model("models/hwn/cosmetics/pumpkin_hat.mdl"),
            .groups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Silver Bullets",
            .modelIndex = precache_model("models/hwn/cosmetics/silver_bullets.mdl"),
            .groups = (PCosmetic_Group_Body),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Skull",
            .modelIndex = precache_model("models/hwn/cosmetics/skull.mdl"),
            .groups = (PCosmetic_Group_Mask),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Spookyhood",
            .modelIndex = precache_model("models/hwn/cosmetics/spookyhood.mdl"),
            .groups = (PCosmetic_Group_Hat),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}