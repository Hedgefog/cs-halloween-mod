#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Dance Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 8.0;

new g_hWofSpell;

public plugin_precache() {
    g_hWofSpell = Hwn_Wof_Spell_Register("Dance", "Invoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_hWofSpell == iSpell) {
        Hwn_Wof_Abort();
    }
}

public Invoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "dance", true, EffectTime);
}
