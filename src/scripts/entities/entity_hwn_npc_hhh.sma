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

enum _:Sequence {
    Sequence_Idle = 0,

    Sequence_Run,

    Sequence_Attack,
    Sequence_RunAttack,
    Sequence_Shake,
    Sequence_Spawn
};

enum Action {
    Action_Idle = 0,
    Action_Run,
    Action_Attack,
    Action_RunAttack,
    Action_Shake,
    Action_Spawn
};

enum _:HHH {
    Float:HHH_NextAction,
    Float:HHH_NextSmokeEmit,
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

new g_iBloodModelIndex;
new g_iBloodSprayModelIndex;
new g_iSmokeModelIndex;

new g_mdlGibs;

new g_pAstar[10];

new g_pCvarUseAstar;

new g_iCeHandler;
new g_bossHandler;

public plugin_precache() {
    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/headless_hatman.mdl"),
        .vMins = Float:{-16.0, -16.0, -48.0},
        .vMaxs = Float:{16.0, 16.0, 48.0},
        .preset = CEPreset_NPC
    );

    g_bossHandler = Hwn_Bosses_Register(ENTITY_NAME, "Horseless Headless Horsemann");

    g_iBloodModelIndex        = precache_model("sprites/blood.spr");
    g_iBloodSprayModelIndex    = precache_model("sprites/bloodspray.spr");

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
    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke_tiny.spr");

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");

    RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "HamHook_Base_Think_Post", .Post = 1);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    g_pCvarUseAstar = register_cvar("hwn_npc_hhh_use_astar", "1");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver() {
    NPC_Health += NPC_HealthBonusPerPlayer;
}

public client_disconnected(pPlayer) {
    NPC_Health -= NPC_HealthBonusPerPlayer;
}

public Hwn_Bosses_Fw_BossTeleport(pEntity, handler) {
    if (handler != g_bossHandler) {
        return;
    }

    AStar_Reset(pEntity);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        flRenderColor[i] *= 0.2;
    }

    set_pev(pEntity, pev_rendermode, kRenderNormal);
    set_pev(pEntity, pev_renderfx, kRenderFxGlowShell);
    set_pev(pEntity, pev_renderamt, 4.0);
    set_pev(pEntity, pev_rendercolor, flRenderColor);
    set_pev(pEntity, pev_fuser1, 0.0);
    set_pev(pEntity, pev_team, 666);

    set_pev(pEntity, pev_health, NPC_Health);

    NPC_Create(pEntity);
    HHH_Create(pEntity);
    AStar_Reset(pEntity);

    engfunc(EngFunc_DropToFloor, pEntity);

    set_pev(pEntity, pev_takedamage, DAMAGE_NO);
    NPC_EmitVoice(pEntity, g_szSndSpawn);
    NPC_PlayAction(pEntity, g_actions[Action_Spawn]);

    new Array:hhh = HHH_Get(pEntity);
    ArraySetCell(hhh, HHH_NextAction, get_gametime() + 6.0);

    set_pev(pEntity, pev_nextthink, get_gametime());
}

public OnRemove(pEntity) {
    remove_task(pEntity+TASKID_SUM_HIT);

    {
        new Float:vecOrigin[3];
        pev(pEntity, pev_origin, vecOrigin);

        UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 10, 32);
    }

    AStar_Reset(pEntity);

    NPC_Destroy(pEntity);
    HHH_Destroy(pEntity);
}

public OnKill(pEntity) {
    new iDeadFlag = pev(pEntity, pev_deadflag);

    if (iDeadFlag == DEAD_NO) {
        NPC_EmitVoice(pEntity, g_szSndDying, .supercede = true);
        NPC_PlayAction(pEntity, g_actions[Action_Shake], .supercede = true);

        NPC_StopMovement(pEntity);
        set_pev(pEntity, pev_takedamage, DAMAGE_NO);
        set_pev(pEntity, pev_deadflag, DEAD_DYING);

        remove_task(pEntity);
        set_pev(pEntity, pev_nextthink, get_gametime() + 2.0);
    } else if (iDeadFlag == DEAD_DEAD) {
        return PLUGIN_CONTINUE;
    }

    return PLUGIN_HANDLED;
}

