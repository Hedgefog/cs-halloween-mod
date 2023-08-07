#include <amxmodx>

#include <hwn>

#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Player Cosmetic 2016"
#define AUTHOR "Hedgehog Fog"

#define UNUSUAL_COLOR Float:{HWN_COLOR_PRIMARY_F}

public plugin_precache() {
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Coffin Pack",
            .iModelIndex = precache_model("models/hwn/cosmetics/coffinpack.mdl"),
            .iGroups = (PCosmetic_Group_Back),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Horns",
            .iModelIndex = precache_model("models/hwn/cosmetics/devil_horns.mdl"),
            .iGroups = (PCosmetic_Group_Mask),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Tail",
            .iModelIndex = precache_model("models/hwn/cosmetics/devil_tail.mdl"),
            .iGroups = (PCosmetic_Group_Fanny),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Devil Wings",
            .iModelIndex = precache_model("models/hwn/cosmetics/devil_wings.mdl"),
            .iGroups = (PCosmetic_Group_Back),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Garlik Flank Stake",
            .iModelIndex = precache_model("models/hwn/cosmetics/garlic_flank_stake.mdl"),
            .iGroups = (PCosmetic_Group_Legs),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Holy Hunter",
            .iModelIndex = precache_model("models/hwn/cosmetics/holy_hunter.mdl"),
            .iGroups = (PCosmetic_Group_Hat),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Pumpkin",
            .iModelIndex = precache_model("models/hwn/cosmetics/pumpkin_hat.mdl"),
            .iGroups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Silver Bullets",
            .iModelIndex = precache_model("models/hwn/cosmetics/silver_bullets.mdl"),
            .iGroups = (PCosmetic_Group_Body),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Skull",
            .iModelIndex = precache_model("models/hwn/cosmetics/skull.mdl"),
            .iGroups = (PCosmetic_Group_Mask),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Spookyhood",
            .iModelIndex = precache_model("models/hwn/cosmetics/spookyhood.mdl"),
            .iGroups = (PCosmetic_Group_Hat),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}
