#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Invisibility WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Invisibility", "@Player_InvokeEffect", "@Player_RevokeEffect");
}

@Player_InvokeEffect(this) {
    Hwn_Player_SetEffect(this, "invisibility", true);
}

@Player_RevokeEffect(this) {
    Hwn_Player_SetEffect(this, "invisibility", false);
}