public HamHook_Base_Think_Post(pEntity) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return HAM_IGNORED;
    }

    if (!pev_valid(pEntity)) {
        return HAM_IGNORED;
    }

    new Float:flRate = Hwn_GetUpdateRate();

    new Array:hhh = HHH_Get(pEntity);

    new Float:flNextAction = ArrayGetCell(hhh, HHH_NextAction);
    if (flNextAction < get_gametime()) {
        static Float:vecOrigin[3];
        pev(pEntity, pev_origin, vecOrigin);

        if (pev(pEntity, pev_deadflag) == DEAD_DYING)
        {
            UTIL_Message_ExplodeModel(vecOrigin, random_float(-512.0, 512.0), g_mdlGibs, 5, 25);
            NPC_EmitVoice(pEntity, g_szSndDeath, .supercede = true);
            set_pev(pEntity, pev_deadflag, DEAD_DEAD);
            CE_Kill(pEntity);

            return HAM_HANDLED;
        }

        if (pev(pEntity, pev_takedamage) == DAMAGE_NO) {
            set_pev(pEntity, pev_takedamage, DAMAGE_AIM);
        }

        new pEnemy = NPC_GetEnemy(pEntity);
        new Action:action = Action_Idle;

        static Float:flLastUpdate;
        pev(pEntity, pev_fuser1, flLastUpdate);
        new bool:shouldUpdate = get_gametime() - flLastUpdate >= flRate;

        if (pEnemy) {
            Attack(pEntity, pEnemy, action, shouldUpdate);
            pEnemy = NPC_GetEnemy(pEntity);
        }

        if (pEnemy && shouldUpdate) {
            AStar_Reset(pEntity);
        }

        if (shouldUpdate) {
            if (!pEnemy) {
                NPC_FindEnemy(pEntity, 96.0, .allowMonsters = true);
                pEnemy = NPC_GetEnemy(pEntity);
            }

            if (!pEnemy) {
                NPC_FindEnemy(pEntity, NPC_ViewRange, .allowMonsters = false);
                pEnemy = NPC_GetEnemy(pEntity);
            }

            if (!pEnemy && get_pcvar_num(g_pCvarUseAstar) > 0) {
                AStar_Attack(pEntity, action);
            }

            {
                new iLifeTime = min(floatround(flRate * 10), 1);

                UTIL_Message_Dlight(vecOrigin, 4, {HWN_COLOR_PRIMARY}, iLifeTime, 0);

                engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
                write_byte(TE_ELIGHT);
                write_short(0);
                engfunc(EngFunc_WriteCoord, vecOrigin[0]);
                engfunc(EngFunc_WriteCoord, vecOrigin[1]);
                engfunc(EngFunc_WriteCoord, vecOrigin[2]+42.0);
                write_coord(16);
                write_byte(64);
                write_byte(52);
                write_byte(4);
                write_byte(iLifeTime);
                write_coord(0);
                message_end();
            }

            NPC_PlayAction(pEntity, g_actions[action]);

            set_pev(pEntity, pev_fuser1, get_gametime());
        }
    }

    EmitSmoke(pEntity);
    set_pev(pEntity, pev_nextthink, get_gametime() + 0.01);

    return HAM_HANDLED;
}

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return HAM_IGNORED;
    }

    static Float:vecEnd[3];
    get_tr2(pTrace, TR_vecEndPos, vecEnd);

    UTIL_Message_BloodSprite(vecEnd, g_iBloodSprayModelIndex, g_iBloodModelIndex, 212, floatround(flDamage/4));
    if (random(100) < 10) {
        NPC_EmitVoice(pEntity, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }

    return HAM_HANDLED;
}

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    if (IS_PLAYER(pAttacker) && NPC_IsValidEnemy(pAttacker)) {
        static Float:vecOrigin[3];
        pev(pEntity, pev_origin, vecOrigin);

        static Float:vecTarget[3];
        pev(pAttacker, pev_origin, vecTarget);

        if (get_distance_f(vecOrigin, vecTarget) <= NPC_HitRange && NPC_IsVisible(pEntity, vecTarget)) {
            if (get_gametime() - NPC_GetEnemyTime(pEntity) > 6.0) {
                NPC_SetEnemy(pEntity, pAttacker);
            }
        }
    }
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public AStar_OnPathDone(astarIdx, Array:path, Float:Distance, NodesAdded, NodesValidated, NodesCleared) {
    if (path == Invalid_Array) {
        return;
    }

    new pEntity = g_pAstar[astarIdx];

    if (!pev_valid(pEntity)) {
        return;
    }

    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    new Array:hhh = HHH_Get(pEntity);
    ArraySetCell(hhh, HHH_AStar_Path, path);
}

