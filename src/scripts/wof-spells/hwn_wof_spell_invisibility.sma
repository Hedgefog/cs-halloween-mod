#pragma semicolon 1

#include <amxmodx>

#include <api_player_effects>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Invisibility WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Invisibility", "@Player_InvokeEffect", "@Player_RevokeEffect");
}

@Player_InvokeEffect(this) {
    PlayerEffect_Set(this, "hwn-invisibility", true);
}

@Player_RevokeEffect(this) {
    PlayerEffect_Set(this, "hwn-invisibility", false);
}
