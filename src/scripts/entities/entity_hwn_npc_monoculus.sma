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

enum _:Sequence
{
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

enum Action
{
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

enum _:Monoculus
{
    Float:Monoculus_DamageToStun,
    bool:Monoculus_IsAngry,
    bool:Monoculus_IsStunned,
    bool:Monoculus_NextPortal,
    bool:Monoculus_LastAction
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

new const g_actions[Action][NPC_Action] =
{
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

new g_sprBlood;
new g_sprBloodSpray;
new g_sprSparkle;

new Float:g_fThinkDelay;

new g_cvarAngryTime;
new g_cvarDamageToStun;
new g_cvarJumpTimeMin;
new g_cvarJumpTimeMax;

new g_ceHandler;
new g_bossHandler;

new g_maxPlayers;

new Array:g_portals;
new Array:g_portalAngles;
new g_level = 0;

public plugin_precache()
{
    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/monoculus.mdl"),
        .vMins = Float:{-48.0, -48.0, -48.0},
        .vMaxs = Float:{48.0, 48.0, 48.0},
        .preset = CEPreset_NPC
    );

    g_bossHandler = Hwn_Bosses_Register(ENTITY_NAME, "Monoculus");

    g_sprBlood = precache_model("sprites/blood.spr");
    g_sprBloodSpray = precache_model("sprites/bloodspray.spr");
    g_sprSparkle = precache_model("sprites/muz7.spr");

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

    CE_RegisterHook(CEFunction_Spawn, PORTAL_ENTITY_NAME, "OnPortalSpawn");

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");

    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTakeDamage", .Post = 1);

    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_cvarAngryTime = register_cvar("hwn_npc_monoculus_angry_time", "15.0");
    g_cvarDamageToStun = register_cvar("hwn_npc_monoculus_dmg_to_stun", "2000.0");
    g_cvarJumpTimeMin = register_cvar("hwn_npc_monoculus_jump_time_min", "10.0");
    g_cvarJumpTimeMax = register_cvar("hwn_npc_monoculus_jump_time_max", "20.0");

    g_maxPlayers = get_maxplayers();
}

public plugin_end()
{
    if (g_portals != Invalid_Array) {
        ArrayDestroy(g_portals);
        ArrayDestroy(g_portalAngles);
    }
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded()
{
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
}

public Hwn_Bosses_Fw_BossTeleport(ent, handler)
{
    if (handler != g_bossHandler) {
        return;
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPortalSpawn(ent)
{
    if (g_portals == Invalid_Array) {
        g_portals = ArrayCreate(3);
        g_portalAngles = ArrayCreate(3);
    }

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    ArrayPushArray(g_portals, vOrigin);

    new Float:vAngles[3];
    pev(ent, pev_angles, vAngles);
    ArrayPushArray(g_portalAngles, vAngles);

    CE_Remove(ent);
}

public OnSpawn(ent)
{
    new Float:fHealth = NPC_Health + (g_level * NPC_HealthPerLevel);

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_Dlight(vOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    set_pev(ent, pev_health, fHealth);
    set_pev(ent, pev_movetype, MOVETYPE_FLY);

    new Float:fRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        fRenderColor[i] *= 0.2;
    }

    set_pev(ent, pev_rendermode, kRenderNormal);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 4.0);
    set_pev(ent, pev_rendercolor, fRenderColor);

    NPC_Create(ent, 0.0);
    new Array:monoculus = Monoculus_Create(ent);

    engfunc(EngFunc_DropToFloor, ent);

    set_pev(ent, pev_takedamage, DAMAGE_NO);
    NPC_EmitVoice(ent, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 1.0);
    NPC_PlayAction(ent, g_actions[Action_Spawn]);

    ArraySetCell(monoculus, Monoculus_IsStunned, false);
    ArraySetCell(monoculus, Monoculus_DamageToStun, get_pcvar_float(g_cvarDamageToStun));
    ArraySetCell(monoculus, Monoculus_IsAngry, false);
    ArraySetCell(monoculus, Monoculus_LastAction, get_gametime());

    ClearTasks(ent);

    CreateJumpToPortalTask(ent);
    set_task(g_actions[Action_Spawn][NPC_Action_Time], "TaskThink", ent);
    set_task(1.0, "TaskFloat", ent + TASKID_SUM_FLOAT, _, _, "b");
}

public OnRemove(ent)
{
    ClearTasks(ent);

    {
        new Float:vOrigin[3];
        pev(ent, pev_origin, vOrigin);

        TeleportEffect(vOrigin);
    }

    NPC_Destroy(ent);
    Monoculus_Destroy(ent);
}

public OnKill(ent)
{
    new deadflag = pev(ent, pev_deadflag);

    if (deadflag == DEAD_NO) {
        NPC_PlayAction(ent, g_actions[Action_Death], .supercede = true);

        set_pev(ent, pev_takedamage, DAMAGE_NO);
        set_pev(ent, pev_velocity, ZERO_VECTOR_F);
        set_pev(ent, pev_deadflag, DEAD_DYING);

        ClearTasks(ent);
        set_task(g_actions[Action_Death][NPC_Action_Time], "TaskThink", ent);
    } else if (deadflag == DEAD_DEAD) {
        g_level++;
        return PLUGIN_CONTINUE;
    }

    return PLUGIN_HANDLED;
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);

    UTIL_Message_BloodSprite(vEnd, g_sprBloodSpray, g_sprBlood, 212, floatround(fDamage/4));

    return HAM_HANDLED;
}

public OnTakeDamage(ent, inflictor, attacker, Float:fDamage)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    new Array:monoculus = Monoculus_Get(ent);

    new Float:fDamageToStun = ArrayGetCell(monoculus, Monoculus_DamageToStun);
    fDamageToStun -= fDamage;

    if (random(100) < 10) {
        NPC_EmitVoice(ent, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }

    if (fDamageToStun <= 0) {
        fDamageToStun = get_pcvar_float(g_cvarDamageToStun);
        Stun(ent);
    }

    ArraySetCell(monoculus, Monoculus_DamageToStun, fDamageToStun);

    if (random_num(0, 100) < 5) {
        MakeAngry(ent);
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

public OnPlayerKilled(id, killer)
{
    if (!killer || g_ceHandler != CE_GetHandlerByEntity(killer)) {
        return;
    }

    if (random_num(0, 100) < 30) {
        Laugh(killer);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

Array:Monoculus_Create(ent)
{
    new Array:monoculus = ArrayCreate(1, Monoculus);
    for (new i = 0; i < Monoculus; ++i) {
        ArrayPushCell(monoculus, 0);
    }

    set_pev(ent, pev_iuser2, monoculus);

    return monoculus;
}

Monoculus_Destroy(ent)
{
    new Array:monoculus = any:pev(ent, pev_iuser2);

    ArrayDestroy(monoculus);
}

Array:Monoculus_Get(ent)
{
    return Array:pev(ent, pev_iuser2);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskThink(ent)
{
    if (!pev_valid(ent)) {
        return;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    if (pev(ent, pev_deadflag) == DEAD_DYING) {
        NPC_EmitVoice(ent, g_szSndDeath, .supercede = true);
        set_pev(ent, pev_deadflag, DEAD_DEAD);
        CE_Kill(ent);

        return;
    }

    new Array:monoculus = Monoculus_Get(ent);

    if (pev(ent, pev_takedamage) == DAMAGE_NO) {
        set_pev(ent, pev_takedamage, DAMAGE_AIM);
        ArraySetCell(monoculus, Monoculus_LastAction, get_gametime());
    }

    new bool:isStunned = ArrayGetCell(monoculus, Monoculus_IsStunned);

    if (!isStunned) {
        new enemy = pev(ent, pev_enemy);
        if (!NPC_IsValidEnemy(enemy) || !Attack(ent, enemy)) {
            if (random_num(0, 100) < 5) {
                LookAround(ent);
            }

            NPC_FindEnemy(ent, g_maxPlayers);
            NPC_PlayAction(ent, g_actions[Action_Idle]);
        }

        new Float:fLastAction = ArrayGetCell(monoculus, Monoculus_LastAction);
        if (get_gametime() - fLastAction > 5.0) {
            JumpToPortal(ent);
        }
    }

    set_task(g_fThinkDelay, "TaskThink", ent);
}

bool:Attack(ent, target)
{
    new Array:monoculus = Monoculus_Get(ent);

    static Float:vTarget[3];
    pev(target, pev_origin, vTarget);

    if (!NPC_IsVisible(ent, vTarget)) {
        return false;
    }

    if (NPC_CanHit(ent, target, NPC_HitRange)) {
        new bool:isAngry = ArrayGetCell(monoculus, Monoculus_IsAngry);

        if (isAngry) {
            AngryShot(ent);
        } else {
            Shot(ent);
        }
    } else {
        if (task_exists(ent + TASKID_SUM_PUSH_BACK_END)) {
            NPC_MoveToTarget(ent, vTarget, 0.0);
        } else {
            NPC_MoveToTarget(ent, vTarget, NPC_Speed, 90.0);
        }

        NPC_PlayAction(ent, g_actions[Action_Idle]);
    }

    ArraySetCell(monoculus, Monoculus_LastAction, get_gametime());

    return true;
}

BaseShot(ent, Float:attackDelay)
{
    set_pev(ent, pev_velocity, ZERO_VECTOR_F);

    new Array:npcData = NPC_GetData(ent);
    ArraySetCell(npcData, NPC_NextAttack, get_gametime() + attackDelay);
}

Shot(ent)
{
    set_task(NPC_AttackDelay, "TaskShot", ent+TASKID_SUM_SHOT, _, _, "a", 1);

    NPC_PlayAction(ent, g_actions[Action_Attack]);
    BaseShot(ent, g_actions[Action_Attack][NPC_Action_Time] + 0.1);
}

AngryShot(ent)
{
    set_task(NPC_AttackDelay, "TaskShot", ent+TASKID_SUM_SHOT, _, _, "a", 3);

    NPC_PlayAction(ent, g_actions[Action_AngryAttack]);
    BaseShot(ent, g_actions[Action_AngryAttack][NPC_Action_Time] + 0.1);
}

Laugh(ent)
{
    NPC_PlayAction(ent, g_actions[Action_Laugh]);
    NPC_EmitVoice(ent, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}

LookAround(ent)
{
    NPC_PlayAction(ent, g_actions[Action_LookAround]);
}

Stun(ent)
{
    set_pev(ent, pev_velocity, ZERO_VECTOR_F);

    new Array:monoculus = Monoculus_Get(ent);
    ArraySetCell(monoculus, Monoculus_IsStunned, true);

    NPC_EmitVoice(ent, g_szSndStunned[random(sizeof(g_szSndStunned))], 1.0);
    NPC_PlayAction(ent, g_actions[Action_Stunned], .supercede = true);

    remove_task(ent+TASKID_SUM_SHOT);
    remove_task(ent+TASKID_SUM_JUMP_TO_PORTAL);
    set_task(g_actions[Action_Stunned][NPC_Action_Time], "TaskRemoveStun", ent+TASKID_SUM_REMOVE_STUN);
    ArraySetCell(monoculus, Monoculus_LastAction, get_gametime());
}

MakeAngry(ent)
{
    new Array:monoculus = Monoculus_Get(ent);

    new bool:isAngry = ArrayGetCell(monoculus, Monoculus_IsAngry);

    if (!isAngry) {
        ArraySetCell(monoculus, Monoculus_IsAngry, true);
        set_task(get_pcvar_float(g_cvarAngryTime), "TaskCalmDown", ent+TASKID_SUM_CALM_DOWN);
    }

    ArraySetCell(monoculus, Monoculus_LastAction, get_gametime());
}

SetHeight(ent, Float:fHeight, Float:fSpeed = NPC_Speed)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new Float:fDistanceToFloor = UTIL_GetDistanceToFloor(ent, vOrigin);
    if (fDistanceToFloor == -1.0) {
        set_pev(ent, pev_velocity, ZERO_VECTOR_F);
        return;
    }

    static Float:vVelocity[3];
    pev(ent, pev_velocity, vVelocity);

    new direction = (fDistanceToFloor > fHeight) ? -1 : 1;
    vVelocity[2] = fSpeed * direction;

    set_pev(ent, pev_velocity, vVelocity);
}

AlignHeight(ent, const Float:vTarget[3])
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
 
    new Float:fHeightDiff = vOrigin[2] - vTarget[2];
    vOrigin[2] -= fHeightDiff;

    new Float:fDistanceToFloor = UTIL_GetDistanceToFloor(ent, vOrigin);
    if (fDistanceToFloor == -1.0) {
        return;
    }

    SetHeight(ent, fDistanceToFloor < MONOCULUS_MIN_HEIGHT ? MONOCULUS_MIN_HEIGHT : fDistanceToFloor);
}

SpawnRocket(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vDirection[3];
    UTIL_GetDirectionVector(ent, vDirection);

    {
        static Float:vTmp[3];
        xs_vec_mul_scalar(vDirection, MONOCULUS_SPAWN_ROCKET_DISTANCE, vTmp);
        xs_vec_add(vOrigin, vTmp, vOrigin);
    }

    // todo: add spawn rocket logic
    new rocketEnt = CE_Create("hwn_monoculus_rocket", vOrigin);

    if (!rocketEnt) {
        return;
    }

    static Float:vAngles[3];
    pev(ent, pev_angles, vAngles);

    set_pev(rocketEnt, pev_angles, vAngles);
    set_pev(rocketEnt, pev_owner, ent);

    static Float:vVelocity[3];
    xs_vec_mul_scalar(vDirection, MONOCULUS_ROCKET_SPEED, vVelocity);
    set_pev(rocketEnt, pev_velocity, vVelocity);

    dllfunc(DLLFunc_Spawn, rocketEnt);
}

PushBack(ent)
{
    static Float:vVelocity[3];
    UTIL_GetDirectionVector(ent, vVelocity, -MONOCULUS_PUSHBACK_SPEED);
    set_pev(ent, pev_velocity, vVelocity);

    set_task(0.25, "TaskPushBackEnd", ent+TASKID_SUM_PUSH_BACK_END);
}

JumpToPortal(ent)
{
    if (g_portals == Invalid_Array) {
        return;
    }

    new size = ArraySize(g_portals);

    if (!size) {
        return;
    }

    new Array:monoculus = Monoculus_Get(ent);

    new bool:isStunned = ArrayGetCell(monoculus, Monoculus_IsStunned);
    if (isStunned) {
        return;
    }

    new portalIdx = random(size);
    if (portalIdx == ArrayGetCell(monoculus, Monoculus_NextPortal)) {
        return;
    }

    ArraySetCell(monoculus, Monoculus_NextPortal, portalIdx);

    NPC_PlayAction(ent, g_actions[Action_TeleportIn]);
    remove_task(ent+TASKID_SUM_TELEPORT);
    set_task(g_actions[Action_TeleportIn][NPC_Action_Time], "TaskTeleport", ent+TASKID_SUM_TELEPORT);
    ArraySetCell(monoculus, Monoculus_LastAction, get_gametime());
}

CreateJumpToPortalTask(ent)
{
    new Float:fMinTime = get_pcvar_float(g_cvarJumpTimeMin);
    new Float:fMaxTime = get_pcvar_float(g_cvarJumpTimeMax);
    set_task(random_float(fMinTime, fMaxTime), "TaskJumpToPortal", ent+TASKID_SUM_JUMP_TO_PORTAL);
}

TeleportEffect(const Float:vOrigin[3])
{
    new Float:vEnd[3];
    xs_vec_copy(vOrigin, vEnd);
    vEnd[2] += 8.0;

    UTIL_Message_SpriteTrail(vOrigin, vEnd, g_sprSparkle, 8, 1, 4, 32, 16);
    UTIL_Message_Dlight(vOrigin, 48, {HWN_COLOR_PRIMARY}, 5, 32);
}

ClearTasks(ent) {
    remove_task(ent);
    remove_task(ent+TASKID_SUM_FLOAT);
    remove_task(ent+TASKID_SUM_SHOT);
    remove_task(ent+TASKID_SUM_CALM_DOWN);
    remove_task(ent+TASKID_SUM_REMOVE_STUN);
    remove_task(ent+TASKID_SUM_PUSH_BACK_END);
    remove_task(ent+TASKID_SUM_JUMP_TO_PORTAL);
    remove_task(ent+TASKID_SUM_TELEPORT);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskFloat(taskID)
{
    new ent = taskID - TASKID_SUM_FLOAT;

    new enemy = pev(ent, pev_enemy);
    if (NPC_IsValidEnemy(enemy)) {
        static Float:vTarget[3];
        pev(enemy, pev_origin, vTarget);
        AlignHeight(ent, vTarget);
    } else {
        new Float:fHeight = random_float(MONOCULUS_MIN_HEIGHT, MONOCULUS_MAX_HEIGHT);
        SetHeight(ent, fHeight);
    }
}

public TaskShot(taskID)
{
    new ent = taskID - TASKID_SUM_SHOT;

    PushBack(ent);
    SpawnRocket(ent);
    NPC_EmitVoice(ent, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.3);
}

public TaskCalmDown(taskID)
{
    new ent = taskID - TASKID_SUM_CALM_DOWN;

    new Array:monoculus = Monoculus_Get(ent);
    ArraySetCell(monoculus, Monoculus_IsAngry, false);
}

public TaskRemoveStun(taskID)
{
    new ent = taskID - TASKID_SUM_REMOVE_STUN;

    new Array:monoculus = Monoculus_Get(ent);
    ArraySetCell(monoculus, Monoculus_IsStunned, false);
    CreateJumpToPortalTask(ent);
}

public TaskPushBackEnd(taskID)
{
    new ent = taskID - TASKID_SUM_PUSH_BACK_END;
    set_pev(ent, pev_velocity, ZERO_VECTOR_F);
}

public TaskJumpToPortal(taskID)
{
    new ent = taskID - TASKID_SUM_JUMP_TO_PORTAL;
    JumpToPortal(ent);
    CreateJumpToPortalTask(ent);
}

public TaskTeleport(taskID)
{
    new ent = taskID - TASKID_SUM_TELEPORT;

    client_cmd(0, "spk %s", g_szSndMoved);
    NPC_EmitVoice(ent, g_szSndSpawn, 1.0);

    new Array:monoculus = Monoculus_Get(ent);
    new portalIdx = ArrayGetCell(monoculus, Monoculus_NextPortal);

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    TeleportEffect(vOrigin);

    new Float:vTargetOrigin[3];
    ArrayGetArray(g_portals, portalIdx, vTargetOrigin);
    engfunc(EngFunc_SetOrigin, ent, vTargetOrigin);
    TeleportEffect(vTargetOrigin);

    new Float:vTargetAngles[3];
    ArrayGetArray(g_portalAngles, portalIdx, vTargetAngles);
    set_pev(ent, pev_angles, vTargetAngles);

    NPC_PlayAction(ent, g_actions[Action_TeleportOut]);
}
