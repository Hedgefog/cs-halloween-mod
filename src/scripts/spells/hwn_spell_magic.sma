#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Magic Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_precache() {
    Hwn_Wof_Spell_Register("Magic", "Invoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Invoke(pPlayer, Float:flTime) {
    Hwn_Player_SetEffect(pPlayer, "magic", true, 0.0);
}
