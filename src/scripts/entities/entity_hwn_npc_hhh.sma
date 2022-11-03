#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <astar>
#include <api_custom_entities>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN    "[Custom Entity] Hwn NPC HHH"
#define AUTHOR    "Hedgehog Fog"

#define TASKID_SUM_HIT             1000

#define ENTITY_NAME "hwn_npc_hhh"

enum _:Sequence
{
    Sequence_Idle = 0,

    Sequence_Run,

    Sequence_Attack,
    Sequence_RunAttack,
    Sequence_Shake,
    Sequence_Spawn
};

enum Action
{
    Action_Idle = 0,
    Action_Run,
    Action_Attack,
    Action_RunAttack,
    Action_Shake,
    Action_Spawn
};

enum _:HHH
{
    HHH_AStar_Idx,
    Array:HHH_AStar_Path,
    Float:HHH_AStar_Target[3],
    Float:HHH_AStar_ArrivalTime,
    Float:HHH_AStar_NextSearch
};

new const g_szSndAttack[][128] = {
    "hwn/npc/hhh/hhh_attack01.wav",
    "hwn/npc/hhh/hhh_attack02.wav",
    "hwn/npc/hhh/hhh_attack03.wav",
    "hwn/npc/hhh/hhh_attack04.wav"
};

new const g_szSndLaugh[][128] = {
    "hwn/npc/hhh/hhh_laugh01.wav",
    "hwn/npc/hhh/hhh_laugh02.wav",
    "hwn/npc/hhh/hhh_laugh03.wav",
    "hwn/npc/hhh/hhh_laugh04.wav"
};

new const g_szSndPain[][128] = {
    "hwn/npc/hhh/hhh_pain01.wav",
    "hwn/npc/hhh/hhh_pain02.wav",
    "hwn/npc/hhh/hhh_pain03.wav"
};

new const g_szSndStep[][128] = {
    "hwn/npc/hhh/hhh_step01.wav",
    "hwn/npc/hhh/hhh_step02.wav"
};

new const g_szSndHit[] = "hwn/npc/hhh/hhh_axe_hit.wav";
new const g_szSndSpawn[] = "hwn/npc/hhh/hhh_spawn.wav";
new const g_szSndDying[] = "hwn/npc/hhh/hhh_dying.wav";
new const g_szSndDeath[] = "hwn/npc/hhh/hhh_death.wav";

new const g_actions[Action][NPC_Action] = {
    {    Sequence_Idle,            Sequence_Idle,        0.0    },
    {    Sequence_Run,            Sequence_Run,        0.0    },
    {    Sequence_Attack,        Sequence_Attack,    1.0    },
    {    Sequence_RunAttack,        Sequence_RunAttack,    1.0    },
    {    Sequence_Shake,            Sequence_Shake,        2.0    },
    {    Sequence_Spawn,            Sequence_Spawn,        2.0    }
};

new Float:NPC_Health                = 4000.0;
new Float:NPC_HealthBonusPerPlayer  = 300.0;
const Float:NPC_Speed               = 300.0;
const Float:NPC_Damage              = 160.0;
const Float:NPC_HitRange            = 96.0;
const Float:NPC_HitDelay            = 0.75;
const Float:NPC_ViewRange           = 2048.0;

new g_sprBlood;
new g_sprBloodSpray;

new g_mdlGibs;

new Float:g_fThinkDelay;

new g_astarEnt[10];

new g_cvarUseAstar;

new g_ceHandler;
new g_bossHandler;

new g_maxPlayers;

public plugin_precache()
{
    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/headless_hatman.mdl"),
        .vMins = Float:{-16.0, -16.0, -48.0},
        .vMaxs = Float:{16.0, 16.0, 48.0},
        .preset = CEPreset_NPC
    );

    g_bossHandler = Hwn_Bosses_Register(ENTITY_NAME, "Horseless Headless Horsemann");

    g_sprBlood        = precache_model("sprites/blood.spr");
    g_sprBloodSpray    = precache_model("sprites/bloodspray.spr");

    g_mdlGibs = precache_model("models/hwn/npc/headless_hatman_gibs.mdl");

    for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
        precache_sound(g_szSndAttack[i]);
    }

    for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
        precache_sound(g_szSndLaugh[i]);
    }

    for (new i = 0; i < sizeof(g_szSndPain); ++i) {
        precache_sound(g_szSndPain[i]);
    }

    for (new i = 0; i < sizeof(g_szSndStep); ++i) {
        precache_sound(g_szSndStep[i]);
    }

    precache_sound(g_szSndHit);
    precache_sound(g_szSndSpawn);
    precache_sound(g_szSndDying);
    precache_sound(g_szSndDeath);

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");

    RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "OnThink", .Post = 1);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTakeDamage", .Post = 1);

    g_cvarUseAstar = register_cvar("hwn_npc_hhh_use_astar", "1");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver()
{
    NPC_Health += NPC_HealthBonusPerPlayer;
}

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    NPC_Health -= NPC_HealthBonusPerPlayer;
}

