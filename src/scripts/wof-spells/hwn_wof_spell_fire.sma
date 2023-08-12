#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <hwn>
#include <hwn_utils>
#include <hwn_wof>

#define PLUGIN "[Hwn] Fire WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Fire", "Invoke", "Revoke");
}

public Invoke(pPlayer, Float:flTime) {
    Hwn_Player_SetEffect(pPlayer, "fire", true);
}

public Revoke(pPlayer, Float:flTime) {
    Hwn_Player_SetEffect(pPlayer, "fire", false);
}
