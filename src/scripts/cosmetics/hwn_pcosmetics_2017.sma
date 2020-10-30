#include <amxmodx>

#include <hwn>

#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Player Cosmetic 2017"
#define AUTHOR "Hedgehog Fog"

#define UNUSUAL_COLOR Float:{HWN_COLOR_SECONDARY_F}

public plugin_precache()
{
    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Ethereal Hood",
            .modelIndex = precache_model("models/hwn/cosmetics/ethereal_hood.mdl"),
            .groups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Hallowed Headcase",
            .modelIndex = precache_model("models/hwn/cosmetics/hallowed_headcase.mdl"),
            .groups = (PCosmetic_Group_Mask),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Horsemann's Hand-Me-Down",
            .modelIndex = precache_model("models/hwn/cosmetics/hhh_cape.mdl"),
            .groups = (PCosmetic_Group_Cape),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Nightmare Hunter",
            .modelIndex = precache_model("models/hwn/cosmetics/nightmare_fedora.mdl"),
            .groups = (PCosmetic_Group_Hat),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );

    Hwn_Cosmetic_Register(
        PCosmetic_Register(
            .szName = "Manneater",
            .modelIndex = precache_model("models/hwn/cosmetics/manneater.mdl"),
            .groups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask),
            .fUnusualColor = UNUSUAL_COLOR
        )
    );
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}