public Hwn_Fw_ConfigLoaded()
{
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
}

public Hwn_Bosses_Fw_BossTeleport(ent, handler)
{
    if (handler != g_bossHandler) {
        return;
    }

    AStar_Reset(ent);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_Dlight(vOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    new Float:fRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        fRenderColor[i] *= 0.2;
    }

    set_pev(ent, pev_rendermode, kRenderNormal);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 4.0);
    set_pev(ent, pev_rendercolor, fRenderColor);
    set_pev(ent, pev_fuser1, 0.0);

    set_pev(ent, pev_health, NPC_Health);

    NPC_Create(ent);
    HHH_Create(ent);
    AStar_Reset(ent);

    engfunc(EngFunc_DropToFloor, ent);

    set_pev(ent, pev_takedamage, DAMAGE_NO);
    NPC_EmitVoice(ent, g_szSndSpawn);
    NPC_PlayAction(ent, g_actions[Action_Spawn]);

    set_pev(ent, pev_nextthink, get_gametime() + 6.0);
}

public OnRemove(ent)
{
    remove_task(ent+TASKID_SUM_HIT);

    {
        new Float:vOrigin[3];
        pev(ent, pev_origin, vOrigin);

        UTIL_Message_Dlight(vOrigin, 32, {HWN_COLOR_PRIMARY}, 10, 32);
    }

    AStar_Reset(ent);

    NPC_Destroy(ent);
    HHH_Destroy(ent);
}

public OnKill(ent)
{
    new deadflag = pev(ent, pev_deadflag);

    if (deadflag == DEAD_NO) {
        NPC_EmitVoice(ent, g_szSndDying, .supercede = true);
        NPC_PlayAction(ent, g_actions[Action_Shake], .supercede = true);

        NPC_StopMovement(ent);
        set_pev(ent, pev_takedamage, DAMAGE_NO);
        set_pev(ent, pev_deadflag, DEAD_DYING);

        remove_task(ent);
        set_pev(ent, pev_nextthink, get_gametime() + 2.0);
    } else if (deadflag == DEAD_DEAD) {
        return PLUGIN_CONTINUE;
    }

    return PLUGIN_HANDLED;
}

public OnThink(ent)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    if (!pev_valid(ent)) {
        return HAM_IGNORED;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    if (pev(ent, pev_deadflag) == DEAD_DYING)
    {
        UTIL_Message_ExplodeModel(vOrigin, random_float(-512.0, 512.0), g_mdlGibs, 5, 25);
        NPC_EmitVoice(ent, g_szSndDeath, .supercede = true);
        set_pev(ent, pev_deadflag, DEAD_DEAD);
        CE_Kill(ent);

        return HAM_HANDLED;
    }

    if (pev(ent, pev_takedamage) == DAMAGE_NO) {
        set_pev(ent, pev_takedamage, DAMAGE_AIM);
    }

    new enemy = NPC_GetEnemy(ent);
    new Action:action = Action_Idle;

    static Float:fLastUpdate;
    pev(ent, pev_fuser1, fLastUpdate);
    new bool:shouldUpdate = get_gametime() - fLastUpdate >= g_fThinkDelay;

    if (enemy) {
        Attack(ent, enemy, action, shouldUpdate);
        enemy = NPC_GetEnemy(ent);
    }

    if (enemy && shouldUpdate) {
        AStar_Reset(ent);
    }

    if (shouldUpdate) {
        if (!enemy) {
            NPC_FindEnemy(ent, g_maxPlayers, NPC_ViewRange);
            enemy = NPC_GetEnemy(ent);
        }

        if (!enemy && get_pcvar_num(g_cvarUseAstar) > 0) {
            AStar_Attack(ent, action);
        }

        {
            static lifeTime;
            if (!lifeTime) {
                lifeTime = UTIL_DelayToLifeTime(g_fThinkDelay);
            }

            UTIL_Message_Dlight(vOrigin, 4, {HWN_COLOR_PRIMARY}, lifeTime, 0);

            engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
            write_byte(TE_ELIGHT);
            write_short(0);
            engfunc(EngFunc_WriteCoord, vOrigin[0]);
            engfunc(EngFunc_WriteCoord, vOrigin[1]);
            engfunc(EngFunc_WriteCoord, vOrigin[2]+42.0);
            write_coord(16);
            write_byte(64);
            write_byte(52);
            write_byte(4);
            write_byte(lifeTime);
            write_coord(0);
            message_end();
        }

        NPC_PlayAction(ent, g_actions[action]);

        set_pev(ent, pev_fuser1, get_gametime());
    }

    set_pev(ent, pev_nextthink, get_gametime() + 0.01);

    return HAM_HANDLED;
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);

    UTIL_Message_BloodSprite(vEnd, g_sprBloodSpray, g_sprBlood, 212, floatround(fDamage/4));
    if (random(100) < 10) {
        NPC_EmitVoice(ent, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }

    return HAM_HANDLED;
}

