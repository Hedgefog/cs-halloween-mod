#pragma semicolon 1

#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Overheal Spell"
#define AUTHOR "Hedgehog Fog"

new g_hWofSpell;

public plugin_precache() {
    Hwn_Spell_Register(
        "Overheal",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Heal | Hwn_SpellFlag_Radius,
        "Invoke"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Overheal", "Invoke");
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
    Hwn_Player_SetEffect(pPlayer, "overheal", true, 0.0);
}
