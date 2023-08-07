#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Power Up WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Power Up", "Invoke", "Revoke");
}

public Invoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "powerup", true);
}

public Revoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "powerup", false);
}
