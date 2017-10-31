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

#define TASKID_SUM_SHOT             1000
#define TASKID_SUM_CALM_DOWN        2000
#define TASKID_SUM_REMOVE_STUN      3000
#define TASKID_SUM_PUSH_BACK_END    4000
#define TASKID_SUM_IDLE_SOUND       5000
#define TASKID_SUM_JUMP_TO_PORTAL   6000
#define TASKID_SUM_TELEPORT         7000

#define ZERO_VECTOR_F Float:{0.0, 0.0, 0.0}

#define MONOCULUS_ROCKET_SPEED 960.0
#define MONOCULUS_PUSHBACK_SPEED 64.0
#define MONOCULUS_MIN_HEIGHT 128.0
#define MONOCULUS_MAX_HEIGHT 320.0
#define MONOCULUS_SPAWN_ROCKET_DISTANCE 80.0

enum _:Sequence 
{
    Sequence_Ref = 0,
    Sequence_Angry,
    Sequence_Idle,
    Sequence_Stunned,
    Sequence_Attack1,
    Sequence_Attack2,
    Sequence_Attack3,
    Sequence_Spawn,
    Sequence_Laugh,
    Sequence_LongLaugh,
    Sequence_TeleportIn,
    Sequence_TeleportOut,
    Sequence_Huff1,
    Sequence_Huff2,
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
    Action_LongLaugh,
    Action_TeleportIn,
    Action_TeleportOut,
    Action_Death,
    Action_LookAround,
    Action_Escape
};

enum _:Monoculus
{
    Float:Monoculus_DamageToStun,
    bool:Monoculus_IsAngry,
    bool:Monoculus_IsStunned,
    bool:Monoculus_NextPortal
};

new const g_szSndAttack[][128] = {
    "hwn/npc/monoculus/monoculus_attack01.wav",
    "hwn/npc/monoculus/monoculus_attack02.wav",
    "hwn/npc/monoculus/monoculus_attack03.wav"
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
    {Sequence_LongLaugh, Sequence_LongLaugh, 3.6},
    {Sequence_TeleportIn, Sequence_TeleportIn, 1.0},
    {Sequence_TeleportOut, Sequence_TeleportOut, 1.0},
    {Sequence_Death, Sequence_Death, 8.36},
    {Sequence_LookAround1, Sequence_LookAround3, 6.0},
    {Sequence_Escape, Sequence_Escape, 4.16}
};

const Float:NPC_Health = 10000.0;
const Float:NPC_Speed = 32.0;
const Float:NPC_HitRange = 1024.0;
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

public plugin_precache()
{
    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/monoculus.mdl"),
        .vMins = Float:{-48.0, -48.0, -48.0},
        .vMaxs = Float:{48.0, 48.0, 48.0},
        .preset = CEPreset_NPC
    );
    
    g_bossHandler = Hwn_Bosses_RegisterBoss(ENTITY_NAME);

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
    
    precache_sound(g_szSndSpawn);
    precache_sound(g_szSndDeath);
    
    CE_RegisterHook(CEFunction_Spawn, PORTAL_ENTITY_NAME, "OnPortalSpawn");

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");
    
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTakeDamage", .Post = 1);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    g_cvarAngryTime = register_cvar("hwn_npc_monoculus_angry_time", "15.0");
    g_cvarDamageToStun = register_cvar("hwn_npc_monoculus_dmg_to_stun", "2000.0");
    g_cvarJumpTimeMin = register_cvar("hwn_npc_monoculus_jump_time_min", "10.0");
    g_cvarJumpTimeMax = register_cvar("hwn_npc_monoculus_jump_time_max", "20.0");

    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
    
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
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    
    UTIL_Message_Dlight(vOrigin, 32, {HWN_COLOR_PURPLE}, 60, 4);
        
    set_pev(ent, pev_health, NPC_Health);
    set_pev(ent, pev_movetype, MOVETYPE_FLY);
    
    NPC_Create(ent);
    new Array:monoculus = Monoculus_Create(ent);
    
    engfunc(EngFunc_DropToFloor, ent);

    set_pev(ent, pev_takedamage, DAMAGE_NO);
    NPC_EmitVoice(ent, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 1.0);
    NPC_PlayAction(ent, g_actions[Action_Spawn]);

    ArraySetCell(monoculus, Monoculus_IsStunned, false);
    ArraySetCell(monoculus, Monoculus_DamageToStun, get_pcvar_float(g_cvarDamageToStun));
    ArraySetCell(monoculus, Monoculus_IsAngry, false);
    
    CreateJumpToPortalTask(ent);

    set_task(g_actions[Action_Spawn][NPC_Action_Time], "TaskThink", ent);
}