/*--------------------------------[ Methods ]--------------------------------*/

HHH_Create(pEntity) {
    new Array:hhh = ArrayCreate(1, HHH);
    for (new i = 0; i < HHH; ++i) {
        ArrayPushCell(hhh, 0);
    }

    ArraySetArray(hhh, HHH_AStar_Target, Float:{0.0, 0.0, 0.0});
    ArraySetCell(hhh, HHH_NextAction, get_gametime());
    ArraySetCell(hhh, HHH_NextSmokeEmit, get_gametime());

    set_pev(pEntity, pev_iuser2, hhh);
}

HHH_Destroy(pEntity) {
    new Array:hhh = any:pev(pEntity, pev_iuser2);

    new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
    if (path != Invalid_Array) {
        ArrayDestroy(path);
    }

    ArrayDestroy(hhh);
}

Array:HHH_Get(pEntity) {
    return Array:pev(pEntity, pev_iuser2);
}

bool:Attack(pEntity, pTarget, &Action:action, bool:checkTarget = false) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTarget[3];

    if (checkTarget) {
        if (!NPC_GetTarget(pEntity, NPC_Speed, vecTarget)) {
            NPC_SetEnemy(pEntity, 0);
            NPC_StopMovement(pEntity);
            set_pev(pEntity, pev_vuser1, vecOrigin);
            return false;
        }

        set_pev(pEntity, pev_vuser1, vecTarget);
    } else {
        pev(pEntity, pev_vuser1, vecTarget);
    }

    new bool:canHit = NPC_CanHit(pEntity, pTarget, NPC_HitRange);
    if (checkTarget) {
        if (canHit && !task_exists(pEntity+TASKID_SUM_HIT)) {
            NPC_EmitVoice(pEntity, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.5);
            set_task(NPC_HitDelay, "Task_Hit", pEntity+TASKID_SUM_HIT);
            action = Action_Attack;
        } else {
            if (random(100) < 10) {
                NPC_EmitVoice(pEntity, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
            }
        }
    }

    static Float:vecTargetVelocity[3];
    pev(pTarget, pev_velocity, vecTargetVelocity);

    new bool:shouldRun = !canHit || xs_vec_len(vecTargetVelocity) > NPC_HitRange;

    if (shouldRun) {
        ScreenShakeEffect(pEntity);
        NPC_EmitFootStep(pEntity, g_szSndStep[random(sizeof(g_szSndStep))]);
        action = (action == Action_Attack) ? Action_RunAttack : Action_Run;
        NPC_MoveToTarget(pEntity, vecTarget, NPC_Speed);
    } else {
        NPC_StopMovement(pEntity);
    }

    return true;
}

AStar_FindPath(pEntity) {
    new pEnemy = pev(pEntity, pev_enemy);

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    pev(pEnemy, pev_origin, vecTarget);

    static Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    new astarIdx = AStarThreaded(vecOrigin, vecTarget, "AStar_OnPathDone", 30, DONT_IGNORE_MONSTERS, pEntity, floatround(-vecMins[2]), 50);

    new Array:hhh = HHH_Get(pEntity);
    ArraySetCell(hhh, HHH_AStar_Idx, astarIdx);

    if (astarIdx != -1) {
        g_pAstar[astarIdx] = pEntity;
    }
}

