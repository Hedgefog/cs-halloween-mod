#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Power Up Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_precache() {
    Hwn_Spell_Register(
        "Power Up",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Heal | Hwn_SpellFlag_Rare,
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Player_CastSpell(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "powerup", true, 10.0);
}
