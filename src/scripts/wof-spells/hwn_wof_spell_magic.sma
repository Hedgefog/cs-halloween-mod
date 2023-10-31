#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Magic WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Magic", "Invoke");
}

public Invoke(pPlayer, Float:flTime) {
    Hwn_Player_SetEffect(pPlayer, "magic", true, 0.0);
}
