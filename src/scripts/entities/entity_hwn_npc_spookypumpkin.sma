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

enum _:Sequence
{
    Sequence_Idle = 0,
    Sequence_JumpStart,
    Sequence_JumpFloat,
    Sequence_Why,
    Sequence_Attack,
};

enum Action
{
    Action_Idle = 0,
    Action_JumpStart,
    Action_JumpFloat,
    Action_Why,
    Action_Attack,
};

const Float:NPC_Health = 70.0;
const Float:NPC_Speed = 128.0; // for jump velocity
const Float:NPC_Damage = 10.0;
const Float:NPC_HitRange = 48.0;
const Float:NPC_HitDelay = 0.5;

const Float:ENTITY_LifeTime = 30.0;
const Float:ENTITY_RespawnTime = 30.0;

const Float:SP_BigScaleMul = 1.5;
const Float:SP_JumpVelocityY = 128.0;
const Float:SP_AttackJumpVelocityY = 256.0;

new const g_szSndIdleList[][] =
{
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

new g_mdlGibs;

new g_sprBlood;
new g_sprBloodSpray;

new Float:g_fThinkDelay;

new g_ceHandlerSp;
new g_ceHandlerSpBig;

new g_maxPlayers;

new g_cvarPumpkinMutateChance;

public plugin_precache()
{
    g_mdlGibs = precache_model("models/hwn/props/pumpkin_explode_jib.mdl");
    g_sprBlood = precache_model("sprites/blood.spr");
    g_sprBloodSpray = precache_model("sprites/bloodspray.spr");

    for (new i = 0; i < sizeof(g_szSndIdleList); ++i) {
        precache_sound(g_szSndIdleList[i]);
    }

    g_ceHandlerSp = CE_Register(
        .szName = ENTITY_NAME_SP,
        .modelIndex = precache_model("models/hwn/npc/spookypumpkin.mdl"),
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 32.0},
        .fLifeTime = ENTITY_LifeTime,
        .fRespawnTime = ENTITY_RespawnTime,
        .preset = CEPreset_NPC
    );

    g_ceHandlerSpBig = CE_Register(
        .szName = ENTITY_NAME_SP_BIG,
        .modelIndex = precache_model("models/hwn/npc/spookypumpkin_big.mdl"),
        .vMins = Float:{-24.0, -24.0, 0.0},
        .vMaxs = Float:{24.0, 24.0, 48.0},
        .fLifeTime = ENTITY_LifeTime,
        .fRespawnTime = ENTITY_RespawnTime,
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

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);    
    
    g_cvarPumpkinMutateChance = register_cvar("hwn_pumpkin_mutate_chance", "20");

    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
    g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
    NPC_Create(ent);
    
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    
    new Float:fHealth = NPC_Health;
    if (isBig(ent)) {
        fHealth *= SP_BigScaleMul;
        UTIL_Message_Dlight(vOrigin, 16, {HWN_COLOR_YELLOW}, 20, 8);
    } else {
        UTIL_Message_Dlight(vOrigin, 8, {HWN_COLOR_YELLOW}, 20, 8);
    }

    set_pev(ent, pev_health, fHealth);

    EmitRandomLaugh(ent);

    engfunc(EngFunc_DropToFloor, ent);
        
    RemoveTasks(ent);
    set_task(0.0, "TaskThink", ent);
}

public OnKilled(ent)
{
    DisappearEffect(ent);
}

public OnRemove(ent)
{
    RemoveTasks(ent);
    NPC_Destroy(ent);
    DisappearEffect(ent);
}

public OnItemPumpkinKilled(ent, killer, bool:picked)
{
    if (picked) {
        return;
    }

    MutatePumpkin(ent, false);
}

public OnItemPumpkinBigKilled(ent, killer, bool:picked) {
    MutatePumpkin(ent, true);
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    new ceHandler = CE_GetHandlerByEntity(ent);

    if (ceHandler != g_ceHandlerSp && ceHandler != g_ceHandlerSpBig) {
        return;
    }
    
    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);

    UTIL_Message_BloodSprite(vEnd, g_sprBloodSpray, g_sprBlood, 103, floatround(fDamage/4));
}


