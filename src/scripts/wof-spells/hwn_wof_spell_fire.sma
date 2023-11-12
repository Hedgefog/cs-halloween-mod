#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Fire WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Fire", "@Player_InvokeEffect", "@Player_RevokeEffect");
}

@Player_InvokeEffect(this, Float:flTime) {
    Hwn_Player_SetEffect(this, "fire", true);
}

@Player_RevokeEffect(this, Float:flTime) {
    Hwn_Player_SetEffect(this, "fire", false);
}
