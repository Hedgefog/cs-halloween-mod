#pragma semicolon 1

#include <amxmodx>
#include <hwn>

#define PLUGIN "[Hwn] Fortune Telling Spell"
#define AUTHOR "Hedgehog Fog"

enum Spell {
    Spell_Fish,
    Spell_BeingLucky,
    Spell_Wait
}

new g_hSpells[Spell];

public plugin_precache()
{
    g_hSpells[Spell_Fish] = Hwn_Wof_Spell_Register("Fish?", "Invoke");
    g_hSpells[Spell_BeingLucky] = Hwn_Wof_Spell_Register("Being lucky", "Invoke");
    g_hSpells[Spell_Wait] = Hwn_Wof_Spell_Register("Wait for the next roll", "Invoke");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Invoke() {}

public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    if (isFortuneSpell(spellIdx)) {
        Hwn_Wof_Abort();
    }
}

isFortuneSpell(spellIdx)
{
    for (new i = 0; i < sizeof(g_hSpells); ++i) {
        if (spellIdx == g_hSpells[Spell:i]) {
            return true;
        }
    }

    return false;
}
