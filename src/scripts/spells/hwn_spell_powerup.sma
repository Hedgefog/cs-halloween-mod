#pragma semicolon 1

#include <amxmodx>

#include <api_player_effects>

#include <hwn>

#define PLUGIN "[Hwn] Power Up Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELL_NAME "Power Up"

public plugin_precache() {
    Hwn_Spell_Register(
        SPELL_NAME,
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Heal | Hwn_SpellFlag_Rare,
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Player_CastSpell(pPlayer) {
    PlayerEffect_Set(pPlayer, "hwn-powerup", true, 10.0);
}
