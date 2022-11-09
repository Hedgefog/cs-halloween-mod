#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN "[Custom Entity] Hwn NPC Skeleton"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_HIT 1000

#define ENTITY_NAME "hwn_npc_skeleton"
#define ENTITY_NAME_SMALL "hwn_npc_skeleton_small"

#define SKELETON_EGG_ENTITY_NAME "hwn_skeleton_egg"
#define SKELETON_EGG_COUNT 2

enum _:Sequence
{
    Sequence_Idle = 0,

    Sequence_Run,

    Sequence_Attack,
    Sequence_RunAttack,

    Sequence_Spawn1,
    Sequence_Spawn2,
    Sequence_Spawn3,
    Sequence_Spawn4,
    Sequence_Spawn5,
    Sequence_Spawn6,
    Sequence_Spawn7,
};

enum Action
{
    Action_Idle = 0,
    Action_Run,
    Action_Attack,
    Action_RunAttack,
    Action_Spawn
};

const Float:NPC_Health = 100.0;
const Float:NPC_Speed = 230.0;
const Float:NPC_Damage = 24.0;
const Float:NPC_HitRange = 48.0;
const Float:NPC_HitDelay = 0.35;

const Float:NPC_Small_Health = 50.0;
const Float:NPC_Small_Speed = 250.0;
const Float:NPC_Small_Damage = 12.0;
const Float:NPC_Small_HitRange = 48.0;
const Float:NPC_Small_HitDelay = 0.35;

new const g_szSndIdleList[][] =
{
    "hwn/npc/skeleton/skelly_medium_01.wav",
    "hwn/npc/skeleton/skelly_medium_02.wav",
    "hwn/npc/skeleton/skelly_medium_03.wav",
    "hwn/npc/skeleton/skelly_medium_04.wav",
    "hwn/npc/skeleton/skelly_medium_05.wav"
};

new const g_szSndSmallIdleList[][] =
{
    "hwn/npc/skeleton/skelly_small_01.wav",
    "hwn/npc/skeleton/skelly_small_02.wav",
    "hwn/npc/skeleton/skelly_small_03.wav",
    "hwn/npc/skeleton/skelly_small_04.wav",
    "hwn/npc/skeleton/skelly_small_05.wav"
};

new const g_szSndBreak[]    = "hwn/npc/skeleton/skeleton_break.wav";

new const g_actions[Action][NPC_Action] = {
    {    Sequence_Idle,         Sequence_Idle,          0.0    },
    {    Sequence_Run,          Sequence_Run,           0.0    },
    {    Sequence_Attack,       Sequence_Attack,        1.0    },
    {    Sequence_RunAttack,    Sequence_RunAttack,     1.0    },
    {    Sequence_Spawn1,       Sequence_Spawn7,        2.0    }
};

new g_mdlGibs;

new g_sprBlood;
new g_sprBloodSpray;

new Float:g_fThinkDelay;

new g_ceHandler;
new g_ceHandlerSmall;

