#pragma semicolon 1

#include <amxmodx>

#include <api_player_effects>

#include <hwn>

#define PLUGIN "[Hwn] Moon Jump Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELL_NAME "Moon Jump"

public plugin_precache() {
    Hwn_Spell_Register(
        SPELL_NAME,
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability,
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Player_CastSpell(pPlayer) {
    PlayerEffect_Set(pPlayer, "hwn-moonjump", true, 25.0);
}
