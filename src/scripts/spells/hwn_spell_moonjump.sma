#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Moon Jump Spell"
#define AUTHOR "Hedgehog Fog"

#define GRAVITATIONAL_ACCELERATION_EARTH 9.807
#define GRAVITATIONAL_ACCELERATION_MOON 1.62

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
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    SetGravity(id, true);

    UTIL_Message_Dlight(vOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(id, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    if (task_exists(id)) {
        remove_task(id);
    }

    set_task(EffectTime, "TaskRemoveGravity", id);
}

/*--------------------------------[ Methods ]--------------------------------*/

SetGravity(id, bool:value = true)
{
    if (value) {
        new Float:fGravityValue = (GRAVITATIONAL_ACCELERATION_MOON / GRAVITATIONAL_ACCELERATION_EARTH);
        set_pev(id, pev_gravity, fGravityValue);
    } else {
        set_pev(id, pev_gravity, 1.0);
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskRemoveGravity(id)
{
    SetGravity(id, false);
}
