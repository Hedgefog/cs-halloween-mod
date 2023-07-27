#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN    "[Custom Entity] Hwn NPC Monoculus"
#define AUTHOR    "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_monoculus"
#define PORTAL_ENTITY_NAME "hwn_monoculus_portal"

#define TASKID_SUM_FLOAT            1000
#define TASKID_SUM_SHOT             2000
#define TASKID_SUM_CALM_DOWN        3000
#define TASKID_SUM_REMOVE_STUN      4000
#define TASKID_SUM_PUSH_BACK_END    5000
#define TASKID_SUM_JUMP_TO_PORTAL   6000
#define TASKID_SUM_TELEPORT         7000

#define ZERO_VECTOR_F Float:{0.0, 0.0, 0.0}

#define MONOCULUS_ROCKET_SPEED 720.0
#define MONOCULUS_PUSHBACK_SPEED 128.0
#define MONOCULUS_MIN_HEIGHT 128.0
#define MONOCULUS_MAX_HEIGHT 256.0
#define MONOCULUS_SPAWN_ROCKET_DISTANCE 80.0

enum _:Sequence {
    Sequence_Idle = 0,
    Sequence_Stunned,
    Sequence_Attack1,
    Sequence_Attack2,
    Sequence_Attack3,
    Sequence_Spawn,
    Sequence_Laugh,
    Sequence_TeleportIn,
    Sequence_TeleportOut,
    Sequence_Death,
    Sequence_LookAround1,
    Sequence_LookAround2,
    Sequence_LookAround3,
    Sequence_Escape
};

enum Action {
    Action_Idle = 0,
    Action_Stunned,
    Action_Attack,
    Action_AngryAttack,
    Action_Spawn,
    Action_Laugh,
    Action_TeleportIn,
    Action_TeleportOut,
    Action_Death,
    Action_LookAround
};

enum _:Monoculus {
    Float:Monoculus_DamageToStun,
    bool:Monoculus_IsAngry,
    bool:Monoculus_IsStunned,
    bool:Monoculus_NextPortal,
    bool:Monoculus_LastAction,
    bool:Monoculus_NextAction,
    bool:Monoculus_NextSmokeEmit
};

new const g_szSndAttack[][128] = {
    "hwn/npc/monoculus/monoculus_attack01.wav",
    "hwn/npc/monoculus/monoculus_attack02.wav"
};

new const g_szSndLaugh[][128] = {
    "hwn/npc/monoculus/monoculus_laugh01.wav",
    "hwn/npc/monoculus/monoculus_laugh02.wav",
    "hwn/npc/monoculus/monoculus_laugh03.wav"
};

new const g_szSndPain[][128] = {
    "hwn/npc/monoculus/monoculus_pain01.wav"
};

new const g_szSndStunned[][128] = {
    "hwn/npc/monoculus/monoculus_stunned01.wav",
    "hwn/npc/monoculus/monoculus_stunned02.wav",
    "hwn/npc/monoculus/monoculus_stunned03.wav",
    "hwn/npc/monoculus/monoculus_stunned04.wav",
    "hwn/npc/monoculus/monoculus_stunned05.wav"
};

new const g_szSndSpawn[] = "hwn/npc/monoculus/monoculus_teleport.wav";
new const g_szSndDeath[] = "hwn/npc/monoculus/monoculus_died.wav";
new const g_szSndMoved[] = "hwn/npc/monoculus/monoculus_moved.wav";

new const g_actions[Action][NPC_Action] = {
    {Sequence_Idle, Sequence_Idle, 0.0},
    {Sequence_Stunned, Sequence_Stunned, 4.5},
    {Sequence_Attack1, Sequence_Attack1, 1.0},
    {Sequence_Attack2, Sequence_Attack3, 2.0},
    {Sequence_Spawn, Sequence_Spawn, 4.5},
    {Sequence_Laugh, Sequence_Laugh, 1.3},
    {Sequence_TeleportIn, Sequence_TeleportIn, 1.0},
    {Sequence_TeleportOut, Sequence_TeleportOut, 1.0},
    {Sequence_Death, Sequence_Death, 8.36},
    {Sequence_LookAround1, Sequence_LookAround3, 1.0}
};

