#include <amxmodx>

#include <hwn>

#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Player Cosmetic 2016"
#define AUTHOR "Hedgehog Fog"

public plugin_precache()
{
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Coffin Pack",
            .modelIndex = precache_model("models/hwn/cosmetics/coffinpack.mdl"),
            .groups = (PCosmetic_Group_Back)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Horns",
            .modelIndex = precache_model("models/hwn/cosmetics/devil_horns.mdl"),
            .groups = (PCosmetic_Group_Mask)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Tail",
            .modelIndex = precache_model("models/hwn/cosmetics/devil_tail.mdl"),
            .groups = (PCosmetic_Group_Fanny)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Wings",
            .modelIndex = precache_model("models/hwn/cosmetics/devil_wings.mdl"),
            .groups = (PCosmetic_Group_Back)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Garlik Flank Stake",
            .modelIndex = precache_model("models/hwn/cosmetics/garlic_flank_stake.mdl"),
            .groups = (PCosmetic_Group_Legs)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Holy Hunter",
            .modelIndex = precache_model("models/hwn/cosmetics/holy_hunter.mdl"),
            .groups = (PCosmetic_Group_Hat)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Pumpkin",
            .modelIndex = precache_model("models/hwn/cosmetics/pumpkin_hat.mdl"),
            .groups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Silver Bullets",
            .modelIndex = precache_model("models/hwn/cosmetics/silver_bullets.mdl"),
            .groups = (PCosmetic_Group_Body)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Skull",
            .modelIndex = precache_model("models/hwn/cosmetics/skull.mdl"),
            .groups = (PCosmetic_Group_Mask)
        )
    );
    
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Spookyhood",
            .modelIndex = precache_model("models/hwn/cosmetics/spookyhood.mdl"),
            .groups = (PCosmetic_Group_Hat)
        )
    );
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}