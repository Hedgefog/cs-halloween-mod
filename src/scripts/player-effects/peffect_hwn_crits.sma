#include <amxmodx>

#include <api_player_effects>

#include <hwn>
#include <hwn_crits>

#define PLUGIN "[Hwn] Crits Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "hwn-crits"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "dmg_shock", {HWN_COLOR_PRIMARY});
}

@Player_EffectInvoke(pPlayer) {
    Hwn_Crits_Set(pPlayer, true);
}

@Player_EffectRevoke(pPlayer) {
    Hwn_Crits_Set(pPlayer, false);
}