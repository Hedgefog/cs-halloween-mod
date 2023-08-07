#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Overheal WoF Spell"
#define AUTHOR "Hedgehog Fog"

new g_hWofSpell;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_hWofSpell = Hwn_Wof_Spell_Register("Overheal", "Invoke");
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_hWofSpell == iSpell) {
        Hwn_Wof_Abort();
    }
}

public Invoke(pPlayer) {
    Hwn_Player_SetEffect(pPlayer, "overheal", true, 0.0);
}
