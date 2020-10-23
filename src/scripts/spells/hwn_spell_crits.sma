#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Crits Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 10.0;

const EffectRadius = 32;
new const EffectColor[3] = {HWN_COLOR_PURPLE};

new const g_szSndDetonate[] = "hwn/spells/spell_crit.wav";

public plugin_precache()
{
    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
    
    Hwn_Spell_Register("Crits", "OnCast");
    Hwn_Wof_Spell_Register("Crits", "Invoke", "Revoke");
}

/*--------------------------------[ Hooks ]--------------------------------*/


public OnPlayerSpawn(id)
{
    Hwn_Crits_Set(id, false);
}

public OnPlayerKilled(id)
{
    Hwn_Crits_Set(id, false);
}

public OnCast(id)
{   
    Invoke(id);

    if (task_exists(id)) {
        remove_task(id);
    }

    set_task(EffectTime, "Revoke", id);
}

public Invoke(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    Hwn_Crits_Set(id, true);

    UTIL_Message_Dlight(vOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(id, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public Revoke(id)
{
    Hwn_Crits_Set(id, false);
}
