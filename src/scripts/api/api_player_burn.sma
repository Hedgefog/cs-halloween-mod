#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>

#define PLUGIN    "[API] Player Burn"
#define VERSION    "0.3.2"
#define AUTHOR    "Hedgehog Fog"

#define CBASEPLAYER_LINUX_OFFSET 5
#define m_flVelocityModifier 108

#define TASKID_SUM_BURN        1000

#define DMG_BURN_PAINSHOCK    0.5
#define DMG_BURN_AMOUNT        4.0

new g_rgPlayerAttacker[MAX_PLAYERS + 1];

new g_iPlayerBurnFlag;

new g_iFlameModelIndex;
new g_iSmokeModelIndex;

new const g_szSndBurn[] = "ambience/burning1.wav";

public plugin_precache() {
    g_iFlameModelIndex = precache_model("sprites/xffloor.spr");
    g_iSmokeModelIndex = precache_model("sprites/black_smoke3.spr");

    precache_sound(g_szSndBurn);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "on_player_spawn", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "on_player_killed", .Post = 0);
    RegisterHamPlayer(Ham_TakeDamage, "on_player_takeDamage", .Post = 1);
}

public plugin_natives() {
    register_library("api_player_burn");
    register_native("burn_player", "native_burn_player");
    register_native("extinguish_player", "native_extinguish_player");
    register_native("is_player_burn", "native_is_player_burn");
}

/*----[ Natives ]----*/

public bool:native_is_player_burn(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    return is_player_burn(pPlayer);
}

public native_burn_player(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new pInflictor = get_param(2);
    new burnTime = get_param(3);

    burn_player(pPlayer, pInflictor, burnTime);
}

public native_extinguish_player(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    extinguish_player(pPlayer);
}

/*----[ Private methods ]----*/

bool:is_player_burn(pPlayer) {
    if (g_iPlayerBurnFlag & BIT(pPlayer & 31))
        return true;

    return false;
}

burn_player(pPlayer, pAttacker, burnTime) {
    if (!is_user_alive(pPlayer))
        return;

    if (is_player_burn(pPlayer))
        return;

    g_iPlayerBurnFlag |= BIT(pPlayer & 31);

    g_rgPlayerAttacker[pPlayer] = pAttacker;

    remove_task(pPlayer+TASKID_SUM_BURN);

    set_task(0.2, "task_player_burn_effect", pPlayer+TASKID_SUM_BURN, _, _, "b");
    set_task(1.0, "task_player_burn_damage", pPlayer+TASKID_SUM_BURN, _, _, "b");

    if (burnTime > 0)
        set_task(float(burnTime), "task_player_extinguish", pPlayer+TASKID_SUM_BURN);
}

extinguish_player(pPlayer) {
    remove_task(pPlayer+TASKID_SUM_BURN);
    g_iPlayerBurnFlag &= ~BIT(pPlayer & 31);

    g_rgPlayerAttacker[pPlayer] = 0;
    emit_sound(pPlayer, CHAN_VOICE, g_szSndBurn, VOL_NORM, ATTN_NORM, SND_STOP, PITCH_NORM);
}

/*----[ Events ]----*/

public client_disconnected(pPlayer) {
    if (is_player_burn(pPlayer))
        extinguish_player(pPlayer);
}

public on_player_killed(victim, pAttacker) {
    if (!is_player_burn(victim)) {
        return;
    }

    if (!pAttacker) {
        SetHamParamEntity(2, g_rgPlayerAttacker[victim]);
    }

    extinguish_player(victim);
}

public on_player_spawn(pPlayer) {
    if (!is_user_alive(pPlayer))
        return;

    if (is_player_burn(pPlayer)) {
        extinguish_player(pPlayer);
    }
}

public on_player_takeDamage(victim, pInflictor, pAttacker, Float:damage, damageType) {
    if (pAttacker)
        return;

    if (!is_player_burn(victim))
        return;

    if (!(damageType & DMG_BURN))
        return;

    new Float:flPainShock = get_pdata_float(victim, m_flVelocityModifier, CBASEPLAYER_LINUX_OFFSET);
    flPainShock = flPainShock/DMG_BURN_PAINSHOCK*0.80;
    set_pdata_float(victim, m_flVelocityModifier, flPainShock, CBASEPLAYER_LINUX_OFFSET);
}

/*----[ Tasks ]----*/

public task_player_burn_effect(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_BURN;

    if (!is_user_alive(pPlayer))
        return;

    static Float:flOrigin[3];
    pev(pPlayer, pev_origin, flOrigin);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0);
    write_byte(TE_SPRITE);
    engfunc(EngFunc_WriteCoord, flOrigin[0]);
    engfunc(EngFunc_WriteCoord, flOrigin[1]);
    engfunc(EngFunc_WriteCoord, flOrigin[2]);
    write_short(g_iFlameModelIndex);
    write_byte(random_num(5, 10));
    write_byte(200);
    message_end();

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, flOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, flOrigin[0]);
    engfunc(EngFunc_WriteCoord, flOrigin[1]);
    engfunc(EngFunc_WriteCoord, flOrigin[2]-48.0);
    write_short(g_iSmokeModelIndex);
    write_byte(random_num(15, 20));
    write_byte(random_num(10, 20));
    message_end();

    emit_sound(pPlayer, CHAN_VOICE, g_szSndBurn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public task_player_burn_damage(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_BURN;

    if (!is_user_alive(pPlayer))
        return;

    if (pev(pPlayer, pev_flags) & FL_INWATER) {
        extinguish_player(pPlayer);
        return;
    }

    ExecuteHamB(Ham_TakeDamage, pPlayer, 0, 0, DMG_BURN_AMOUNT, DMG_BURN);
}

public task_player_extinguish(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_BURN;
    extinguish_player(pPlayer);
}