const Float:NPC_Health = 8000.0;
const Float:NPC_HealthPerLevel = 3000.0;
const Float:NPC_Speed = 16.0;
const Float:NPC_HitRange = 3072.0;
const Float:NPC_AttackDelay = 0.33;

new g_iBloodModelIndex;
new g_iBloodSprayModelIndex;
new g_iSmokeModelIndex;

new g_pCvarAngryTime;
new g_pCvarDamageToStun;
new g_pCvarJumpTimeMin;
new g_pCvarJumpTimeMax;

new g_iCeHandler;
new g_iBossHandler;

new Array:g_irgPortals;
new Array:g_irgPortalAngles;
new g_iLevel = 0;

public plugin_precache() {
    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/monoculus.mdl"),
        .vMins = Float:{-48.0, -48.0, -48.0},
        .vMaxs = Float:{48.0, 48.0, 48.0},
        .preset = CEPreset_NPC
    );

    g_iBossHandler = Hwn_Bosses_Register(ENTITY_NAME, "Monoculus");

    g_iBloodModelIndex = precache_model("sprites/blood.spr");
    g_iBloodSprayModelIndex = precache_model("sprites/bloodspray.spr");

    for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
        precache_sound(g_szSndAttack[i]);
    }

    for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
        precache_sound(g_szSndLaugh[i]);
    }

    for (new i = 0; i < sizeof(g_szSndPain); ++i) {
        precache_sound(g_szSndPain[i]);
    }

    for (new i = 0; i < sizeof(g_szSndStunned); ++i) {
        precache_sound(g_szSndStunned[i]);
    }

    precache_sound(g_szSndSpawn);
    precache_sound(g_szSndDeath);
    precache_sound(g_szSndMoved);

    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke.spr");

    CE_RegisterHook(CEFunction_Spawn, PORTAL_ENTITY_NAME, "OnPortalSpawn");

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");

    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarAngryTime = register_cvar("hwn_npc_monoculus_angry_time", "15.0");
    g_pCvarDamageToStun = register_cvar("hwn_npc_monoculus_dmg_to_stun", "2000.0");
    g_pCvarJumpTimeMin = register_cvar("hwn_npc_monoculus_jump_time_min", "10.0");
    g_pCvarJumpTimeMax = register_cvar("hwn_npc_monoculus_jump_time_max", "20.0");
}