public plugin_precache()
{
    g_mdlGibs = precache_model("models/bonegibs.mdl");
    g_sprBlood = precache_model("sprites/blood.spr");
    g_sprBloodSpray = precache_model("sprites/bloodspray.spr");

    precache_sound(g_szSndBreak);

    for (new i = 0; i < sizeof(g_szSndIdleList); ++i) {
        precache_sound(g_szSndIdleList[i]);
    }

    for (new i = 0; i < sizeof(g_szSndSmallIdleList); ++i) {
        precache_sound(g_szSndSmallIdleList[i]);
    }

    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/skeleton_v2.mdl"),
        .vMins = Float:{-12.0, -12.0, -32.0},
        .vMaxs = Float:{12.0, 12.0, 32.0},
        .fLifeTime = 30.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_NPC
    );

    g_ceHandlerSmall = CE_Register(
        .szName = ENTITY_NAME_SMALL,
        .modelIndex = precache_model("models/hwn/npc/skeleton_small_v3.mdl"),
        .vMins = Float:{-8.0, -8.0, -16.0},
        .vMaxs = Float:{8.0, 8.0, 16.0},
        .fLifeTime = 30.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_SMALL, "OnSpawn");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME_SMALL, "OnKilled");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_SMALL, "OnRemove");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttackPre", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);
    RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "OnThink", .Post = 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilledPre", .Post = 0);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded()
{
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
    new Float:fHealth = IsSmall(ent) ? NPC_Small_Health : NPC_Health;
    
    NPC_Create(ent);

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_Dlight(vOrigin, IsSmall(ent) ? 8 : 16, {HWN_COLOR_SECONDARY}, 20, 8);

    set_pev(ent, pev_rendermode, kRenderNormal);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 4.0);
    set_pev(ent, pev_health, fHealth);
    set_pev(ent, pev_groupinfo, 128);
    set_pev(ent, pev_fuser1, 0.0);

    engfunc(EngFunc_DropToFloor, ent);

    NPC_PlayAction(ent, g_actions[Action_Spawn]);
    
    RemoveTasks(ent);
    set_pev(ent, pev_nextthink, get_gametime() + 2.0);

    UpdateColor(ent);
}

public OnKilled(ent, killer)
{
    DisappearEffect(ent);

    if (!IsSmall(ent)) {
        new Float:vOrigin[3];
        pev(ent, pev_origin, vOrigin);

        for (new i = 0; i < SKELETON_EGG_COUNT; ++i) {
            new eggEnt = CE_Create(SKELETON_EGG_ENTITY_NAME, vOrigin);

            if (!eggEnt) {
                continue;
            }

            set_pev(eggEnt, pev_team, pev(ent, pev_team));
            set_pev(eggEnt, pev_owner, pev(ent, pev_owner));
            dllfunc(DLLFunc_Spawn, eggEnt);

            new Float:vVelocity[3];
            xs_vec_set(vVelocity, random_float(-96.0, 96.0), random_float(-96.0, 96.0), 128.0);
            set_pev(eggEnt, pev_velocity, vVelocity);
        }
    }
}

public OnRemove(ent)
{
    RemoveTasks(ent);
    NPC_Destroy(ent);
}

public OnTraceAttackPre(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent) && g_ceHandlerSmall != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    new team = pev(ent, pev_team);
    if (UTIL_IsPlayer(attacker) && UTIL_GetPlayerTeam(attacker) == team) {
        return HAM_SUPERCEDE;
    }

    return HAM_HANDLED;
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent) && g_ceHandlerSmall != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    new team = pev(ent, pev_team);
    if (UTIL_IsPlayer(attacker) && UTIL_GetPlayerTeam(attacker) == team) {
        return HAM_HANDLED;
    }

    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);
    UTIL_Message_BloodSprite(vEnd, g_sprBloodSpray, g_sprBlood, 242, floatround(fDamage/4));

    return HAM_HANDLED;
}

public OnThink(ent)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent) && g_ceHandlerSmall != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    if (pev(ent, pev_deadflag) != DEAD_NO) {
        return HAM_IGNORED;
    }

    new enemy = NPC_GetEnemy(ent);
    new Action:action = Action_Idle;

    static Float:fLastUpdate;
    pev(ent, pev_fuser1, fLastUpdate);
    new bool:shouldUpdate = get_gametime() - fLastUpdate >= g_fThinkDelay;

    if (enemy) {
        Attack(ent, enemy, action, shouldUpdate);
    }

    if (shouldUpdate) {
        if (!enemy) {
            NPC_FindEnemy(ent, 1024.0);
        } else {
            if (random(100) < 10) {
                if (IsSmall(ent)) {
                    NPC_EmitVoice(ent, g_szSndSmallIdleList[random(sizeof(g_szSndSmallIdleList))]);
                } else {
                    NPC_EmitVoice(ent, g_szSndIdleList[random(sizeof(g_szSndIdleList))]);
                }
            }
        }

        NPC_PlayAction(ent, g_actions[action]);
        UpdateColor(ent);

        set_pev(ent, pev_fuser1, get_gametime());
    }

    set_pev(ent, pev_nextthink, get_gametime() + 0.01);

    return HAM_HANDLED;
}

