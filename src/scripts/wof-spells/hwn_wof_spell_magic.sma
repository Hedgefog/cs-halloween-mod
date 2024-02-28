#pragma semicolon 1

#include <amxmodx>

#include <api_player_effects>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Magic WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Magic", "@Player_InvokeEffect");
}

@Player_InvokeEffect(this, Float:flTime) {
    PlayerEffect_Set(this, "hwn-magic", true, 0.0);
}
