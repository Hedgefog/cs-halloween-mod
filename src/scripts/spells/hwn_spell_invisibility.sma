#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Invisibility Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_precache() {
    Hwn_Spell_Register(
        "Invisibility",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Protection,
        "Cast"
    );

    Hwn_Wof_Spell_Register("Invisibility", "Invoke", "Revoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Cast(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "invisibility", true, 9.9);
}

public Invoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "invisibility", true);
}

public Revoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "invisibility", false);
}
