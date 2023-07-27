#pragma semicolon 1

#include <amxmodx>
#include <hwn>

#define PLUGIN "[Hwn] Magic Spell"
#define AUTHOR "Hedgehog Fog"

new g_hWofSpell;

public plugin_precache() {
    g_hWofSpell = Hwn_Wof_Spell_Register("Magic", "Invoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Invoke(pPlayer, Float:flTime) {
    new iSpellsNum = Hwn_Spell_GetCount();
    if (!iSpellsNum) {
        return;
    }

    new iSpell = Hwn_Spell_GetPlayerSpell(pPlayer);
    if (iSpell >= 0) {
        return;
    }

    Hwn_Spell_SetPlayerSpell(pPlayer, random(iSpellsNum), 1);
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_hWofSpell != iSpell) {
        return;
    }
}
