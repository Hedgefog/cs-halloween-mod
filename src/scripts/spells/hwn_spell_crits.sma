#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Crits Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_precache() {
    Hwn_Spell_Register(
        "Crits",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Rare,
        "Cast"
    );

    Hwn_Wof_Spell_Register("Crits", "Invoke", "Revoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Cast(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "crits", true, 10.0);
}

public Invoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "crits", true);
}

public Revoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "crits", false);
}
