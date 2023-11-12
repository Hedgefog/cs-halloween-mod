#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Invisibility Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELL_NAME "Invisibility"

public plugin_precache() {
    Hwn_Spell_Register(
        SPELL_NAME,
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Protection,
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Player_CastSpell(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "invisibility", true, 9.9);
}
