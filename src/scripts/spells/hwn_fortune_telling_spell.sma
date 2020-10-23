#pragma semicolon 1

#include <amxmodx>
#include <hwn>

#define PLUGIN "[Hwn] Fortune Telling Spell"
#define AUTHOR "Hedgehog Fog"

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Fish", "Invoke");
    Hwn_Wof_Spell_Register("Being lucky", "Invoke");
    Hwn_Wof_Spell_Register("Wait for the next roll", "Invoke");
    Hwn_Wof_Spell_Register("Wait for the next roll", "Invoke");
    Hwn_Wof_Spell_Register("Dance", "Invoke");
}

public Invoke() {}
