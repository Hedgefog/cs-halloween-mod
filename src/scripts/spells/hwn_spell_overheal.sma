#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Overheal Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELL_NAME "Overheal"

public plugin_precache() {
    Hwn_Spell_Register(
        SPELL_NAME,
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Heal | Hwn_SpellFlag_Radius,
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Player_CastSpell(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "overheal", true, 0.0);
}
