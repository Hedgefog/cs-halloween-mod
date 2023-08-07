#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Moon Jump Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_precache() {
    Hwn_Spell_Register(
        "Moon Jump",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability,
        "Cast"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Cast(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "moonjump", true, 25.0);
}
