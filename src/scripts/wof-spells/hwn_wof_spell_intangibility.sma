#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Intangibility WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Intangibility", "Invoke", "Revoke");
}

public Invoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "intangibility", true);
}

public Revoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "intangibility", false);
}