public OnRemove(ent)
{
    remove_task(ent);
    remove_task(ent+TASKID_SUM_SHOT);
    remove_task(ent+TASKID_SUM_CALM_DOWN);
    remove_task(ent+TASKID_SUM_REMOVE_STUN);
    remove_task(ent+TASKID_SUM_PUSH_BACK_END);
    remove_task(ent+TASKID_SUM_IDLE_SOUND);
    remove_task(ent+TASKID_SUM_JUMP_TO_PORTAL);
    remove_task(ent+TASKID_SUM_TELEPORT);

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
        
        remove_task(ent);
        set_task(g_actions[Action_Death][NPC_Action_Time], "TaskThink", ent);
    } else if (deadflag == DEAD_DEAD) {
        return PLUGIN_CONTINUE;
    }
    
    return PLUGIN_HANDLED;
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }
    
    if (UTIL_IsPlayer(attacker)) {
        static Float:vOrigin[3];
        pev(attacker, pev_origin, vOrigin);

        if (random(100) < 30) {
            set_pev(ent, pev_enemy, attacker);
        }
    }
    
    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);

    UTIL_Message_BloodSprite(vEnd, g_sprBloodSpray, g_sprBlood, 212, floatround(fDamage/4));

    return HAM_IGNORED;
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

    if (random_num(0, 100) < 5) {
        MakeAngry(ent);
    }

    ArraySetCell(monoculus, Monoculus_DamageToStun, fDamageToStun);
}

/*--------------------------------[ Methods ]--------------------------------*/

Array:Monoculus_Create(ent)
{
    new Array:monoculus = ArrayCreate(Monoculus);
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
    
    if (pev(ent, pev_deadflag) == DEAD_DYING)
    {
        NPC_EmitVoice(ent, g_szSndDeath, .supercede = true);
        set_pev(ent, pev_deadflag, DEAD_DEAD);
        CE_Kill(ent);
        
        return;
    }
    
    if (pev(ent, pev_takedamage) == DAMAGE_NO) {
        set_pev(ent, pev_takedamage, DAMAGE_AIM);    
    }

    new Array:monoculus = Monoculus_Get(ent);
    new bool:isStunned = ArrayGetCell(monoculus, Monoculus_IsStunned);

    if (!isStunned) {
        new enemy = pev(ent, pev_enemy);
        if (NPC_IsValidEnemy(enemy) && Attack(ent, enemy)) {
            // do something
        } else {
            NPC_FindEnemy(ent, g_maxPlayers);
            set_pev(ent, pev_velocity, ZERO_VECTOR_F);
            NPC_PlayAction(ent, g_actions[Action_Idle]);
        }
        
        RandomHeight(ent);
    }
    
    set_task(g_fThinkDelay, "TaskThink", ent);
}