public OnTakeDamage(ent, inflictor, attacker, Float:fDamage)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    if (UTIL_IsPlayer(attacker) && NPC_IsValidEnemy(attacker)) {
        static Float:vOrigin[3];
        pev(ent, pev_origin, vOrigin);

        static Float:vTarget[3];
        pev(attacker, pev_origin, vTarget);

        if (get_distance_f(vOrigin, vTarget) <= NPC_HitRange && NPC_IsVisible(ent, vTarget)) {
            if (get_gametime() - NPC_GetEnemyTime(ent) > 6.0) {
                NPC_SetEnemy(ent, attacker);
            }
        }
    }
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public AStar_OnPathDone(astarIdx, Array:path, Float:Distance, NodesAdded, NodesValidated, NodesCleared)
{
    if (path == Invalid_Array) {
        return;
    }

    new ent = g_astarEnt[astarIdx];

    if (!pev_valid(ent)) {
        return;
    }

    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    new Array:hhh = HHH_Get(ent);
    ArraySetCell(hhh, HHH_AStar_Path, path);
}

/*--------------------------------[ Methods ]--------------------------------*/

HHH_Create(ent)
{
    new Array:hhh = ArrayCreate(1, HHH);
    for (new i = 0; i < HHH; ++i) {
        ArrayPushCell(hhh, 0);
    }

    ArraySetArray(hhh, HHH_AStar_Target, Float:{0.0, 0.0, 0.0});

    set_pev(ent, pev_iuser2, hhh);
}

HHH_Destroy(ent)
{
    new Array:hhh = any:pev(ent, pev_iuser2);

    new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
    if (path != Invalid_Array) {
        ArrayDestroy(path);
    }

    ArrayDestroy(hhh);
}

Array:HHH_Get(ent)
{
    return Array:pev(ent, pev_iuser2);
}

bool:Attack(ent, target, &Action:action, bool:checkTarget = false)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vTarget[3];

    if (checkTarget) {
        if (!NPC_GetTarget(ent, NPC_Speed, vTarget)) {
            NPC_SetEnemy(ent, 0);
            NPC_StopMovement(ent);
            set_pev(ent, pev_vuser1, vOrigin);
            return false;
        }

        set_pev(ent, pev_vuser1, vTarget);
    } else {
        pev(ent, pev_vuser1, vTarget);
    }

    new bool:canHit = NPC_CanHit(ent, target, NPC_HitRange);
    if (checkTarget) {
        if (canHit && !task_exists(ent+TASKID_SUM_HIT)) {
            NPC_EmitVoice(ent, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.5);
            set_task(NPC_HitDelay, "TaskHit", ent+TASKID_SUM_HIT);
            action = Action_Attack;
        } else {
            if (random(100) < 10) {
                NPC_EmitVoice(ent, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
            }
        }
    }

    static Float:vTargetVelocity[3];
    pev(target, pev_velocity, vTargetVelocity);

    new bool:shouldRun = !canHit || xs_vec_len(vTargetVelocity) > NPC_HitRange;

    if (shouldRun) {
        ScreenShakeEffect(ent);
        NPC_EmitFootStep(ent, g_szSndStep[random(sizeof(g_szSndStep))]);
        action = (action == Action_Attack) ? Action_RunAttack : Action_Run;
        NPC_MoveToTarget(ent, vTarget, NPC_Speed);
    } else {
        NPC_StopMovement(ent);
    }

    return true;
}

