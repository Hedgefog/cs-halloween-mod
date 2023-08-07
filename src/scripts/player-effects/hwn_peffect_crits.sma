#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "crits"

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "dmg_shock", {HWN_COLOR_PRIMARY});
}

@Player_EffectInvoke(pPlayer) {
    client_print(pPlayer, print_chat, "Crits Invoke");
    Hwn_Crits_Set(pPlayer, true);
}

@Player_EffectRevoke(pPlayer) {
    client_print(pPlayer, print_chat, "Crits Revoke");
    Hwn_Crits_Set(pPlayer, false);
}
