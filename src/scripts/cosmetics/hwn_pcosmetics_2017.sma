#include <amxmodx>

#include <hwn>

#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Player Cosmetic 2017"
#define AUTHOR "Hedgehog Fog"

#define UNUSUAL_COLOR Float:{HWN_COLOR_SECONDARY_F}

public plugin_precache() {
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Ethereal Hood",
            .iModelIndex = precache_model("models/hwn/cosmetics/ethereal_hood.mdl"),
            .iGroups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Hallowed Headcase",
            .iModelIndex = precache_model("models/hwn/cosmetics/hallowed_headcase.mdl"),
            .iGroups = (PCosmetic_Group_Mask),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Horsemann's Hand-Me-Down",
            .iModelIndex = precache_model("models/hwn/cosmetics/hhh_cape.mdl"),
            .iGroups = (PCosmetic_Group_Cape),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Nightmare Hunter",
            .iModelIndex = precache_model("models/hwn/cosmetics/nightmare_fedora.mdl"),
            .iGroups = (PCosmetic_Group_Hat),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Manneater",
            .iModelIndex = precache_model("models/hwn/cosmetics/manneater.mdl"),
            .iGroups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask),
            .flUnusualColor = UNUSUAL_COLOR
        )
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}
