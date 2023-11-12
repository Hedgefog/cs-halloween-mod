#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Crits WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Crits", "@Player_InvokeEffect", "@Player_RevokeEffect");
}

@Player_InvokeEffect(this) {
    Hwn_Player_SetEffect(this, "crits", true);
}

@Player_RevokeEffect(this) {
    Hwn_Player_SetEffect(this, "crits", false);
}
