#pragma semicolon 1

#include <amxmodx>
#include <hwn>

#define PLUGIN "[Hwn] Magic Spell"
#define AUTHOR "Hedgehog Fog"

new g_hWofSpell;

public plugin_precache()
{
    g_hWofSpell = Hwn_Wof_Spell_Register("Magic", "Invoke");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Invoke(id, Float:fTime)
{
    new spellCount = Hwn_Spell_GetCount();
    if (!spellCount) {
        return;
    }

    new playerSpell = Hwn_Spell_GetPlayerSpell(id);
    if (playerSpell >= 0) {
        return;
    }

    Hwn_Spell_SetPlayerSpell(id, random(spellCount), 1);
}

public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    if (g_hWofSpell != spellIdx) {
        return;
    }
}