bool:Attack(ent, target)
{
    new Array:monoculus = Monoculus_Get(ent);

    static Float:vOrigin[3];    
    pev(ent, pev_origin, vOrigin);

    if (NPC_CanHit(ent, target, NPC_HitRange)) {
        new bool:isAngry = ArrayGetCell(monoculus, Monoculus_IsAngry);

        if (isAngry) {
            AngryShot(ent);
        } else {
            Shot(ent);
        }

        return true;
    }

    if (random(100) < 10) {
        NPC_EmitVoice(ent, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
    }

    static Float:vTarget[3];
    pev(target, pev_origin, vTarget);

    if (NPC_IsVisible(vOrigin, vTarget, ent)) {
        if (task_exists(ent+TASKID_SUM_PUSH_BACK_END)) {
            UTIL_TurnTo(ent, vTarget, bool:{false, false, true});
        } else {
            NPC_MoveToTarget(ent, vTarget, NPC_Speed);
        }

        NPC_PlayAction(ent, g_actions[Action_Idle]);
        return true;
    }

    return false;
}

BaseShot(ent, Float:attackDelay)
{
    set_pev(ent, pev_velocity, ZERO_VECTOR_F);

    new Array:npcData = NPC_GetData(ent);
    ArraySetCell(npcData, NPC_NextAttack, get_gametime() + attackDelay);
}

Shot(ent)
{
    set_task(NPC_AttackDelay, "Task_Shot", ent+TASKID_SUM_SHOT, _, _, "a", 1);

    NPC_PlayAction(ent, g_actions[Action_Attack]);
    BaseShot(ent, g_actions[Action_Attack][NPC_Action_Time] + 0.1);
}

AngryShot(ent)
{
    set_task(NPC_AttackDelay, "Task_Shot", ent+TASKID_SUM_SHOT, _, _, "a", 3);

    NPC_PlayAction(ent, g_actions[Action_AngryAttack]);
    BaseShot(ent, g_actions[Action_AngryAttack][NPC_Action_Time] + 0.1);
}

Stun(ent)
{   
    new Array:monoculus = Monoculus_Get(ent);
    ArraySetCell(monoculus, Monoculus_IsStunned, true);

    NPC_EmitVoice(ent, g_szSndStunned[random(sizeof(g_szSndStunned))], 1.0);
    NPC_PlayAction(ent, g_actions[Action_Stunned], .supercede = true);
    
    set_task(g_actions[Action_Stunned][NPC_Action_Time], "Task_RemoveStun", ent+TASKID_SUM_REMOVE_STUN);
}

MakeAngry(ent)
{
    new Array:monoculus = Monoculus_Get(ent);

    new bool:isAngry = ArrayGetCell(monoculus, Monoculus_IsAngry);

    if (!isAngry) {
        ArraySetCell(monoculus, Monoculus_IsAngry, true);
        set_task(get_pcvar_float(g_cvarAngryTime), "Task_CalmDown", ent+TASKID_SUM_CALM_DOWN);
    }
}

RandomHeight(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vVelocity[3];
    pev(ent, pev_velocity, vVelocity);

    new Float:fRandomHeight = random_float(MONOCULUS_MIN_HEIGHT, MONOCULUS_MAX_HEIGHT);
    new Float:fDistanceToFloor = UTIL_GetDistanceToFloor(vOrigin, ent);
    new direction = (fDistanceToFloor > fRandomHeight) ? -1 : 1;
    vVelocity[2] += 12.0 * direction;

    set_pev(ent, pev_velocity, vVelocity);
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

    set_task(0.25, "Task_PushBackEnd", ent+TASKID_SUM_PUSH_BACK_END);
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

    new portalIdx = random(size);
    if (portalIdx == ArrayGetCell(monoculus, Monoculus_NextPortal)) {
        return;
    }

    ArraySetCell(monoculus, Monoculus_NextPortal, portalIdx);

    NPC_PlayAction(ent, g_actions[Action_TeleportIn]);
    set_task(g_actions[Action_TeleportIn][NPC_Action_Time], "Task_Teleport", ent+TASKID_SUM_TELEPORT);
}

CreateJumpToPortalTask(ent)
{
    new Float:fMinTime = get_pcvar_float(g_cvarJumpTimeMin);
    new Float:fMaxTime = get_pcvar_float(g_cvarJumpTimeMax);
    set_task(random_float(fMinTime, fMaxTime), "Task_JumpToPortal", ent+TASKID_SUM_JUMP_TO_PORTAL);
}

TeleportEffect(const Float:vOrigin[3])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_SPRITETRAIL);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2] + 8.0);
    write_short(g_sprSparkle);
    write_byte(8); //Count
    write_byte(1); //Lifetime
    write_byte(4); //Scale
    write_byte(16); //Speed Noise
    write_byte(32); //Speed
    message_end();

    UTIL_Message_Dlight(vOrigin, 48, {HWN_COLOR_PURPLE}, 5, 32);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Shot(taskID)
{
    new ent = taskID - TASKID_SUM_SHOT;

    PushBack(ent);
    SpawnRocket(ent);
    NPC_EmitVoice(ent, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.3);
}

public Task_CalmDown(taskID)
{
    new ent = taskID - TASKID_SUM_CALM_DOWN;

    new Array:monoculus = Monoculus_Get(ent);
    ArraySetCell(monoculus, Monoculus_IsAngry, false);
}

public Task_RemoveStun(taskID)
{
    new ent = taskID - TASKID_SUM_REMOVE_STUN;

    new Array:monoculus = Monoculus_Get(ent);
    ArraySetCell(monoculus, Monoculus_IsStunned, false);
}

public Task_PushBackEnd(taskID)
{
    new ent = taskID - TASKID_SUM_PUSH_BACK_END;
    set_pev(ent, pev_velocity, ZERO_VECTOR_F);
}

public Task_JumpToPortal(taskID)
{
    new ent = taskID - TASKID_SUM_JUMP_TO_PORTAL;
    JumpToPortal(ent);
    CreateJumpToPortalTask(ent);
}

public Task_Teleport(taskID)
{
    new ent = taskID - TASKID_SUM_TELEPORT;

    client_cmd(0, "spk %s", g_szSndMoved);
    NPC_EmitVoice(ent, g_szSndSpawn, 1.0);

    new Array:monoculus = Monoculus_Get(ent);
    new portalIdx = ArrayGetCell(monoculus, Monoculus_NextPortal);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    TeleportEffect(vOrigin);

    static Float:vTargetOrigin[3];
    ArrayGetArray(g_portals, portalIdx, vTargetOrigin);
    set_pev(ent, pev_origin, vTargetOrigin);
    TeleportEffect(vTargetOrigin);

    static Float:vTargetAngles[3];
    ArrayGetArray(g_portalAngles, portalIdx, vTargetAngles);
    set_pev(ent, pev_angles, vTargetAngles);

    NPC_PlayAction(ent, g_actions[Action_TeleportOut]);
}
