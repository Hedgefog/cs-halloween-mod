#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <hwn_wof>

#define PLUGIN "[Hwn] Overheal WoF Spell"
#define AUTHOR "Hedgehog Fog"

new g_iWofSpell;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_iWofSpell = Hwn_Wof_Spell_Register("Overheal", "@Player_InvokeEffect");
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_iWofSpell == iSpell) {
        Hwn_Wof_Abort();
    }
}

@Player_InvokeEffect(this) {
    Hwn_Player_SetEffect(this, "overheal", true, 0.0);
}