bool:AStar_Attack(pEntity, &Action:action) {
    new Float:flGametime = get_gametime();

    new Array:hhh = HHH_Get(pEntity);
    new astarIdx = ArrayGetCell(hhh, HHH_AStar_Idx);
    new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
    new Float:flNextSearch = ArrayGetCell(hhh, HHH_AStar_NextSearch);

    if (astarIdx == -1) {
        new pEnemy = NPC_GetEnemy(pEntity);
        if (pEnemy || NPC_FindEnemy(pEntity, NPC_ViewRange, .reachableOnly = false, .visibleOnly = false, .allowMonsters = false)) {
            AStar_FindPath(pEntity);
            ArraySetCell(hhh, HHH_AStar_NextSearch, flGametime + 10.0);
        }

        // NPC_PlayAction(pEntity, g_actions[Action_Idle]);
    } else if (path != Invalid_Array) {
        AStar_ProcessPath(pEntity, path);
        NPC_EmitFootStep(pEntity, g_szSndStep[random(sizeof(g_szSndStep))]);
        action = Action_Run;
    } else {
        if (flGametime > flNextSearch) {
            AStar_Reset(pEntity);
        }
    }
}

AStar_ProcessPath(pEntity, Array:path) {
    new Array:hhh = HHH_Get(pEntity);

    new Float:flArrivalTime = ArrayGetCell(hhh, HHH_AStar_ArrivalTime);

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    ArrayGetArray(hhh, HHH_AStar_Target, vecTarget);

    if (ArraySize(path) > 0) {
        if (get_gametime() >= flArrivalTime) {
            static curStep[3];
            ArrayGetArray(path, 0, curStep);
            ArrayDeleteItem(path, 0);

            for (new i = 0; i < 3; ++i) {
                vecTarget[i] = float(curStep[i]);
            }

            if (NPC_IsReachable(pEntity, vecTarget)) {
                new Float:flDistance = get_distance_f(vecOrigin, vecTarget);
                ArraySetArray(hhh, HHH_AStar_Target, vecTarget);
                ArraySetCell(hhh, HHH_AStar_ArrivalTime, get_gametime() + (flDistance/NPC_Speed));
            } else {
                AStar_Reset(pEntity);
            }
        }

        NPC_PlayAction(pEntity, g_actions[Action_Run]);
        NPC_MoveToTarget(pEntity, vecTarget, NPC_Speed);
    } else {
        vecOrigin[2] = vecTarget[2];
        if (get_distance_f(vecOrigin, vecTarget) <= 64.0 && get_gametime() >= flArrivalTime) {
            AStar_Reset(pEntity);
            NPC_PlayAction(pEntity, g_actions[Action_Idle]);
        }
    }
}

AStar_Reset(pEntity) {
    new Array:hhh = HHH_Get(pEntity);

    new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
    if (path != Invalid_Array) {
        ArrayDestroy(path);
    }

    new astarIdx = ArrayGetCell(hhh, HHH_AStar_Idx);
    AStarAbort(astarIdx);

    ArraySetCell(hhh, HHH_AStar_Idx, -1);
    ArraySetCell(hhh, HHH_AStar_Path, Invalid_Array);
}

ScreenShakeEffect(pEntity) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_connected(pPlayer)) {
            continue;
        }

        if (!is_user_alive(pPlayer)) {
            continue;
        }

        static Float:vecUserOrigin[3];
        pev(pPlayer, pev_origin, vecUserOrigin);

        if (get_distance_f(vecOrigin, vecUserOrigin) > 512.0) {
            continue;
        }

        message_begin(MSG_ONE, get_user_msgid("ScreenShake"), .player = pPlayer);
        write_short(UTIL_FixedUnsigned16(8.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<8));
        message_end();
    }
}

EmitSmoke(pEntity) {
    new Array:hhh = HHH_Get(pEntity);

    new Float:flNextSmokeEmit = ArrayGetCell(hhh, HHH_NextSmokeEmit);

    if (get_gametime() < flNextSmokeEmit) {
        return;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    vecOrigin[2] += random_float(-16.0, 16.0);
    UTIL_Message_FireField(vecOrigin, 8, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);

    ArraySetCell(hhh, HHH_NextSmokeEmit, get_gametime() + 0.1);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Hit(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_HIT;
    if (NPC_Hit(pEntity, NPC_Damage, NPC_HitRange, NPC_HitDelay, Float:{0.0, 0.0, 16.0})) {
        emit_sound(pEntity, CHAN_WEAPON, g_szSndHit, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }
}
