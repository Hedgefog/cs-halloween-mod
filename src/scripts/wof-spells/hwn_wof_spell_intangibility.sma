#pragma semicolon 1

#include <amxmodx>

#include <api_player_effects>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Intangibility WoF Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Intangibility", "@Player_InvokeEffect", "@Player_RevokeEffect");
}

@Player_InvokeEffect(this) {
    PlayerEffect_Set(this, "hwn-intangibility", true);
}

@Player_RevokeEffect(this) {
    PlayerEffect_Set(this, "hwn-intangibility", false);
}
