#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Moon Jump Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 25.0;

const EffectRadius = 48;
new const EffectColor[3] = {32, 32, 32};

new const g_szSndDetonate[] = "hwn/spells/spell_moonjump.wav";

public plugin_precache()
{
    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
    
    Hwn_Spell_Register("Moon Jump", "OnCast");
    Hwn_Wof_Spell_Register("Moon Jump", "Invoke", "Revoke");
}

/*--------------------------------[ Hooks ]--------------------------------*/


public OnPlayerSpawn(id)
{
    SetGravity(id, false);
}

public OnPlayerKilled(id)
{
    SetGravity(id, false);
}

public OnCast(id)
{
    Invoke(id);

    if (task_exists(id)) {
        remove_task(id);
    }

    set_task(EffectTime, "Revoke", id);
}

/*--------------------------------[ Methods ]--------------------------------*/

SetGravity(id, bool:value = true)
{
    if (value) {
        new Float:fGravityValue = (MOON_GRAVIY);
        set_pev(id, pev_gravity, fGravityValue);
    } else {
        set_pev(id, pev_gravity, 1.0);
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Invoke(id)
{
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    SetGravity(id, true);

    UTIL_Message_Dlight(vOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(id, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public Revoke(id)
{
    SetGravity(id, false);
}
