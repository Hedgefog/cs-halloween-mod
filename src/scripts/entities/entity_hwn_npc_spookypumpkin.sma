#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN "[Custom Entity] Hwn NPC Spooky Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_HIT 1000
#define TASKID_SUM_JUMP 2000

#define ENTITY_NAME_SP "hwn_npc_spookypumpkin"
#define ENTITY_NAME_SP_BIG "hwn_npc_spookypumpkin_big"

enum _:Sequence {
    Sequence_Idle = 0,
    Sequence_JumpStart,
    Sequence_JumpFloat,
    Sequence_Why,
    Sequence_Attack,
};

enum Action {
    Action_Idle = 0,
    Action_JumpStart,
    Action_JumpFloat,
    Action_Why,
    Action_Attack,
};

const Float:NPC_Health = 100.0;
const Float:NPC_Speed = 200.0; // for jump velocity
const Float:NPC_Damage = 20.0;
const Float:NPC_HitRange = 48.0;
const Float:NPC_HitDelay = 0.5;
const Float:NPC_ViewRange = 1024.0;
const Float:NPC_LifeTime = 30.0;
const Float:NPC_RespawnTime = 15.0;

const Float:SP_BigScaleMul = 2.0;
const Float:SP_JumpVelocityZ = 160.0;
const Float:SP_AttackJumpVelocityZ = 256.0;

new const g_szSndIdleList[][] = {
    "hwn/npc/spookypumpkin/sp_laugh01.wav",
    "hwn/npc/spookypumpkin/sp_laugh02.wav",
    "hwn/npc/spookypumpkin/sp_laugh03.wav"
};

new const g_actions[Action][NPC_Action] = {
    { Sequence_Idle, Sequence_Idle, 0.0 },
    { Sequence_JumpStart, Sequence_JumpStart, 0.6 },
    { Sequence_JumpFloat, Sequence_JumpFloat, 0.0 },
    { Sequence_Why, Sequence_Why, 0.0 },
    { Sequence_Attack, Sequence_Attack, 1.2 }
};

new g_iGibsModelIndex;

new g_iBloodModelIndex;
new g_iBloodSprayModelIndex;

new Float:g_flThinkDelay;

new g_ceHandlerSp;
new g_ceHandlerSpBig;

new g_pCvarPumpkinMutateChance;

public plugin_precache() {
    g_iGibsModelIndex = precache_model("models/hwn/props/pumpkin_explode_jib_v2.mdl");
    g_iBloodModelIndex = precache_model("sprites/blood.spr");
    g_iBloodSprayModelIndex = precache_model("sprites/bloodspray.spr");

    for (new i = 0; i < sizeof(g_szSndIdleList); ++i) {
        precache_sound(g_szSndIdleList[i]);
    }

    g_ceHandlerSp = CE_Register(
        ENTITY_NAME_SP,
        .modelIndex = precache_model("models/hwn/npc/spookypumpkin.mdl"),
        .vMins = Float:{-12.0, -12.0, 0.0},
        .vMaxs = Float:{12.0, 12.0, 24.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC
    );

    g_ceHandlerSpBig = CE_Register(
        ENTITY_NAME_SP_BIG,
        .modelIndex = precache_model("models/hwn/npc/spookypumpkin_big.mdl"),
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 32.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_SP, "OnSpawn");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME_SP, "OnKilled");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_SP, "OnRemove");

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_SP_BIG, "OnSpawn");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME_SP_BIG, "OnKilled");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_SP_BIG, "OnRemove");

    CE_RegisterHook(CEFunction_Killed, "hwn_item_pumpkin", "OnItemPumpkinKilled");
    CE_RegisterHook(CEFunction_Killed, "hwn_item_pumpkin_big", "OnItemPumpkinBigKilled");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);

    g_pCvarPumpkinMutateChance = register_cvar("hwn_pumpkin_mutate_chance", "20");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded() {
    g_flThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(pEntity) {
    NPC_Create(pEntity);

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:flHealth = NPC_Health;
    if (bIsBig(pEntity)) {
        flHealth *= SP_BigScaleMul;
        UTIL_Message_Dlight(vecOrigin, 16, {HWN_COLOR_YELLOW}, 20, 8);
    } else {
        UTIL_Message_Dlight(vecOrigin, 8, {HWN_COLOR_YELLOW}, 20, 8);
    }

    set_pev(pEntity, pev_rendermode, kRenderNormal);
    set_pev(pEntity, pev_renderfx, kRenderFxGlowShell);
    set_pev(pEntity, pev_renderamt, 4.0);
    set_pev(pEntity, pev_rendercolor, {HWN_COLOR_ORANGE_DIRTY_F});
    set_pev(pEntity, pev_health, flHealth);

    engfunc(EngFunc_DropToFloor, pEntity);

    EmitRandomLaugh(pEntity);

    RemoveTasks(pEntity);
    set_task(0.0, "Task_Think", pEntity);
}

public OnKilled(pEntity) {
    DisappearEffect(pEntity);
}

public OnRemove(pEntity) {
    RemoveTasks(pEntity);
    NPC_Destroy(pEntity);
    DisappearEffect(pEntity);
}

public OnItemPumpkinKilled(pEntity, pKiller, bool:bPicked) {
    if (bPicked) {
        return;
    }

    MutatePumpkin(pEntity, false);
}

public OnItemPumpkinBigKilled(pEntity, pKiller, bool:bPicked) {
    if (bPicked) {
        return;
    }

    MutatePumpkin(pEntity, true);
}

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    new iCeHandler = CE_GetHandlerByEntity(pEntity);

    if (iCeHandler != g_ceHandlerSp && iCeHandler != g_ceHandlerSpBig) {
        return;
    }

    static Float:vecEnd[3];
    get_tr2(pTrace, TR_vecEndPos, vecEnd);

    UTIL_Message_BloodSprite(vecEnd, g_iBloodSprayModelIndex, g_iBloodModelIndex, 103, floatround(flDamage/4));
}

