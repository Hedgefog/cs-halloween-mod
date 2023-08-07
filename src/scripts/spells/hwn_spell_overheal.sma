#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Overheal Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_precache() {
    Hwn_Spell_Register(
        "Overheal",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Heal | Hwn_SpellFlag_Radius,
        "Cast"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Cast(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "overheal", true, 0.0);
}
