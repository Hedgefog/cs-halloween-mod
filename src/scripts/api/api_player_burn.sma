#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#define PLUGIN    "[API] Player Burn"
#define VERSION    "0.3.2"
#define AUTHOR    "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#define CBASEPLAYER_LINUX_OFFSET 5
#define m_flVelocityModifier 108

#define TASKID_SUM_BURN        1000

#define DMG_BURN_PAINSHOCK    0.5
#define DMG_BURN_AMOUNT        4.0

new g_playerAttacker[MAX_PLAYERS + 1] = { 0, ... };

new g_flagPlayerBurn;

new g_sprFlame;
new g_sprSmoke;

new const g_szSndBurn[] = "ambience/burning1.wav";

public plugin_precache()
{
    g_sprFlame = precache_model("sprites/xffloor.spr");
    g_sprSmoke = precache_model("sprites/black_smoke3.spr");

    precache_sound(g_szSndBurn);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHam(Ham_Spawn, "player", "on_player_spawn", .Post = 1);
    RegisterHam(Ham_Killed, "player", "on_player_killed", .Post = 0);
    RegisterHam(Ham_TakeDamage, "player", "on_player_takeDamage", .Post = 1);
}

public plugin_natives()
{
    register_library("api_player_burn");
    register_native("burn_player", "native_burn_player");
    register_native("extinguish_player", "native_extinguish_player");
    register_native("is_player_burn", "native_is_player_burn");
}

/*----[ Natives ]----*/

public bool:native_is_player_burn(plugin_id, argc)
{
    new id = get_param(1);

    return is_player_burn(id);
}

public native_burn_player(plugin_id, argc)
{
    new id = get_param(1);
    new inflictor = get_param(2);
    new burnTime = get_param(3);

    burn_player(id, inflictor, burnTime);
}

public native_extinguish_player(plugin_id, argc)
{
    new id = get_param(1);

    extinguish_player(id);
}

/*----[ Private methods ]----*/

bool:is_player_burn(id)
{
    if(g_flagPlayerBurn & (1 << (id & 31)))
        return true;

    return false;
}

burn_player(id, attacker, burnTime)
{
    if(!is_user_alive(id))
        return;

    if(is_player_burn(id))
        return;

    g_flagPlayerBurn |= (1 << (id & 31));

    g_playerAttacker[id] = attacker;

    remove_task(id+TASKID_SUM_BURN);

    set_task(0.2, "task_player_burn_effect", id+TASKID_SUM_BURN, _, _, "b");
    set_task(1.0, "task_player_burn_damage", id+TASKID_SUM_BURN, _, _, "b");

    if(burnTime > 0)
        set_task(float(burnTime), "task_player_extinguish", id+TASKID_SUM_BURN);
}

extinguish_player(id)
{
    remove_task(id+TASKID_SUM_BURN);
    g_flagPlayerBurn &= ~(1 << (id & 31));

    g_playerAttacker[id] = 0;
    emit_sound(id, CHAN_VOICE, g_szSndBurn, VOL_NORM, ATTN_NORM, SND_STOP, PITCH_NORM);
}

/*----[ Events ]----*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    if(is_player_burn(id))
        extinguish_player(id);
}

public on_player_killed(victim, attacker)
{
    if(!is_player_burn(victim)) {
        return;
    }

    if(!attacker) {
        SetHamParamEntity(2, g_playerAttacker[victim]);
    }

    extinguish_player(victim);
}

public on_player_spawn(id)
{
    if(!is_user_alive(id))
        return;

    if(is_player_burn(id)) {
        extinguish_player(id);
    }
}

public on_player_takeDamage(victim, inflictor, attacker, Float:damage, damageType)
{
    if(attacker)
        return;

    if(!is_player_burn(victim))
        return;

    if(!(damageType & DMG_BURN))
        return;

    new Float:fPainShock = get_pdata_float(victim, m_flVelocityModifier, CBASEPLAYER_LINUX_OFFSET);
    fPainShock = fPainShock/DMG_BURN_PAINSHOCK*0.80;
    set_pdata_float(victim, m_flVelocityModifier, fPainShock, CBASEPLAYER_LINUX_OFFSET);
}

/*----[ Tasks ]----*/

public task_player_burn_effect(taskID)
{
    new id = taskID - TASKID_SUM_BURN;

    if(!is_user_alive(id))
        return;

    static Float:fOrigin[3];
    pev(id, pev_origin, fOrigin);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin, 0);
    write_byte(TE_SPRITE);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]);
    write_short(g_sprFlame);
    write_byte(random_num(5, 10));
    write_byte(200);
    message_end();

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, fOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, fOrigin[0]);
    engfunc(EngFunc_WriteCoord, fOrigin[1]);
    engfunc(EngFunc_WriteCoord, fOrigin[2]-48.0);
    write_short(g_sprSmoke);
    write_byte(random_num(15, 20));
    write_byte(random_num(10, 20));
    message_end();

    emit_sound(id, CHAN_VOICE, g_szSndBurn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public task_player_burn_damage(taskID)
{
    new id = taskID - TASKID_SUM_BURN;

    if(!is_user_alive(id))
        return;

    if (pev(id, pev_flags) & FL_INWATER) {
        extinguish_player(id);
        return;
    }

    ExecuteHamB(Ham_TakeDamage, id, 0, 0, DMG_BURN_AMOUNT, DMG_BURN);
}

public task_player_extinguish(taskID)
{
    new id = taskID - TASKID_SUM_BURN;
    extinguish_player(id);
}