Attack(ent, target, &Action:action)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    if (NPC_CanHit(ent, target, NPC_HitRange) && !task_exists(ent+TASKID_SUM_HIT)) {
        if (Jump(ent, 0.0, SP_AttackJumpVelocityY)) {
            EmitRandomLaugh(ent);
            set_task(NPC_HitDelay, "TaskHit", ent+TASKID_SUM_HIT);
            action = Action_Attack;
        }
    } else {
        static Float:vTarget[3];
        if (NPC_GetTarget(ent, NPC_Speed, vTarget)) {
            NPC_MoveToTarget(ent, vTarget, 0.0);
            if (!task_exists(ent+TASKID_SUM_JUMP)) {
                new Float:fJumpDelay = g_actions[Action_JumpStart][NPC_Action_Time];
                set_task(fJumpDelay, "TaskJump", ent+TASKID_SUM_JUMP);
                action = Action_JumpStart;

                if (random(100) < 10) {
                    EmitRandomLaugh(ent);
                }
            }
        } else {
            set_pev(ent, pev_enemy, 0);
        }
    }
}

RemoveTasks(ent)
{
    remove_task(ent);
    remove_task(ent+TASKID_SUM_HIT);
    remove_task(ent+TASKID_SUM_JUMP);
}

DisappearEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vVelocity[3];
    UTIL_RandomVector(-16.0, 16.0, vVelocity);

    UTIL_Message_Dlight(vOrigin, isBig(ent) ? 16 : 8, {HWN_COLOR_YELLOW}, 10, 32);
    UTIL_Message_BreakModel(vOrigin, Float:{4.0, 4.0, 4.0}, vVelocity, 32, g_mdlGibs, 4, 25, 0);
}

bool:Jump(ent, Float:fVelocity, Float:fJumpHeight) {
    if (~pev(ent, pev_flags) & FL_ONGROUND) {
        return false;
    }

    static Float:vVelocity[3];
    UTIL_GetDirectionVector(ent, vVelocity, fVelocity);
    vVelocity[2] = fJumpHeight;

    set_pev(ent, pev_velocity, vVelocity);
    
    return true;
}

EmitRandomLaugh(ent) {
    NPC_EmitVoice(ent, g_szSndIdleList[random(sizeof(g_szSndIdleList))]);
}

MutatePumpkin(ent, bool:big = false) {
    new chance = get_pcvar_num(g_cvarPumpkinMutateChance);
    if (!chance) {
        return;
    }

    if (random(100) <= chance) {
        static Float:vOrigin[3];
        pev(ent, pev_origin, vOrigin);

        new monsterEnt = CE_Create(big ? ENTITY_NAME_SP_BIG : ENTITY_NAME_SP, vOrigin);
        if (!monsterEnt) {
            return;
        }

        static Float:vAngles[3];
        for (new i = 0; i < 3; ++i) {
            vAngles[i] = 0.0;
        }

        vAngles[1] = random_float(0.0, 360.0);
        set_pev(monsterEnt, pev_angles, vAngles);

        dllfunc(DLLFunc_Spawn, monsterEnt);
    }
}

bool:isBig(ent) {
    return CE_GetHandlerByEntity(ent) == g_ceHandlerSpBig;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskHit(taskID)
{
    new ent = taskID - TASKID_SUM_HIT;
    
    if (pev(ent, pev_deadflag) != DEAD_NO) {
        return;
    }
    
    new Float:fDamage = NPC_Damage;
    if (isBig(ent)) {
        fDamage *= SP_BigScaleMul;
    }

    NPC_Hit(ent, fDamage, NPC_HitRange, NPC_HitDelay);
}

public TaskJump(taskID) {
    new ent = taskID - TASKID_SUM_JUMP;

    new enemy = pev(ent, pev_enemy);
    if (NPC_IsValidEnemy(enemy)) {
        static Float:vTarget[3];
        pev(enemy, pev_origin, vTarget);
        NPC_MoveToTarget(ent, vTarget, 0.0);
    }
    
    Jump(ent, NPC_Speed, SP_JumpVelocityY);
}

public TaskThink(taskID)
{
    new ent = taskID;
    
    if (pev(ent, pev_deadflag) != DEAD_NO) {
        return;
    }

    if (!pev_valid(ent)) {
        return;
    }

    new Action:action = Action_Idle;
    if (pev(ent, pev_flags) & FL_ONGROUND) {
        new enemy = pev(ent, pev_enemy);
        if (NPC_IsValidEnemy(enemy)) {
            Attack(ent, enemy, action);
        } else {
            NPC_FindEnemy(ent, g_maxPlayers);
        }
    } else {
        action = Action_JumpFloat;
    }
    
    new bool:supercede = action == Action_JumpStart || action == Action_Attack;
    NPC_PlayAction(ent, g_actions[action], supercede);

    set_task(g_fThinkDelay, "TaskThink", ent);
}