public plugin_end() {
    if (g_irgPortals != Invalid_Array) {
        ArrayDestroy(g_irgPortals);
        ArrayDestroy(g_irgPortalAngles);
    }
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Bosses_Fw_BossTeleport(pEntity, handler) {
    if (handler != g_iBossHandler) {
        return;
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPortalSpawn(pEntity) {
    if (g_irgPortals == Invalid_Array) {
        g_irgPortals = ArrayCreate(3);
        g_irgPortalAngles = ArrayCreate(3);
    }

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    ArrayPushArray(g_irgPortals, vecOrigin);

    new Float:vecAngles[3];
    pev(pEntity, pev_angles, vecAngles);
    ArrayPushArray(g_irgPortalAngles, vecAngles);

    CE_Remove(pEntity);
}

public OnSpawn(pEntity) {
    new Float:flHealth = NPC_Health + (g_iLevel * NPC_HealthPerLevel);

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    set_pev(pEntity, pev_health, flHealth);
    set_pev(pEntity, pev_movetype, MOVETYPE_FLY);

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        flRenderColor[i] *= 0.2;
    }

    set_pev(pEntity, pev_rendermode, kRenderNormal);
    set_pev(pEntity, pev_renderfx, kRenderFxGlowShell);
    set_pev(pEntity, pev_renderamt, 4.0);
    set_pev(pEntity, pev_rendercolor, flRenderColor);

    NPC_Create(pEntity, 0.0);
    new Array:irgData = Monoculus_Create(pEntity);

    engfunc(EngFunc_DropToFloor, pEntity);

    set_pev(pEntity, pev_takedamage, DAMAGE_NO);
    NPC_EmitVoice(pEntity, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 1.0);
    NPC_PlayAction(pEntity, g_actions[Action_Spawn]);

    ArraySetCell(irgData, Monoculus_IsStunned, false);
    ArraySetCell(irgData, Monoculus_DamageToStun, get_pcvar_float(g_pCvarDamageToStun));
    ArraySetCell(irgData, Monoculus_IsAngry, false);
    ArraySetCell(irgData, Monoculus_LastAction, get_gametime());
    ArraySetCell(irgData, Monoculus_NextAction, get_gametime() + g_actions[Action_Spawn][NPC_Action_Time]);
    ArraySetCell(irgData, Monoculus_NextSmokeEmit, get_gametime());

    ClearTasks(pEntity);
    CreateJumpToPortalTask(pEntity);

    set_task(Hwn_GetUpdateRate(), "Task_Think", pEntity, _, _, "b");
    set_task(1.0, "Task_Float", pEntity + TASKID_SUM_FLOAT, _, _, "b");
}

public OnRemove(pEntity) {
    ClearTasks(pEntity);
    remove_task(pEntity);

    {
        new Float:vecOrigin[3];
        pev(pEntity, pev_origin, vecOrigin);
        TeleportEffect(vecOrigin);
    }

    NPC_Destroy(pEntity);
    Monoculus_Destroy(pEntity);
}

public OnKill(pEntity) {
    new iDeadFlag = pev(pEntity, pev_deadflag);

    if (iDeadFlag == DEAD_NO) {
        new Array:irgData = Monoculus_Get(pEntity);

        NPC_PlayAction(pEntity, g_actions[Action_Death], .supercede = true);

        set_pev(pEntity, pev_takedamage, DAMAGE_NO);
        set_pev(pEntity, pev_velocity, ZERO_VECTOR_F);
        set_pev(pEntity, pev_deadflag, DEAD_DYING);

        ClearTasks(pEntity);
        ArraySetCell(irgData, Monoculus_NextAction, get_gametime() + g_actions[Action_Death][NPC_Action_Time]);
    } else if (iDeadFlag == DEAD_DEAD) {
        g_iLevel++;
        return PLUGIN_CONTINUE;
    }

    return PLUGIN_HANDLED;
}

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return HAM_IGNORED;
    }

    static Float:vecEnd[3];
    get_tr2(pTrace, TR_vecEndPos, vecEnd);

    UTIL_Message_BloodSprite(vecEnd, g_iBloodSprayModelIndex, g_iBloodModelIndex, 212, floatround(flDamage/4));

    return HAM_HANDLED;
}

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    new Array:irgData = Monoculus_Get(pEntity);

    new Float:flDamageToStun = ArrayGetCell(irgData, Monoculus_DamageToStun);
    flDamageToStun -= flDamage;

    if (random(100) < 10) {
        NPC_EmitVoice(pEntity, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }

    if (flDamageToStun <= 0) {
        flDamageToStun = get_pcvar_float(g_pCvarDamageToStun);
        Stun(pEntity);
    }

    ArraySetCell(irgData, Monoculus_DamageToStun, flDamageToStun);

    if (random_num(0, 100) < 5) {
        MakeAngry(pEntity);
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

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    if (!pKiller || g_iCeHandler != CE_GetHandlerByEntity(pKiller)) {
        return;
    }

    if (random_num(0, 100) < 30) {
        Laugh(pKiller);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

Array:Monoculus_Create(pEntity) {
    new Array:irgData = ArrayCreate(1, Monoculus);
    for (new i = 0; i < Monoculus; ++i) {
        ArrayPushCell(irgData, 0);
    }

    set_pev(pEntity, pev_iuser2, irgData);

    return irgData;
}

Monoculus_Destroy(pEntity) {
    new Array:irgData = any:pev(pEntity, pev_iuser2);

    ArrayDestroy(irgData);
}

Array:Monoculus_Get(pEntity) {
    return Array:pev(pEntity, pev_iuser2);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Think(pEntity) {
    if (!pev_valid(pEntity)) {
        return;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Array:irgData = Monoculus_Get(pEntity);
    new Float:flNextAction = ArrayGetCell(irgData, Monoculus_NextAction);
    if (flNextAction < get_gametime()) {
        if (pev(pEntity, pev_deadflag) == DEAD_DYING) {
            NPC_EmitVoice(pEntity, g_szSndDeath, .supercede = true);
            set_pev(pEntity, pev_deadflag, DEAD_DEAD);
            CE_Kill(pEntity);

            return;
        }

        if (pev(pEntity, pev_takedamage) == DAMAGE_NO) {
            set_pev(pEntity, pev_takedamage, DAMAGE_AIM);
            ArraySetCell(irgData, Monoculus_LastAction, get_gametime());
        }

        new bool:bIsStunned = ArrayGetCell(irgData, Monoculus_IsStunned);

        if (!bIsStunned) {
            new pEnemy = NPC_GetEnemy(pEntity);
            if (!pEnemy || !Attack(pEntity, pEnemy)) {
                if (random_num(0, 100) < 5) {
                    LookAround(pEntity);
                }

                NPC_FindEnemy(pEntity, .allowMonsters = false);
                NPC_PlayAction(pEntity, g_actions[Action_Idle]);
            }

            new Float:flLastAction = ArrayGetCell(irgData, Monoculus_LastAction);
            if (get_gametime() - flLastAction > 5.0) {
                JumpToPortal(pEntity);
            }
        }
    }

    EmitSmoke(pEntity);
}

bool:Attack(pEntity, pTarget) {
    new Array:irgData = Monoculus_Get(pEntity);

    static Float:vecTarget[3];
    pev(pTarget, pev_origin, vecTarget);

    if (!NPC_IsVisible(pEntity, vecTarget)) {
        return false;
    }

    if (NPC_CanHit(pEntity, pTarget, NPC_HitRange)) {
        new bool:bIsAngry = ArrayGetCell(irgData, Monoculus_IsAngry);

        if (bIsAngry) {
            AngryShot(pEntity);
        } else {
            Shot(pEntity);
        }
    } else {
        if (task_exists(pEntity + TASKID_SUM_PUSH_BACK_END)) {
            NPC_MoveToTarget(pEntity, vecTarget, 0.0);
        } else {
            NPC_MoveToTarget(pEntity, vecTarget, NPC_Speed, 90.0);
        }

        NPC_PlayAction(pEntity, g_actions[Action_Idle]);
    }

    ArraySetCell(irgData, Monoculus_LastAction, get_gametime());

    return true;
}

BaseShot(pEntity, Float:attackDelay) {
    set_pev(pEntity, pev_velocity, ZERO_VECTOR_F);

    new Array:npcData = NPC_GetData(pEntity);
    ArraySetCell(npcData, NPC_NextAttack, get_gametime() + attackDelay);
}

Shot(pEntity) {
    set_task(NPC_AttackDelay, "Task_Shot", pEntity+TASKID_SUM_SHOT, _, _, "a", 1);

    NPC_PlayAction(pEntity, g_actions[Action_Attack]);
    BaseShot(pEntity, g_actions[Action_Attack][NPC_Action_Time] + 0.1);
}

AngryShot(pEntity) {
    set_task(NPC_AttackDelay, "Task_Shot", pEntity+TASKID_SUM_SHOT, _, _, "a", 3);

    NPC_PlayAction(pEntity, g_actions[Action_AngryAttack]);
    BaseShot(pEntity, g_actions[Action_AngryAttack][NPC_Action_Time] + 0.1);
}

Laugh(pEntity) {
    NPC_PlayAction(pEntity, g_actions[Action_Laugh]);
    NPC_EmitVoice(pEntity, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}

LookAround(pEntity) {
    NPC_PlayAction(pEntity, g_actions[Action_LookAround]);
}

Stun(pEntity) {
    set_pev(pEntity, pev_velocity, ZERO_VECTOR_F);

    new Array:irgData = Monoculus_Get(pEntity);
    ArraySetCell(irgData, Monoculus_IsStunned, true);

    NPC_EmitVoice(pEntity, g_szSndStunned[random(sizeof(g_szSndStunned))], 1.0);
    NPC_PlayAction(pEntity, g_actions[Action_Stunned], .supercede = true);

    remove_task(pEntity+TASKID_SUM_SHOT);
    remove_task(pEntity+TASKID_SUM_JUMP_TO_PORTAL);
    set_task(g_actions[Action_Stunned][NPC_Action_Time], "Task_RemoveStun", pEntity+TASKID_SUM_REMOVE_STUN);
    ArraySetCell(irgData, Monoculus_LastAction, get_gametime());
}

MakeAngry(pEntity) {
    new Array:irgData = Monoculus_Get(pEntity);

    new bool:bIsAngry = ArrayGetCell(irgData, Monoculus_IsAngry);

    if (!bIsAngry) {
        ArraySetCell(irgData, Monoculus_IsAngry, true);
        set_task(get_pcvar_float(g_pCvarAngryTime), "Task_CalmDown", pEntity+TASKID_SUM_CALM_DOWN);
    }

    ArraySetCell(irgData, Monoculus_LastAction, get_gametime());
}

SetHeight(pEntity, Float:flHeight, Float:flSpeed = NPC_Speed) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:flDistanceToFloor = UTIL_GetDistanceToFloor(pEntity, vecOrigin);
    if (flDistanceToFloor == -1.0) {
        set_pev(pEntity, pev_velocity, ZERO_VECTOR_F);
        return;
    }

    static Float:vecVelocity[3];
    pev(pEntity, pev_velocity, vecVelocity);

    new iDirection = (flDistanceToFloor > flHeight) ? -1 : 1;
    vecVelocity[2] = flSpeed * iDirection;

    set_pev(pEntity, pev_velocity, vecVelocity);
}

AlignHeight(pEntity, const Float:vecTarget[3]) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
 
    new Float:flHeightDiff = vecOrigin[2] - vecTarget[2];
    vecOrigin[2] -= flHeightDiff;

    new Float:flDistanceToFloor = UTIL_GetDistanceToFloor(pEntity, vecOrigin);
    if (flDistanceToFloor == -1.0) {
        return;
    }

    SetHeight(pEntity, flDistanceToFloor < MONOCULUS_MIN_HEIGHT ? MONOCULUS_MIN_HEIGHT : flDistanceToFloor);
}

SpawnRocket(pEntity) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecDirection[3];
    UTIL_GetDirectionVector(pEntity, vecDirection);

    {
        static Float:vecTmp[3];
        xs_vec_mul_scalar(vecDirection, MONOCULUS_SPAWN_ROCKET_DISTANCE, vecTmp);
        xs_vec_add(vecOrigin, vecTmp, vecOrigin);
    }

    // todo: add spawn rocket logic
    new pRocket = CE_Create("hwn_monoculus_rocket", vecOrigin);

    if (!pRocket) {
        return;
    }

    static Float:vecAngles[3];
    pev(pEntity, pev_angles, vecAngles);

    set_pev(pRocket, pev_angles, vecAngles);
    set_pev(pRocket, pev_owner, pEntity);

    static Float:vecVelocity[3];
    xs_vec_mul_scalar(vecDirection, MONOCULUS_ROCKET_SPEED, vecVelocity);
    set_pev(pRocket, pev_velocity, vecVelocity);

    dllfunc(DLLFunc_Spawn, pRocket);
}

PushBack(pEntity) {
    static Float:vecVelocity[3];
    UTIL_GetDirectionVector(pEntity, vecVelocity, -MONOCULUS_PUSHBACK_SPEED);
    set_pev(pEntity, pev_velocity, vecVelocity);

    set_task(0.25, "Task_PushBackEnd", pEntity+TASKID_SUM_PUSH_BACK_END);
}

JumpToPortal(pEntity) {
    if (g_irgPortals == Invalid_Array) {
        return;
    }

    new iSize = ArraySize(g_irgPortals);

    if (!iSize) {
        return;
    }

    new Array:irgData = Monoculus_Get(pEntity);

    new bool:bIsStunned = ArrayGetCell(irgData, Monoculus_IsStunned);
    if (bIsStunned) {
        return;
    }

    new iPortal = random(iSize);
    if (iPortal == ArrayGetCell(irgData, Monoculus_NextPortal)) {
        return;
    }

    ArraySetCell(irgData, Monoculus_NextPortal, iPortal);

    NPC_PlayAction(pEntity, g_actions[Action_TeleportIn]);
    remove_task(pEntity+TASKID_SUM_TELEPORT);
    set_task(g_actions[Action_TeleportIn][NPC_Action_Time], "Task_Teleport", pEntity+TASKID_SUM_TELEPORT);
    ArraySetCell(irgData, Monoculus_LastAction, get_gametime());
}

CreateJumpToPortalTask(pEntity) {
    new Float:flMinTime = get_pcvar_float(g_pCvarJumpTimeMin);
    new Float:flMaxTime = get_pcvar_float(g_pCvarJumpTimeMax);
    set_task(random_float(flMinTime, flMaxTime), "Task_JumpToPortal", pEntity+TASKID_SUM_JUMP_TO_PORTAL);
}

TeleportEffect(const Float:vecOrigin[3]) {
    UTIL_Message_FireField(vecOrigin, 64, g_iSmokeModelIndex, 10, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 20);
    UTIL_Message_Dlight(vecOrigin, 48, {HWN_COLOR_PRIMARY}, 5, 32);
}

EmitSmoke(pEntity) {
    new Array:irgData = Monoculus_Get(pEntity);

    new Float:flNextSmokeEmit = ArrayGetCell(irgData, Monoculus_NextSmokeEmit);

    if (get_gametime() < flNextSmokeEmit) {
        return;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    UTIL_Message_FireField(vecOrigin, 16, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);

    ArraySetCell(irgData, Monoculus_NextSmokeEmit, get_gametime() + 0.1);
}

ClearTasks(pEntity) {
    remove_task(pEntity + TASKID_SUM_FLOAT);
    remove_task(pEntity + TASKID_SUM_SHOT);
    remove_task(pEntity + TASKID_SUM_CALM_DOWN);
    remove_task(pEntity + TASKID_SUM_REMOVE_STUN);
    remove_task(pEntity + TASKID_SUM_PUSH_BACK_END);
    remove_task(pEntity + TASKID_SUM_JUMP_TO_PORTAL);
    remove_task(pEntity + TASKID_SUM_TELEPORT);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Float(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_FLOAT;

    new pEnemy = NPC_GetEnemy(pEntity);
    if (pEnemy) {
        static Float:vecTarget[3];
        pev(pEnemy, pev_origin, vecTarget);
        AlignHeight(pEntity, vecTarget);
    } else {
        new Float:flHeight = random_float(MONOCULUS_MIN_HEIGHT, MONOCULUS_MAX_HEIGHT);
        SetHeight(pEntity, flHeight);
    }
}

public Task_Shot(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_SHOT;

    PushBack(pEntity);
    SpawnRocket(pEntity);
    NPC_EmitVoice(pEntity, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.3);
}

public Task_CalmDown(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_CALM_DOWN;

    new Array:irgData = Monoculus_Get(pEntity);
    ArraySetCell(irgData, Monoculus_IsAngry, false);
}

public Task_RemoveStun(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_REMOVE_STUN;

    new Array:irgData = Monoculus_Get(pEntity);
    ArraySetCell(irgData, Monoculus_IsStunned, false);
    CreateJumpToPortalTask(pEntity);
}

public Task_PushBackEnd(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_PUSH_BACK_END;
    set_pev(pEntity, pev_velocity, ZERO_VECTOR_F);
}

public Task_JumpToPortal(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_JUMP_TO_PORTAL;
    JumpToPortal(pEntity);
    CreateJumpToPortalTask(pEntity);
}

public Task_Teleport(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_TELEPORT;

    client_cmd(0, "spk %s", g_szSndMoved);
    NPC_EmitVoice(pEntity, g_szSndSpawn, 1.0);

    new Array:irgData = Monoculus_Get(pEntity);
    new iPortal = ArrayGetCell(irgData, Monoculus_NextPortal);

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    TeleportEffect(vecOrigin);

    new Float:vecTargetOrigin[3];
    ArrayGetArray(g_irgPortals, iPortal, vecTargetOrigin);
    engfunc(EngFunc_SetOrigin, pEntity, vecTargetOrigin);
    TeleportEffect(vecTargetOrigin);

    new Float:vecTargetAngles[3];
    ArrayGetArray(g_irgPortalAngles, iPortal, vecTargetAngles);
    set_pev(pEntity, pev_angles, vecTargetAngles);

    NPC_PlayAction(pEntity, g_actions[Action_TeleportOut]);
}
