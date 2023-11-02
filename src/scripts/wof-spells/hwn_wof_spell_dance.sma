#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Dance WoF Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 8.0;

new g_iWofSpell;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    g_iWofSpell = Hwn_Wof_Spell_Register("Dance", "Invoke");
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_iWofSpell == iSpell) {
        Hwn_Wof_Abort();
    }
}

public Invoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "dance", true, EffectTime);
}
