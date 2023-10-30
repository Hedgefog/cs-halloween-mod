#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_navsystem>

#include <hwn>
#include <hwn_utils>
#include <hwn_npc_stocks>

#define PLUGIN "[Custom Entity] Hwn NPC Spooky Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_spookypumpkin"
#define ENTITY_NAME_BIG "hwn_npc_spookypumpkin_big"

#define m_irgPath "irgPath"
#define m_vecGoal "vecGoal"
#define m_vecTarget "vecTarget"
#define m_pBuildPathTask "pBuildPathTask"
#define m_flReleaseHit "flReleaseHit"
#define m_flTargetArrivalTime "flTargetArrivalTime"
#define m_flNextAIThink "flNextAIThink"
#define m_flNextAction "flNextAction"
#define m_flNextAttack "flNextAttack"
#define m_flNextPathSearch "flNextPathSearch"
#define m_flNextLaugh "flNextLaugh"
#define m_pKiller "pKiller"
#define m_flReleaseJump "flReleaseJump"
#define m_bBig "bBig"

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
const Float:NPC_PathSearchDelay = 5.0;
const Float:NPC_TargetUpdateRate = 1.0;

const Float:NPC_Big_Health = 200.0;
const Float:NPC_Big_Damage = 40.0;
const Float:NPC_JumpVelocity = 160.0;
const Float:NPC_AttackJumpVelocity = 256.0;

new const Float:NPC_TargetHitOffset[3] = {0.0, 0.0, 16.0};

new const g_szSndIdleList[][] = {
    "hwn/npc/spookypumpkin/sp_laugh01.wav",
    "hwn/npc/spookypumpkin/sp_laugh02.wav",
    "hwn/npc/spookypumpkin/sp_laugh03.wav"
};

new const g_rgActions[Action][NPC_Action] = {
    { Sequence_Idle, Sequence_Idle, 0.0 },
    { Sequence_JumpStart, Sequence_JumpStart, 0.6 },
    { Sequence_JumpFloat, Sequence_JumpFloat, 0.0 },
    { Sequence_Why, Sequence_Why, 0.0 },
    { Sequence_Attack, Sequence_Attack, 1.2 }
};

new g_pCvarUseAstar;
new g_pCvarPumpkinMutateChance;

new g_iGibsModelIndex;

new g_iCeHandler;
new g_iCeHandlerBig;

public plugin_precache() {
    Nav_Precache();

    g_iGibsModelIndex = precache_model("models/hwn/props/pumpkin_explode_jib_v2.mdl");

    for (new i = 0; i < sizeof(g_szSndIdleList); ++i) {
        precache_sound(g_szSndIdleList[i]);
    }

    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/npc/spookypumpkin.mdl",
        .vMins = Float:{-12.0, -12.0, 0.0},
        .vMaxs = Float:{12.0, 12.0, 24.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC,
        .bloodColor = 103
    );

    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Restart, ENTITY_NAME, "@Entity_Restart");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    g_iCeHandlerBig = CE_Register(
        ENTITY_NAME_BIG,
        .szModel = "models/hwn/npc/spookypumpkin_big.mdl",
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 32.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC,
        .bloodColor = 103
    );

    CE_RegisterHook(CEFunction_Init, ENTITY_NAME_BIG, "@Entity_Init");
    CE_RegisterHook(CEFunction_Restart, ENTITY_NAME_BIG, "@Entity_Restart");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_BIG, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_BIG, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME_BIG, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME_BIG, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME_BIG, "@Entity_Think");

    CE_RegisterHook(CEFunction_Killed, "hwn_item_pumpkin", "@Pumpkin_Killed");
    CE_RegisterHook(CEFunction_Killed, "hwn_item_pumpkin_big", "@BigPumpkin_Killed");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    g_pCvarUseAstar = register_cvar("hwn_npc_spookypumpkin_use_astar", "1");
    g_pCvarPumpkinMutateChance = register_cvar("hwn_pumpkin_mutate_chance", "20");
}