AStar_FindPath(ent)
{
    new enemy = pev(ent, pev_enemy);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vTarget[3];
    pev(enemy, pev_origin, vTarget);

    static Float:vMins[3];
    pev(ent, pev_mins, vMins);

    new astarIdx = AStarThreaded(vOrigin, vTarget, "AStar_OnPathDone", 30, DONT_IGNORE_MONSTERS, ent, floatround(-vMins[2]), 50);

    new Array:hhh = HHH_Get(ent);
    ArraySetCell(hhh, HHH_AStar_Idx, astarIdx);

    if (astarIdx != -1) {
        g_astarEnt[astarIdx] = ent;
    }
}

bool:AStar_Attack(ent, &Action:action)
{
    new enemy = pev(ent, pev_enemy);

    new Float:fGametime = get_gametime();

    new Array:hhh = HHH_Get(ent);
    new astarIdx = ArrayGetCell(hhh, HHH_AStar_Idx);
    new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
    new Float:fNextSearch = ArrayGetCell(hhh, HHH_AStar_NextSearch);

    if (astarIdx == -1) {
        if (NPC_IsValidEnemy(enemy) || NPC_FindEnemy(ent, g_maxPlayers, NPC_ViewRange, .reachableOnly = false, .visibleOnly = false)) {
            AStar_FindPath(ent);
            ArraySetCell(hhh, HHH_AStar_NextSearch, fGametime + 10.0);
        }

        // NPC_PlayAction(ent, g_actions[Action_Idle]);
    } else if (path != Invalid_Array) {
        AStar_ProcessPath(ent, path);
        NPC_EmitFootStep(ent, g_szSndStep[random(sizeof(g_szSndStep))]);
        action = Action_Run;
    } else {
        if (fGametime > fNextSearch) {
            AStar_Reset(ent);
        }
    }
}

AStar_ProcessPath(ent, Array:path)
{
    new Array:hhh = HHH_Get(ent);

    new Float:fArrivalTime = ArrayGetCell(hhh, HHH_AStar_ArrivalTime);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vTarget[3];
    ArrayGetArray(hhh, HHH_AStar_Target, vTarget);

    if (ArraySize(path) > 0) {
        if (get_gametime() >= fArrivalTime) {
            static curStep[3];
            ArrayGetArray(path, 0, curStep);
            ArrayDeleteItem(path, 0);

            for (new i = 0; i < 3; ++i) {
                vTarget[i] = float(curStep[i]);
            }

            if (NPC_IsReachable(ent, vTarget)) {
                new Float:fDistance = get_distance_f(vOrigin, vTarget);
                ArraySetArray(hhh, HHH_AStar_Target, vTarget);
                ArraySetCell(hhh, HHH_AStar_ArrivalTime, get_gametime() + (fDistance/NPC_Speed));
            } else {
                AStar_Reset(ent);
            }
        }

        NPC_PlayAction(ent, g_actions[Action_Run]);
        NPC_MoveToTarget(ent, vTarget, NPC_Speed);
    } else {
        vOrigin[2] = vTarget[2];
        if (get_distance_f(vOrigin, vTarget) <= 64.0 && get_gametime() >= fArrivalTime) {
            AStar_Reset(ent);
            NPC_PlayAction(ent, g_actions[Action_Idle]);
        }
    }
}

AStar_Reset(ent)
{
    new Array:hhh = HHH_Get(ent);

    new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
    if (path != Invalid_Array) {
        ArrayDestroy(path);
    }

    new astarIdx = ArrayGetCell(hhh, HHH_AStar_Idx);
    AStarAbort(astarIdx);

    ArraySetCell(hhh, HHH_AStar_Idx, -1);
    ArraySetCell(hhh, HHH_AStar_Path, Invalid_Array);
}

ScreenShakeEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    for (new id = 1; id <= g_maxPlayers; ++id) {
        if (!is_user_connected(id)) {
            continue;
        }

        if (!is_user_alive(id)) {
            continue;
        }

        static Float:vUserOrigin[3];
        pev(id, pev_origin, vUserOrigin);

        if (get_distance_f(vOrigin, vUserOrigin) > 512.0) {
            continue;
        }

        message_begin(MSG_ONE, get_user_msgid("ScreenShake"), .player = id);
        write_short(UTIL_FixedUnsigned16(8.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<8));
        message_end();
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskHit(taskID)
{
    new ent = taskID - TASKID_SUM_HIT;
    if (NPC_Hit(ent, NPC_Damage, NPC_HitRange, NPC_HitDelay, Float:{0.0, 0.0, 16.0})) {
        emit_sound(ent, CHAN_WEAPON, g_szSndHit, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }
}