Attack(pEntity, pTarget, &Action:action) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    if (NPC_CanHit(pEntity, pTarget, NPC_HitRange) && !task_exists(pEntity+TASKID_SUM_HIT)) {
        if (Jump(pEntity, 0.0, SP_AttackJumpVelocityZ)) {
            EmitRandomLaugh(pEntity);
            set_task(NPC_HitDelay, "Task_Hit", pEntity+TASKID_SUM_HIT);
            action = Action_Attack;
        }
    } else {
        static Float:vecTarget[3];
        if (NPC_GetTarget(pEntity, NPC_Speed, vecTarget)) {
            NPC_MoveToTarget(pEntity, vecTarget, 0.0);
            if (!task_exists(pEntity+TASKID_SUM_JUMP)) {
                new Float:flJumpDelay = g_actions[Action_JumpStart][NPC_Action_Time];
                set_task(flJumpDelay, "Task_Jump", pEntity+TASKID_SUM_JUMP);
                action = Action_JumpStart;

                if (random(100) < 10) {
                    EmitRandomLaugh(pEntity);
                }
            }
        } else {
            NPC_SetEnemy(pEntity, 0);
        }
    }
}

RemoveTasks(pEntity) {
    remove_task(pEntity);
    remove_task(pEntity+TASKID_SUM_HIT);
    remove_task(pEntity+TASKID_SUM_JUMP);
}

DisappearEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:vecVelocity[3];
    UTIL_RandomVector(-16.0, 16.0, vecVelocity);

    UTIL_Message_Dlight(vecOrigin, bIsBig(pEntity) ? 16 : 8, {HWN_COLOR_YELLOW}, 10, 32);
    UTIL_Message_BreakModel(vecOrigin, Float:{4.0, 4.0, 4.0}, vecVelocity, 32, g_iGibsModelIndex, 4, 25, 0);
}

bool:Jump(pEntity, Float:flVelocity, Float:flJumpHeight) {
    if (~pev(pEntity, pev_flags) & FL_ONGROUND) {
        return false;
    }

    static Float:vecVelocity[3];
    UTIL_GetDirectionVector(pEntity, vecVelocity, flVelocity);
    vecVelocity[2] = flJumpHeight;

    set_pev(pEntity, pev_velocity, vecVelocity);

    return true;
}

EmitRandomLaugh(pEntity) {
    NPC_EmitVoice(pEntity, g_szSndIdleList[random(sizeof(g_szSndIdleList))]);
}

MutatePumpkin(pEntity, bool:bBig = false) {
    new chance = get_pcvar_num(g_pCvarPumpkinMutateChance);
    if (!chance) {
        return;
    }

    if (random(100) > chance) {
        return;
    }

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pMonster = CE_Create(bBig ? ENTITY_NAME_SP_BIG : ENTITY_NAME_SP, vecOrigin);
    if (!pMonster) {
        return;
    }

    new Float:vecAngles[3];
    for (new i = 0; i < 3; ++i) {
        vecAngles[i] = 0.0;
    }

    vecAngles[1] = random_float(0.0, 360.0);
    set_pev(pMonster, pev_angles, vecAngles);

    dllfunc(DLLFunc_Spawn, pMonster);
}

bool:bIsBig(pEntity) {
    return CE_GetHandlerByEntity(pEntity) == g_ceHandlerSpBig;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Hit(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_HIT;

    if (pev(pEntity, pev_deadflag) != DEAD_NO) {
        return;
    }

    new Float:flDamage = NPC_Damage;
    if (bIsBig(pEntity)) {
        flDamage *= SP_BigScaleMul;
    }

    NPC_Hit(pEntity, flDamage, NPC_HitRange, NPC_HitDelay);
}

public Task_Jump(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_JUMP;

    new pEnemy = NPC_GetEnemy(pEntity);
    if (pEnemy) {
        static Float:vecTarget[3];
        pev(pEnemy, pev_origin, vecTarget);
        NPC_MoveToTarget(pEntity, vecTarget, 0.0);
    }

    Jump(pEntity, NPC_Speed, SP_JumpVelocityZ);
}

public Task_Think(iTaskId) {
    new pEntity = iTaskId;

    if (pev(pEntity, pev_deadflag) != DEAD_NO) {
        return;
    }

    if (!pev_valid(pEntity)) {
        return;
    }

    new Action:action = Action_Idle;
    if (pev(pEntity, pev_flags) & FL_ONGROUND) {
        new pEnemy = NPC_GetEnemy(pEntity);
        if (pEnemy) {
            Attack(pEntity, pEnemy, action);
        } else {
            NPC_FindEnemy(pEntity, NPC_ViewRange);
        }
    } else {
        action = Action_JumpFloat;
    }

    new bool:bSupercede = action == Action_JumpStart || action == Action_Attack;
    NPC_PlayAction(pEntity, g_actions[action], bSupercede);

    set_task(g_flThinkDelay, "Task_Think", pEntity);
}