/*--------------------------------[ Hooks ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
    CE_SetMember(this, m_irgPath, ArrayCreate(3));
}

@Entity_Restart(this) {
    @Entity_ResetPath(this);
}

@Entity_Spawn(this) {
    new Float:flGameTime = get_gametime();

    new bool:bBig = CE_GetHandlerByEntity(this) == g_iCeHandlerBig;

    CE_SetMember(this, m_bBig, bBig);
    CE_SetMember(this, m_flNextAttack, 0.0);
    CE_SetMember(this, m_flReleaseHit, 0.0);
    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_flNextAction, flGameTime);
    CE_SetMember(this, m_flNextLaugh, flGameTime);
    CE_SetMember(this, m_flNextPathSearch, flGameTime);
    CE_SetMember(this, m_flTargetArrivalTime, 0.0);
    CE_SetMember(this, m_flReleaseJump, 0.0);
    CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
    CE_SetMember(this, m_pKiller, 0);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, {HWN_COLOR_ORANGE_DIRTY_F});
    set_pev(this, pev_health, bBig ? NPC_Big_Health : NPC_Health);
    set_pev(this, pev_takedamage, DAMAGE_AIM);
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 12.0});
    set_pev(this, pev_maxspeed, NPC_Speed);
    set_pev(this, pev_dmg, bBig ? NPC_Big_Damage : NPC_Damage);
    set_pev(this, pev_enemy, 0);

    engfunc(EngFunc_DropToFloor, this);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    if (bBig) {
        UTIL_Message_Dlight(vecOrigin, 16, {HWN_COLOR_YELLOW}, 20, 8);
    } else {
        UTIL_Message_Dlight(vecOrigin, 8, {HWN_COLOR_YELLOW}, 20, 8);
    }

    @Entity_Laugh(this);

    set_pev(this, pev_nextthink, flGameTime);
}

@Entity_Kill(this, pKiller) {
    new Float:flGameTime = get_gametime();

    new iDeadFlag = pev(this, pev_deadflag);

    CE_SetMember(this, m_pKiller, pKiller);

    if (pKiller && iDeadFlag == DEAD_NO) {
        NPC_StopMovement(this);

        set_pev(this, pev_takedamage, DAMAGE_NO);
        set_pev(this, pev_deadflag, DEAD_DYING);

        CE_SetMember(this, m_flNextAIThink, flGameTime + 0.1);
        set_pev(this, pev_nextthink, flGameTime + 0.1);
    
        // cancel first kill function to play duing animation
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

@Entity_Killed(this) {
    @Entity_ResetPath(this);
    @Entity_DisappearEffect(this);
}

@Entity_Remove(this) {
    @Entity_ResetPath(this);

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    ArrayDestroy(irgPath);
}

@Entity_Laugh(this) {
    @Entity_EmitVoice(this, g_szSndIdleList[random(sizeof(g_szSndIdleList))], 2.0);
}

@Entity_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (IS_PLAYER(pAttacker) && NPC_IsValidEnemy(pAttacker)) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        static Float:vecTarget[3];
        pev(pAttacker, pev_origin, vecTarget);

        // new bool:bBig = CE_GetMember(this, m_bBig);    
        new Float:flHitRange = NPC_HitRange;

        if (get_distance_f(vecOrigin, vecTarget) <= flHitRange && NPC_IsVisible(this, vecTarget)) {
            if (random(100) < 10) {
                set_pev(this, pev_enemy, pAttacker);
            }
        }
    }
}

@Entity_Think(this) {
    new Float:flGameTime = get_gametime();
    new Float:flNextAIThink = CE_GetMember(this, m_flNextAIThink);
    new bool:bShouldUpdateAI = flNextAIThink <= flGameTime;
    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (bShouldUpdateAI) {
                @Entity_AIThink(this);
                CE_SetMember(this, m_flNextAIThink, flGameTime + Hwn_GetNpcUpdateRate());
            }

            // update velocity at high rate to avoid inconsistent velocity
            if (CE_HasMember(this, m_vecTarget)) {
                static Float:vecTarget[3];
                CE_GetMemberVec(this, m_vecTarget, vecTarget);
                @Entity_MoveTo(this, vecTarget);
            }
        }
        case DEAD_DYING: {
            CE_Kill(this, CE_GetMember(this, m_pKiller));
            return;
        }
        case DEAD_DEAD, DEAD_RESPAWNABLE: {
            return;
        }
    }

    // animations update based on NPC activity
    if (bShouldUpdateAI) {
        new Action:iAction = @Entity_GetAction(this);
        @Entity_PlayAction(this, iAction, false);
    }

    set_pev(this, pev_ltime, flGameTime);
    set_pev(this, pev_nextthink, flGameTime + 0.01);
}

@Entity_AIThink(this) {
    // new bool:bBig = CE_GetMember(this, m_bBig);

    static Float:flLastThink;
    pev(this, pev_ltime, flLastThink);

    static Float:flGameTime; flGameTime = get_gametime();
    // new Float:flRate = Hwn_GetNpcUpdateRate();
    // new Float:flDelta = flGameTime - flLastThink;

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    new Float:flHitRange = NPC_HitRange;
    new Float:flHitDelay = NPC_HitDelay;

    static Float:flReleaseJump; flReleaseJump = CE_GetMember(this, m_flReleaseJump);
    if (flReleaseJump && flReleaseJump <= flGameTime) {
        @Entity_Jump(this);
        CE_SetMember(this, m_flReleaseJump, 0.0);
    }

    static Float:flReleaseHit; flReleaseHit = CE_GetMember(this, m_flReleaseHit);
    if (!flReleaseHit) {
        static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
        if (flNextAttack <= get_gametime()) {
            static pEnemy; pEnemy = NPC_GetEnemy(this);
            if (pEnemy && NPC_CanHit(this, pEnemy, flHitRange, NPC_TargetHitOffset)) {
                CE_SetMember(this, m_flReleaseHit, flGameTime + flHitDelay);
                @Entity_PlayAction(this, Action_Attack, true);
                @Entity_StartJump(this, 0.0);

                static Float:vecTargetVelocity[3];
                pev(pEnemy, pev_velocity, vecTargetVelocity);
                if (xs_vec_len(vecTargetVelocity) < flHitRange) {
                    NPC_StopMovement(this);
                }
            }
        }
    } else if (flReleaseHit <= flGameTime) {
        static Float:flDamage;
        pev(this, pev_dmg, flDamage);

        NPC_Hit(this, NPC_Damage, flHitRange, NPC_TargetHitOffset);

        CE_SetMember(this, m_flReleaseHit, 0.0);
        CE_SetMember(this, m_flNextAttack, flGameTime + 0.5);
    }

    @Entity_UpdateGoal(this);
    @Entity_UpdateTarget(this);

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    if (xs_vec_len(vecVelocity) > 50.0) {
        static Float:flNextLaugh; flNextLaugh = CE_GetMember(this, m_flNextLaugh);
        if (flNextLaugh <= flGameTime) {
            @Entity_Laugh(this);
            CE_SetMember(this, m_flNextLaugh, flGameTime + random_float(1.0, 2.0));
        }
    }

    static Action:iAction; iAction = @Entity_GetAction(this);
    @Entity_PlayAction(this, iAction, false);
}

@Entity_MoveTo(this, const Float:vecTarget[3]) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flLastThink; pev(this, pev_ltime, flLastThink);
    static Float:flDelta; flDelta = flGameTime - flLastThink;
    static Float:flMaxAngle; flMaxAngle = 180.0 * floatmin(flDelta, 0.1);

    UTIL_TurnTo(this, vecTarget, bool:{true, false, true}, flMaxAngle);

    if (NPC_IsInViewCone(this, vecTarget, 15.0)) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        if (get_distance_f(vecOrigin, vecTarget) > 1.0) {
            static Float:vecOrigin[3];
            pev(this, pev_origin, vecOrigin);
            @Entity_StartJump(this, g_rgActions[Action_JumpStart][NPC_Action_Time]);
        }
    }
}

bool:@Entity_StartJump(this, Float:flJumpDelay) {
    if (~pev(this, pev_flags) & FL_ONGROUND) {
        return false;
    }

    static Float:flReleaseJump; flReleaseJump = CE_GetMember(this, m_flReleaseJump);
    if (flReleaseJump) {
        return false;
    }

    static Float:flGameTime; flGameTime = get_gametime();
    CE_SetMember(this, m_flReleaseJump, flGameTime + flJumpDelay);
    @Entity_PlayAction(this, Action_JumpStart, false);

    return true;
}

bool:@Entity_Jump(this) {
    if (~pev(this, pev_flags) & FL_ONGROUND) {
        return;
    }

    static Float:flReleaseHit; flReleaseHit = CE_GetMember(this, m_flReleaseHit);

    static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);

    static Float:vecVelocity[3];
    UTIL_GetDirectionVector(this, vecVelocity, flMaxSpeed);
    vecVelocity[2] = flReleaseHit ? NPC_AttackJumpVelocity : NPC_JumpVelocity;

    set_pev(this, pev_velocity, vecVelocity);

    @Entity_PlayAction(this, Action_JumpFloat, false);
}

@Entity_EmitVoice(this, const szSound[], Float:flDuration) {
    emit_sound(this, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_UpdateGoal(this) {
    new pEnemy = pev(this, pev_enemy);

    if (@Entity_UpdateEnemy(this, NPC_ViewRange, 0.0)) {
        pEnemy = pev(this, pev_enemy);
    }

    static Float:vecGoal[3];
    pev(pEnemy, pev_origin, vecGoal);
    CE_SetMemberVec(this, m_vecGoal, vecGoal);
}

@Entity_UpdateEnemy(this, Float:flMaxDistance, Float:flMinPriority) {
    return NPC_UpdateEnemy(this, flMaxDistance, flMinPriority);
}

@Entity_UpdateTarget(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (CE_HasMember(this, m_vecTarget)) {
        static Float:flArrivalTime; flArrivalTime = CE_GetMember(this, m_flTargetArrivalTime);

        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        static Float:vecMins[3];
        pev(this, pev_mins, vecMins);

        static Float:vecTarget[3];
        CE_GetMemberVec(this, m_vecTarget, vecTarget);
    
        new bool:bHasReached = xs_vec_distance_2d(vecOrigin, vecTarget) < 10.0;
        if (bHasReached || flGameTime > flArrivalTime) {
            CE_DeleteMember(this, m_vecTarget);
        }
    }

    @Entity_ProcessPath(this);

    if (CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3];
        CE_GetMemberVec(this, m_vecGoal, vecGoal);

        if (!NPC_IsReachable(this, vecGoal, pev(this, pev_enemy))) {
            if (get_pcvar_bool(g_pCvarUseAstar)) {
                if (CE_GetMember(this, m_flNextPathSearch) <= flGameTime) {
                    @Entity_FindPath(this, vecGoal);
                    CE_SetMember(this, m_flNextPathSearch, flGameTime + NPC_PathSearchDelay);
                    CE_DeleteMember(this, m_vecTarget);
                }
            } else {
                CE_DeleteMember(this, m_vecGoal);
                CE_DeleteMember(this, m_vecTarget);
            }
        } else {
            CE_DeleteMember(this, m_vecGoal);
            @Entity_SetTarget(this, vecGoal);
        }
    }
}

@Entity_SetTarget(this, const Float:vecTarget[3]) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static Float:flMaxSpeed;
    pev(this, pev_maxspeed, flMaxSpeed);

    new Float:flDuration = xs_vec_distance(vecOrigin, vecTarget) / flMaxSpeed;

    CE_SetMemberVec(this, m_vecTarget, vecTarget);
    CE_SetMember(this, m_flTargetArrivalTime, get_gametime() + flDuration);
}

bool:@Entity_PlayAction(this, Action:iAction, bool:bSupercede) {
    new Float:flGametime = get_gametime();
    if (!bSupercede && flGametime < CE_GetMember(this, m_flNextAction)) {
        return false;
    }

    new iSequence = random_num(g_rgActions[iAction][NPC_Action_StartSequence], g_rgActions[iAction][NPC_Action_EndSequence]);

    if (!UTIL_SetSequence(this, iSequence)) {
        return false;
    }

    CE_SetMember(this, m_flNextAction, flGametime + g_rgActions[iAction][NPC_Action_Time]);

    return true;
}

Action:@Entity_GetAction(this) {
    return Action_Idle;
}

@Entity_FindPath(this, Float:vecTarget[3]) {
    @Entity_ResetPath(this);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new NavBuildPathTask:pTask = Nav_Path_Find(vecOrigin, vecTarget, "NavPathCallback", this, this, "NavPathCost");
    CE_SetMember(this, m_pBuildPathTask, pTask);
}

@Entity_ResetPath(this) {
    new Array:irgPath = CE_GetMember(this, m_irgPath);
    ArrayClear(irgPath);

    new NavBuildPathTask:pTask = CE_GetMember(this, m_pBuildPathTask);
    if (pTask != Invalid_NavBuildPathTask) {
        Nav_Path_FindTask_Abort(pTask);
        CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
    }

    // CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
}

bool:@Entity_ProcessPath(this) {
    if (CE_HasMember(this, m_vecTarget)) {
        return true;
    }

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    if (!ArraySize(irgPath)) {
        // set_pev(this, pev_enemy, 0);
        return false;
    }
    
    static Float:vecMins[3];
    pev(this, pev_mins, vecMins);

    static Float:vecTarget[3];
    ArrayGetArray(irgPath, 0, vecTarget);
    ArrayDeleteItem(irgPath, 0);
    vecTarget[2] -= vecMins[2];

    @Entity_SetTarget(this, vecTarget);

    return true;
}

Float:@Entity_GetPathCost(this, NavArea:newArea, NavArea:prevArea) {
    return NPC_GetPathCost(this, newArea, prevArea);
}

@Entity_HandlePath(this, NavPath:pPath) {
    if (Nav_Path_IsValid(pPath)) {
        new Array:irgSegments = Nav_Path_GetSegments(pPath);
        
        new Array:irgPath = CE_GetMember(this, m_irgPath);
        ArrayClear(irgPath);

        for (new i = 0; i < ArraySize(irgSegments); ++i) {
            new NavPathSegment:pSegment = ArrayGetCell(irgSegments, i);
            static Float:vecPos[3];
            Nav_Path_Segment_GetPos(pSegment, vecPos);
            ArrayPushArray(irgPath, vecPos, sizeof(vecPos));
        }
    } else {
        set_pev(this, pev_enemy, 0);
    }

    CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
}

@Entity_DisappearEffect(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new Float:vecVelocity[3];
    UTIL_RandomVector(-16.0, 16.0, vecVelocity);

    UTIL_Message_Dlight(vecOrigin, CE_GetMember(this, m_bBig) ? 16 : 8, {HWN_COLOR_YELLOW}, 10, 32);
    UTIL_Message_BreakModel(vecOrigin, Float:{4.0, 4.0, 4.0}, vecVelocity, 32, g_iGibsModelIndex, 4, 25, 0);
}

@Pumpkin_Killed(this, pKiller, bool:bPicked) {
    if (bPicked) {
        return;
    }

    @Pumpkin_Mutate(this, false);
}

@BigPumpkin_Killed(this, pKiller, bool:bPicked) {
    if (bPicked) {
        return;
    }

    @Pumpkin_Mutate(this, true);
}

@Pumpkin_Mutate(this, bool:bBig) {
    new chance = get_pcvar_num(g_pCvarPumpkinMutateChance);
    if (!chance) {
        return;
    }

    if (random(100) > chance) {
        return;
    }

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pMonster = CE_Create(bBig ? ENTITY_NAME_BIG : ENTITY_NAME, vecOrigin);
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

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    new iHandler = CE_GetHandlerByEntity(pEntity);
    if (iHandler == g_iCeHandler || iHandler == g_iCeHandlerBig) {
        @Entity_TakeDamage(pEntity,  pInflictor, pAttacker, flDamage, iDamageBits);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public Float:NavPathCost(NavBuildPathTask:pTask, NavArea:newArea, NavArea:prevArea) {
    new pEntity = Nav_Path_FindTask_GetUserToken(pTask);
    if (!pEntity) {
        return 1.0;
    }
    
    return @Entity_GetPathCost(pEntity, newArea, prevArea);
}

public NavPathCallback(NavBuildPathTask:pTask) {
    new pEntity = Nav_Path_FindTask_GetUserToken(pTask);
    new NavPath:pPath = Nav_Path_FindTask_GetPath(pTask);
    @Entity_HandlePath(pEntity, pPath);
}
