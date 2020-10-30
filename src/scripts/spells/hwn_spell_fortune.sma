#pragma semicolon 1

#include <amxmodx>
#include <hwn>

#define PLUGIN "[Hwn] Fortune Telling Spell"
#define AUTHOR "Hedgehog Fog"

new Array:g_hSpells;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_hSpells = ArrayCreate(1, 8);

    ArrayPushCell(g_hSpells, Hwn_Wof_Spell_Register("Fish?", "Invoke"));
    ArrayPushCell(g_hSpells, Hwn_Wof_Spell_Register("Being lucky", "Invoke"));
    ArrayPushCell(g_hSpells, Hwn_Wof_Spell_Register("Wait for the next roll", "Invoke"));
}

public plugin_end()
{
    ArrayDestroy(g_hSpells);
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
    new count = ArraySize(g_hSpells);
    for (new i = 0; i < count; ++i) {
        if (spellIdx == ArrayGetCell(g_hSpells, i)) {
            return true;
        }
    }

    return false;
}