public OnPlayerKilledPre(id, killer)
{
    new ceHandler = CE_GetHandlerByEntity(killer);
    if (ceHandler == g_ceHandler || ceHandler == g_ceHandlerSmall) {
        new owner = pev(killer, pev_owner);
        if (owner) {
            SetHamParamEntity(2, owner);
        }
    }

    return HAM_HANDLED;
}

bool:Attack(ent, target, &Action:action, bool:checkTarget = true)
{
    new Float:fHitRange = IsSmall(ent) ? NPC_Small_HitRange : NPC_HitRange;
    new Float:fHitDelay = IsSmall(ent) ? NPC_Small_HitDelay : NPC_HitDelay;
    new Float:fSpeed = IsSmall(ent) ? NPC_Small_Speed : NPC_Speed;

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vTarget[3];
    if (checkTarget) {
        if (!NPC_GetTarget(ent, fSpeed, vTarget)) {
            NPC_SetEnemy(ent, 0);
            NPC_StopMovement(ent);
            set_pev(ent, pev_vuser1, vOrigin);
            return false;
        }

        set_pev(ent, pev_vuser1, vTarget);
    } else {
        pev(ent, pev_vuser1, vTarget);
    }

    new bool:canHit = NPC_CanHit(ent, target, fHitRange);

    if (checkTarget && canHit && !task_exists(ent+TASKID_SUM_HIT)) {
        set_task(fHitDelay, "TaskHit", ent+TASKID_SUM_HIT);
        action = Action_Attack;
    }

    static Float:vTargetVelocity[3];
    pev(target, pev_velocity, vTargetVelocity);

    new bool:shouldRun = !canHit || xs_vec_len(vTargetVelocity) > fHitRange;

    if (shouldRun) {
        NPC_MoveToTarget(ent, vTarget, NPC_Speed);
        action = (action == Action_Attack) ? Action_RunAttack : Action_Run;
    } else {
        NPC_StopMovement(ent);
    }

    return true;
}

RemoveTasks(ent)
{
    remove_task(ent+TASKID_SUM_HIT);
}

DisappearEffect(ent)
{
    new Float:vVelocity[3];
    UTIL_RandomVector(-48.0, 48.0, vVelocity);

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    UTIL_Message_Dlight(vOrigin, IsSmall(ent) ? 8 : 16, {HWN_COLOR_SECONDARY}, 10, 32);

    UTIL_Message_BreakModel(vOrigin, Float:{16.0, 16.0, 16.0}, vVelocity, 10, g_mdlGibs, 5, 25, 0);

    emit_sound(ent, CHAN_BODY, g_szSndBreak, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

UpdateColor(ent) {
    new team = pev(ent, pev_team);

    switch (team) {
        case 0:
            set_pev(ent, pev_rendercolor, {HWN_COLOR_SECONDARY_F});
        case 1:
            set_pev(ent, pev_rendercolor, {HWN_COLOR_RED_F});
        case 2:
            set_pev(ent, pev_rendercolor, {HWN_COLOR_BLUE_F});
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskHit(taskID)
{
    new ent = taskID - TASKID_SUM_HIT;

    if (pev(ent, pev_deadflag) != DEAD_NO) {
        return;
    }

    new Float:fHitRange = IsSmall(ent) ? NPC_Small_HitRange : NPC_HitRange;
    new Float:fHitDelay = IsSmall(ent) ? NPC_Small_HitDelay : NPC_HitDelay;
    new Float:fDamage = IsSmall(ent) ? NPC_Small_Damage : NPC_Damage;

    NPC_Hit(ent, fDamage, fHitRange, fHitDelay);
}

bool:IsSmall(ent) {
    return CE_GetHandlerByEntity(ent) == g_ceHandlerSmall;
}
