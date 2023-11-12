#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Moon Jump WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Moon Jump", "@Player_InvokeEffect", "@Player_RevokeEffect");
}

@Player_InvokeEffect(this) {
    Hwn_Player_SetEffect(this, "moonjump", true);
}

@Player_RevokeEffect(this) {
    Hwn_Player_SetEffect(this, "moonjump", false);
}
