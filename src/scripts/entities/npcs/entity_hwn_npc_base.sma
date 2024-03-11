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

#define PLUGIN "[Custom Entity] Hwn NPC Base"
#define AUTHOR "Hedgehog Fog"

#define STEP_HEIGHT 18.0
#define ENTITY_NAME "hwn_npc_base"

#define m_flDamage "flDamage"
#define m_irgPath "irgPath"
#define m_vecGoal "vecGoal"
#define m_vecTarget "vecTarget"
#define m_pBuildPathTask "pBuildPathTask"
#define m_flReleaseAttack "flReleaseAttack"
#define m_flTargetArrivalTime "flTargetArrivalTime"
#define m_flNextAIThink "flNextAIThink"
#define m_flNextAction "flNextAction"
#define m_flNextAttack "flNextAttack"
#define m_flNextPathSearch "flNextPathSearch"
#define m_pKiller "pKiller"
#define m_flAttackRate "flAttackRate"
#define m_flAttackRange "flAttackRange"
#define m_flAttackDelay "flAttackDelay"
#define m_flViewRange "flViewRange"
#define m_flFindRange "flFindRange"
#define m_irgActions "irgActions"
#define m_vecHitOffset "vecHitOffset"
#define m_flDieDuration "flDieDuration"

#define EmitVoice "EmitVoice"
#define ResetPath "ResetPath"
#define AIThink "AIThink"
#define UpdateEnemy "UpdateEnemy"
#define UpdateGoal "UpdateGoal"
#define TakeDamage "TakeDamage"
#define ProcessPath "ProcessPath"
#define ProcessTarget "ProcessTarget"
#define ProcessGoal "ProcessGoal"
#define SetTarget "SetTarget"
#define MoveTo "MoveTo"
#define UpdateTarget "UpdateTarget"
#define FindPath "FindPath"
#define GetPathCost "GetPathCost"
#define HandlePath "HandlePath"
#define Hit "Hit"
#define StartAttack "StartAttack"
#define GetEnemy "GetEnemy"
#define IsValidEnemy "IsValidEnemy"
#define ReleaseAttack "ReleaseAttack"
#define CanAttack "CanAttack"
// #define RegisterAction "RegisterAction"
#define PlayAction "PlayAction"
#define AttackThink "AttackThink"
#define IsVisible "IsVisible"
#define IsReachable "IsReachable"
#define FindEnemy "FindEnemy"
#define TestStep "TestStep"
#define MoveForward "MoveForward"
#define StopMovement "StopMovement"
#define IsInViewCone "IsInViewCone"
#define Dying "Dying"

enum _:Sequence {
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

enum Action {
    Action_Idle = 0,
    Action_Run,
    Action_Attack,
    Action_RunAttack,
    Action_Spawn
};

const Float:NPC_PathSearchDelay = 5.0;

new g_pCvarUseAstar;

new g_pTrace;

public plugin_precache() {
    Nav_Precache();

    g_pTrace = create_tr2();

    CE_Register(ENTITY_NAME, CEPreset_NPC);

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Restart, "@Entity_Restart");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Kill, "@Entity_Kill");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_RegisterMethod(ENTITY_NAME, PlayAction, "@Entity_PlayAction", CE_MP_Cell, CE_MP_Cell, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, EmitVoice, "@Entity_EmitVoice", CE_MP_String, CE_MP_Cell);

    CE_RegisterVirtualMethod(ENTITY_NAME, ResetPath, "@Entity_ResetPath");
    CE_RegisterVirtualMethod(ENTITY_NAME, AttackThink, "@Entity_AttackThink");
    CE_RegisterVirtualMethod(ENTITY_NAME, ProcessPath, "@Entity_ProcessPath");
    CE_RegisterVirtualMethod(ENTITY_NAME, ProcessTarget, "@Entity_ProcessTarget");
    CE_RegisterVirtualMethod(ENTITY_NAME, ProcessGoal, "@Entity_ProcessGoal");
    CE_RegisterVirtualMethod(ENTITY_NAME, SetTarget, "@Entity_SetTarget", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");
    CE_RegisterVirtualMethod(ENTITY_NAME, GetEnemy, "@Entity_GetEnemy");
    CE_RegisterVirtualMethod(ENTITY_NAME, IsValidEnemy, "@Entity_IsValidEnemy", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, UpdateEnemy, "@Entity_UpdateEnemy");
    CE_RegisterVirtualMethod(ENTITY_NAME, UpdateGoal, "@Entity_UpdateGoal");
    CE_RegisterVirtualMethod(ENTITY_NAME, CanAttack, "@Entity_CanAttack", CE_MP_Cell, CE_MP_Float, CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, StartAttack, "@Entity_StartAttack", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, ReleaseAttack, "@Entity_ReleaseAttack", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, Hit, "@Entity_Hit", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, HandlePath, "@Entity_HandlePath", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, UpdateTarget, "@Entity_UpdateTarget");
    CE_RegisterVirtualMethod(ENTITY_NAME, Dying, "@Entity_Dying");
    CE_RegisterVirtualMethod(ENTITY_NAME, GetPathCost, "@Entity_GetPathCost", CE_MP_Cell, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, FindPath, "@Entity_FindPath", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, MoveTo, "@Entity_MoveTo", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, TakeDamage, "@Entity_TakeDamage", CE_MP_Cell, CE_MP_Cell, CE_MP_Float, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, IsVisible, "@Entity_IsVisible", CE_MP_FloatArray, 3, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, FindEnemy, "@Entity_FindEnemy", CE_MP_Float, CE_MP_Float, CE_MP_Cell, CE_MP_Cell, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, IsReachable, "@Entity_IsReachable", CE_MP_FloatArray, 3, CE_MP_Cell, CE_MP_Float);
    CE_RegisterVirtualMethod(ENTITY_NAME, TestStep, "@Entity_TestStep", CE_MP_FloatArray, 3, CE_MP_FloatArray, 3, CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, MoveForward, "@Entity_MoveForward");
    CE_RegisterVirtualMethod(ENTITY_NAME, StopMovement, "@Entity_StopMovement");
    CE_RegisterVirtualMethod(ENTITY_NAME, IsInViewCone, "@Entity_IsInViewCone", CE_MP_FloatArray, 3);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    g_pCvarUseAstar = register_cvar("hwn_npc_use_astar", "1");
}

public plugin_end() {
    free_tr2(g_pTrace);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, -32.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 32.0});
    CE_SetMember(this, CE_MEMBER_LIFETIME, HWN_NPC_LIFE_TIME);
    CE_SetMember(this, CE_MEMBER_RESPAWNTIME, HWN_NPC_RESPAWN_TIME);
    CE_SetMember(this, CE_MEMBER_BLOODCOLOR, 242);
    CE_SetMemberVec(this, m_vecHitOffset, Float:{0.0, 0.0, 0.0});
    CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
    CE_SetMember(this, m_irgPath, ArrayCreate(3));
    CE_SetMember(this, m_flAttackRange, 0.0);
    CE_SetMember(this, m_flAttackRate, 0.0);
    CE_SetMember(this, m_flAttackDelay, 0.0);
    CE_SetMember(this, m_flDamage, 0.0);
    CE_SetMember(this, m_flDieDuration, 0.1);
    CE_SetMember(this, m_irgActions, ArrayCreate(_:NPC_Action, 16));
}

@Entity_Restart(this) {
    CE_CallMethod(this, ResetPath);
}

@Entity_Spawned(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    CE_SetMember(this, m_flNextAttack, 0.0);
    CE_SetMember(this, m_flReleaseAttack, 0.0);
    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_flNextAction, flGameTime);
    CE_SetMember(this, m_flNextPathSearch, flGameTime);
    CE_SetMember(this, m_flTargetArrivalTime, 0.0);
    CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
    CE_SetMember(this, m_pKiller, 0);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, Float:{0.0, 0.0, 0.0});
    set_pev(this, pev_health, 1.0);
    set_pev(this, pev_takedamage, DAMAGE_AIM);
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 32.0});
    set_pev(this, pev_maxspeed, 0.0);
    set_pev(this, pev_enemy, 0);
    set_pev(this, pev_fov, 90.0);

    engfunc(EngFunc_DropToFloor, this);

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecMaxs[3]; CE_GetMemberVec(this, CE_MEMBER_MAXS, vecMaxs);
    UTIL_Message_Dlight(vecOrigin, floatround(floatmax(vecMaxs[0], vecMaxs[1])), {HWN_COLOR_SECONDARY}, 20, 8);

    set_pev(this, pev_nextthink, flGameTime + 0.1);
}

@Entity_Kill(this, pKiller) {
    new Float:flGameTime = get_gametime();

    new iDeadFlag = pev(this, pev_deadflag);

    CE_SetMember(this, m_pKiller, pKiller);

    if (pKiller && iDeadFlag == DEAD_NO) {
        CE_CallMethod(this, StopMovement);

        new Float:flDieDuration = CE_GetMember(this, m_flDieDuration);

        set_pev(this, pev_takedamage, DAMAGE_NO);
        set_pev(this, pev_deadflag, DEAD_DYING);
        set_pev(this, pev_nextthink, flGameTime + flDieDuration);

        CE_SetMember(this, m_flNextAIThink, flGameTime + flDieDuration);

        // cancel first kill function to play duing animation
        CE_CallMethod(this, Dying);

        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

@Entity_Killed(this) {
    CE_CallMethod(this, ResetPath);
}

@Entity_Dying(this) {} 

@Entity_Remove(this) {
    CE_CallMethod(this, ResetPath);

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    ArrayDestroy(irgPath);

    new Array:irgActions = CE_GetMember(this, m_irgActions);
    ArrayDestroy(irgActions);
}

@Entity_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (IS_PLAYER(pAttacker) && CE_CallMethod(this, IsValidEnemy, pAttacker)) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        static Float:vecTarget[3]; pev(pAttacker, pev_origin, vecTarget);
        static Float:flAttackRange; flAttackRange = CE_GetMember(this, m_flAttackRange);

        if (get_distance_f(vecOrigin, vecTarget) <= flAttackRange && CE_CallMethod(this, IsVisible, vecTarget, 0)) {
            if (random(100) < 10) {
                set_pev(this, pev_enemy, pAttacker);
            }
        }
    }
}

@Entity_Think(this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flNextAIThink; flNextAIThink = CE_GetMember(this, m_flNextAIThink);
    static bool:bShouldUpdateAI; bShouldUpdateAI = flNextAIThink <= flGameTime;
    static iDeadFlag; iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (bShouldUpdateAI) {
                CE_CallMethod(this, AIThink);
                CE_SetMember(this, m_flNextAIThink, flGameTime + Hwn_GetNpcUpdateRate());
            }

            // update velocity at high rate to avoid inconsistent velocity
            if (CE_HasMember(this, m_vecTarget)) {
                static Float:vecTarget[3]; CE_GetMemberVec(this, m_vecTarget, vecTarget);
                CE_CallMethod(this, MoveTo, vecTarget);
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

    set_pev(this, pev_ltime, flGameTime);
    set_pev(this, pev_nextthink, flGameTime + 0.01);
}

@Entity_AIThink(this) {
    CE_CallMethod(this, AttackThink);
    CE_CallMethod(this, UpdateGoal);
    CE_CallMethod(this, UpdateTarget);
}

@Entity_AttackThink(this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flAttackRange; flAttackRange = CE_GetMember(this, m_flAttackRange);
    static Float:flAttackDelay; flAttackDelay = CE_GetMember(this, m_flAttackDelay);
    static Float:vecHitOffset[3]; CE_GetMemberVec(this, m_vecHitOffset, vecHitOffset);
    static Float:flDamage; flDamage = CE_GetMember(this, m_flDamage);
    static pEnemy; pEnemy = CE_CallMethod(this, GetEnemy);

    static Float:flReleaseAttack; flReleaseAttack = CE_GetMember(this, m_flReleaseAttack);
    if (!flReleaseAttack) {
        static Float:flGameTime; flGameTime = get_gametime();
        static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
        if (flNextAttack <= flGameTime) {
            if (pEnemy && CE_CallMethod(this, CanAttack, pEnemy, flAttackRange, vecHitOffset)) {
                CE_CallMethod(this, StartAttack, flDamage, flAttackRange, vecHitOffset, flAttackDelay, pEnemy);
            }
        }
    } else if (flReleaseAttack <= flGameTime) {
        CE_CallMethod(this, ReleaseAttack, flDamage, flAttackRange, vecHitOffset, flAttackDelay, pEnemy);
    }
}

@Entity_CanAttack(this, pEnemy, Float:flAttackRange, Float:vecOffset[3]) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecTarget[3]; pev(pEnemy, pev_origin, vecTarget);

    xs_vec_add(vecTarget, vecOffset, vecTarget);

    if (get_distance_f(vecOrigin, vecTarget) > flAttackRange) return false;

    // if (!@Entity_IsInViewCone(this, vecTarget, 60.0)) {
    //     return false;
    // }

    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, this, g_pTrace);

    static Float:flFraction; get_tr2(g_pTrace, TR_flFraction, flFraction);

    new bool:bResult = false;

    if (flFraction != 1.0) {
        if (get_tr2(g_pTrace, TR_pHit) == pEnemy) {
            get_tr2(g_pTrace, TR_vecEndPos, vecTarget);
            bResult = (get_distance_f(vecOrigin, vecTarget) <= flAttackRange);
        }
    }

    return bResult;
}

@Entity_StartAttack(this, Float:flDamage, Float:flAttackRange, Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    static Float:flGameTime; flGameTime = get_gametime();

    CE_SetMember(this, m_flReleaseAttack, flGameTime + flAttackDelay);

    static Float:vecTargetVelocity[3]; pev(pEnemy, pev_velocity, vecTargetVelocity);
    if (xs_vec_len(vecTargetVelocity) < flAttackRange) {
        CE_CallMethod(this, StopMovement);
    }
}

@Entity_ReleaseAttack(this, Float:flDamage, Float:flAttackRange, Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    CE_CallMethod(this, Hit, flDamage, flAttackRange, vecHitOffset, flAttackDelay, pEnemy);
    
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flAttackRate; flAttackRate = CE_GetMember(this, m_flAttackRate);

    CE_SetMember(this, m_flReleaseAttack, 0.0);
    CE_SetMember(this, m_flNextAttack, flGameTime + flAttackRate);
}

@Entity_Hit(this, Float:flDamage, Float:flAttackRange, const Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecDirection[3]; UTIL_GetDirectionVector(this, vecDirection);

    static Float:vecTarget[3];
    xs_vec_mul_scalar(vecDirection, flAttackRange, vecTarget);
    xs_vec_add(vecTarget, vecOrigin, vecTarget);
    xs_vec_add(vecTarget, vecHitOffset, vecTarget);

    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, this, g_pTrace);

    static pTarget; pTarget = get_tr2(g_pTrace, TR_pHit);
    if (pTarget == -1) {
        engfunc(EngFunc_TraceHull, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, HULL_HEAD, this, g_pTrace);
        pTarget = get_tr2(g_pTrace, TR_pHit);
    }

    static bool:bHit; bHit = pTarget != -1;

    if (bHit) {
        get_tr2(g_pTrace, TR_vecEndPos, vecTarget);
        xs_vec_sub(vecOrigin, vecTarget, vecDirection);
        xs_vec_normalize(vecDirection, vecDirection);

        rg_multidmg_clear();
        ExecuteHamB(Ham_TraceAttack, pTarget, this, flDamage, vecDirection, g_pTrace, DMG_GENERIC);
        rg_multidmg_apply(this, this);

        bHit = IS_PLAYER(pTarget) || UTIL_IsMonster(pTarget);
    }

    return bHit;
}

@Entity_MoveTo(this, const Float:vecTarget[3]) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);
    static Float:flLastThink; pev(this, pev_ltime, flLastThink);
    static Float:flDelta; flDelta = flGameTime - flLastThink;
    static Float:flMaxAngle; flMaxAngle = 180.0 * floatmin(flDelta, 0.1);
    static bool:rgbLockAxis[3]; rgbLockAxis = bool:{true, false, true};

    static iMoveType; iMoveType = pev(this, pev_movetype);
    if (iMoveType == MOVETYPE_FLY || iMoveType == MOVETYPE_NOCLIP) {
        rgbLockAxis[0] = false;
    }

    UTIL_TurnTo(this, vecTarget, rgbLockAxis, flMaxAngle);

    if (CE_CallMethod(this, IsInViewCone, vecTarget)) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

        if (flMaxSpeed > 0.0 && get_distance_f(vecOrigin, vecTarget) > 1.0) {
            CE_CallMethod(this, MoveForward);
        }
    }
}

@Entity_EmitVoice(this, const szSound[], Float:flDuration) {
    emit_sound(this, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_UpdateEnemy(this) {
    static Float:flViewRange; flViewRange = CE_GetMember(this, m_flViewRange);
    if (@Entity_FindEnemy(this, flViewRange, 0.0, false, true, true)) {
        return true;
    }

    static Float:flFindRange; flFindRange = CE_GetMember(this, m_flFindRange);
    if (@Entity_FindEnemy(this, flFindRange, 0.0, false, false, false)) {
        return true;
    }

    return false;
}

@Entity_UpdateGoal(this) {
    CE_DeleteMember(this, m_vecGoal);

    new pEnemy = CE_CallMethod(this, GetEnemy);

    if (CE_CallMethod(this, UpdateEnemy)) {
        pEnemy = pev(this, pev_enemy);
    }

    if (pEnemy) {
        static Float:vecGoal[3]; pev(pEnemy, pev_origin, vecGoal);
        CE_SetMemberVec(this, m_vecGoal, vecGoal);
    }
}

@Entity_UpdateTarget(this) {
    CE_CallMethod(this, ProcessTarget);
    CE_CallMethod(this, ProcessPath);
    CE_CallMethod(this, ProcessGoal);
}

@Entity_ProcessTarget(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (CE_HasMember(this, m_vecTarget)) {
        static Float:flArrivalTime; flArrivalTime = CE_GetMember(this, m_flTargetArrivalTime);
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        static Float:vecMins[3]; pev(this, pev_mins, vecMins);
        static Float:vecTarget[3]; CE_GetMemberVec(this, m_vecTarget, vecTarget);
    
        new bool:bHasReached = xs_vec_distance_2d(vecOrigin, vecTarget) < 10.0;
        if (bHasReached || flGameTime > flArrivalTime) {
            CE_DeleteMember(this, m_vecTarget);
        }
    }
}

@Entity_ProcessGoal(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3]; CE_GetMemberVec(this, m_vecGoal, vecGoal);

        if (!CE_CallMethod(this, IsReachable, vecGoal, pev(this, pev_enemy), 32.0)) {
            if (get_pcvar_bool(g_pCvarUseAstar)) {
                if (CE_GetMember(this, m_flNextPathSearch) <= flGameTime) {
                    CE_CallMethod(this, FindPath, vecGoal);
                    CE_SetMember(this, m_flNextPathSearch, flGameTime + NPC_PathSearchDelay);
                    CE_DeleteMember(this, m_vecTarget);
                }
            } else {
                CE_DeleteMember(this, m_vecGoal);
                CE_DeleteMember(this, m_vecTarget);
            }
        } else {
            CE_DeleteMember(this, m_vecGoal);
            CE_CallMethod(this, SetTarget, vecGoal);
        }
    }
}


@Entity_SetTarget(this, const Float:vecTarget[3]) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);
    static Float:flDuration; flDuration = xs_vec_distance(vecOrigin, vecTarget) / flMaxSpeed;

    CE_SetMemberVec(this, m_vecTarget, vecTarget);
    CE_SetMember(this, m_flTargetArrivalTime, get_gametime() + flDuration);
}

@Entity_PlayAction(this, iStartSequence, iEndSequence, Float:flDuration, bSupercede) {
    new Float:flGametime = get_gametime();
    if (!bSupercede && flGametime < CE_GetMember(this, m_flNextAction)) {
        return false;
    }

    new iSequence = random_num(iStartSequence, iEndSequence);

    if (!UTIL_SetSequence(this, iSequence)) {
        return false;
    }

    CE_SetMember(this, m_flNextAction, flGametime + flDuration);

    return true;
}

Action:@Entity_GetAction(this) {
    new Action:iAction = Action_Idle;

    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (CE_GetMember(this, m_flReleaseAttack) > 0.0) {
                iAction = Action_Attack;
            }

            static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

            if (xs_vec_len_2d(vecVelocity) > 10.0) {
                iAction = iAction == Action_Attack ? Action_RunAttack : Action_Run;
            }
        }
    }

    return iAction;
}

@Entity_FindPath(this, Float:vecTarget[3]) {
    CE_CallMethod(this, ResetPath);

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

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
    if (CE_HasMember(this, m_vecTarget)) return true;

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    if (!ArraySize(irgPath)) {
        // set_pev(this, pev_enemy, 0);
        return false;
    }
    
    static Float:vecMins[3]; pev(this, pev_mins, vecMins);

    static Float:vecTarget[3];
    ArrayGetArray(irgPath, 0, vecTarget);
    ArrayDeleteItem(irgPath, 0);
    vecTarget[2] -= vecMins[2];

    CE_CallMethod(this, SetTarget, vecTarget);

    return true;
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


@Entity_GetEnemy(this) {
    new pEnemy = pev(this, pev_enemy);

    if (!CE_CallMethod(this, IsValidEnemy, pEnemy)) {
        pEnemy = 0;
    }

    return pEnemy;
}

bool:@Entity_IsValidEnemy(this, pEnemy) {
    if (!pEnemy || !pev_valid(pEnemy)) return false;

    new iTeam = pev(this, pev_team);

    new iEnemyTeam = 0;
    if (IS_PLAYER(pEnemy)) {
        if (!is_user_alive(pEnemy)) return false;

        iEnemyTeam = get_ent_data(pEnemy, "CBasePlayer", "m_iTeam");
    } else if (UTIL_IsMonster(pEnemy)) {
        iEnemyTeam = pev(pEnemy, pev_team);
    } else {
        return false;
    }

    if (iTeam == iEnemyTeam) return false;
    if (pev(pEnemy, pev_takedamage) == DAMAGE_NO) return false;
    if (pev(pEnemy, pev_solid) < SOLID_BBOX) return false;
    if (UTIL_IsInvisible(pEnemy)) return false;

    return true;
}

@Entity_FindEnemy(this, Float:flMaxDistance, Float:flMinPriority, bool:bVisibleOnly, bool:bReachableOnly, bool:bAllowMonsters) {
    new pEnemy = pev(this, pev_enemy);
    if (!CE_CallMethod(this, IsValidEnemy, pEnemy)) {
        set_pev(this, pev_enemy, 0);
    }

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static pClosestTarget; pClosestTarget = 0;
    static Float:flClosestTargetPriority; flClosestTargetPriority = 0.0;

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, flMaxDistance)) > 0) {
        if (this == pTarget) continue;

        if (!CE_CallMethod(this, IsValidEnemy, pTarget)) continue;

        static Float:vecTarget[3]; pev(pTarget, pev_origin, vecTarget);

        if (bVisibleOnly && !CE_CallMethod(this, IsVisible, vecTarget, pTarget)) continue;

        static Float:flDistance; flDistance = xs_vec_distance(vecOrigin, vecTarget);
        static Float:flTargetPriority; flTargetPriority = 1.0 - (flDistance / flMaxDistance);

        if (IS_PLAYER(pTarget)) {
            flTargetPriority *= 1.0;
        } else if (bAllowMonsters && UTIL_IsMonster(pTarget)) {
            flTargetPriority *= 0.075;
        } else {
            flTargetPriority *= 0.0;
        }

        if (flTargetPriority >= flMinPriority && bReachableOnly && !CE_CallMethod(this, IsReachable, vecTarget, pTarget)) {
            flTargetPriority *= 0.1;
        }

        if (flTargetPriority >= flMinPriority && flTargetPriority > flClosestTargetPriority) {
            pClosestTarget = pTarget;
            flClosestTargetPriority = flTargetPriority;
        }
    }

    if (pClosestTarget) {
        set_pev(this, pev_enemy, pClosestTarget);
    }

    return pClosestTarget;
}

bool:@Entity_IsVisible(this, const Float:vecTarget[3], pIgnoreEnt) {
    static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, this, vecOrigin);

    static iIgnoreEntSolidType; iIgnoreEntSolidType = SOLID_NOT;
    if (pIgnoreEnt) {
        iIgnoreEntSolidType = pev(pIgnoreEnt, pev_solid);
        set_pev(pIgnoreEnt, pev_solid, SOLID_NOT);
    }

    static bool:bIsOpen; bIsOpen = UTIL_IsOpen(vecOrigin, vecTarget, this);

    if (pIgnoreEnt) {
        set_pev(pIgnoreEnt, pev_solid, iIgnoreEntSolidType);
    }

    return bIsOpen;
}

bool:@Entity_IsReachable(this, const Float:vecTarget[3], pIgnoreEnt, Float:flStepLength) {    
    if ((~pev(this, pev_flags) & FL_ONGROUND) && pev(this, pev_movetype) != MOVETYPE_FLY) {
        return false;
    }

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Float:_vecTarget[3];
    xs_vec_copy(vecTarget, _vecTarget);
    if (_vecTarget[2] < vecOrigin[2]) {
        _vecTarget[2] = vecOrigin[2];
    }

    new iIgnoreEntSolidType = SOLID_NOT;
    if (pIgnoreEnt) {
        iIgnoreEntSolidType = pev(pIgnoreEnt, pev_solid);
        set_pev(pIgnoreEnt, pev_solid, SOLID_NOT);
    }

    new bool:bIsReachable = true;

    if (bIsReachable) {
        bIsReachable = UTIL_IsOpen(vecOrigin, _vecTarget, this);
    }

    if (bIsReachable) {
        static Float:vecMins[3];
        pev(this, pev_mins, vecMins);

        static Float:vecLeftSide[3];
        vecLeftSide[0] = vecOrigin[0] + vecMins[0];
        vecLeftSide[1] = vecOrigin[1] + vecMins[1];
        vecLeftSide[2] = vecOrigin[2];

        static Float:vecTargetLeftSide[3];
        vecTargetLeftSide[0] = _vecTarget[0] + vecMins[0];
        vecTargetLeftSide[1] = _vecTarget[1] + vecMins[1];
        vecTargetLeftSide[2] = _vecTarget[2];

        bIsReachable = UTIL_IsOpen(vecLeftSide, vecTargetLeftSide, this);
    }

    if (bIsReachable) {
        static Float:vecMaxs[3];
        pev(this, pev_maxs, vecMaxs);

        static Float:vecRightSide[3];
        vecRightSide[0] = vecOrigin[0] + vecMaxs[0];
        vecRightSide[1] = vecOrigin[1] + vecMaxs[1];
        vecRightSide[2] = vecOrigin[2];

        static Float:vecTargetRightSide[3];
        vecTargetRightSide[0] = _vecTarget[0] + vecMaxs[0];
        vecTargetRightSide[1] = _vecTarget[1] + vecMaxs[1];
        vecTargetRightSide[2] = _vecTarget[2];

        bIsReachable = UTIL_IsOpen(vecRightSide, vecTargetRightSide, this);
    }

    if (pev(this, pev_movetype) != MOVETYPE_FLY) {
        static Float:vecStepOrigin[3];

        if (bIsReachable) {
            new Float:flDistance = get_distance_f(vecOrigin, _vecTarget);
            new iStepsNum = floatround(flDistance / flStepLength);

            if (iStepsNum) {
                //Get direction vector
                static Float:vecStep[3];
                xs_vec_sub(_vecTarget, vecOrigin, vecStep);
                
                bIsReachable = @Entity_TestStep(this, vecOrigin, vecStep, vecStepOrigin);

                if (bIsReachable) {
                    xs_vec_normalize(vecStep, vecStep);
                    xs_vec_mul_scalar(vecStep, flStepLength, vecStep);

                    xs_vec_copy(vecOrigin, vecStepOrigin);

                    for (new iStep = 0; iStep < iStepsNum; ++iStep) {
                        // UTIL_DrawArrow(0, vecStep, vecStepOrigin, {0, 255, 0}, _, _, 16);
                        if (!@Entity_TestStep(this, vecStepOrigin, vecStep, vecStepOrigin)) {
                            bIsReachable = false;
                            break;
                        }
                    }
                }
            }
        }

        if (bIsReachable) {
            bIsReachable = (vecTarget[2] - vecStepOrigin[2]) < 72.0;
        }
    }


    if (pIgnoreEnt) {
        set_pev(pIgnoreEnt, pev_solid, iIgnoreEntSolidType);
    }

    return bIsReachable;
}

// TODO: return final step origin
bool:@Entity_TestStep(this, const Float:vecOrigin[3], const Float:vecStep[3], Float:vecStepOrigin[3]) {
    static Float:vecMins[3]; pev(this, pev_mins, vecMins);
    
    static Float:_vecStepOrigin[3];
    xs_vec_copy(vecStepOrigin, _vecStepOrigin);
    xs_vec_add(vecOrigin, vecStep, _vecStepOrigin);

    // check wall
    static Float:vecStepStart[3];
    xs_vec_copy(vecOrigin, vecStepStart);
    vecStepStart[2] += vecMins[2] + STEP_HEIGHT;

    static Float:vecStepEnd[3];
    xs_vec_copy(_vecStepOrigin, vecStepEnd);
    vecStepEnd[2] += vecMins[2] + STEP_HEIGHT;

    if (!UTIL_IsOpen(vecStepStart, vecStepEnd, this)) {
        return false;
    }

    _vecStepOrigin[2] += STEP_HEIGHT; // add height to the step

    new Float:flDistanceToFloor = UTIL_GetDistanceToFloor(this, _vecStepOrigin);
    if (flDistanceToFloor < 0.0) { // check if falling or solid
        static Float:vecEnd[3];
        xs_vec_copy(_vecStepOrigin, vecEnd);
        vecEnd[2] -= -vecMins[2] + STEP_HEIGHT;
        return false;
    }

    if (flDistanceToFloor >= STEP_HEIGHT) { // subtract step height if not needed
        flDistanceToFloor -= STEP_HEIGHT;
        _vecStepOrigin[2] -= STEP_HEIGHT;
    }

    _vecStepOrigin[2] -= flDistanceToFloor; // apply possible height change

    xs_vec_copy(_vecStepOrigin, vecStepOrigin); // copy result

    return true;
}

@Entity_MoveForward(this) {
    static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);
    static iMoveType; iMoveType = pev(this, pev_movetype);
    static bool:bIsFlying; bIsFlying = (iMoveType == MOVETYPE_FLY || iMoveType == MOVETYPE_NOCLIP);

    set_pev(this, pev_speed, flMaxSpeed);

    static Float:vecDirection[3];
    UTIL_GetDirectionVector(this, vecDirection);

    if (!bIsFlying) {
        vecDirection[2] = 0.0;
        xs_vec_normalize(vecDirection, vecDirection);
    }

    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

    vecVelocity[0] = vecDirection[0] * flMaxSpeed;
    vecVelocity[1] = vecDirection[1] * flMaxSpeed;

    if (bIsFlying) {
        vecVelocity[2] = vecDirection[2] * flMaxSpeed;
    }

    static Float:vecAngles[3]; pev(this, pev_angles, vecAngles);

    set_pev(this, pev_ideal_yaw, vecAngles[1]);

    if (!bIsFlying) {
        engfunc(EngFunc_WalkMove, this, vecAngles[1], 0.5, WALKMOVE_NORMAL);
    }

    set_pev(this, pev_velocity, vecVelocity);
}

@Entity_StopMovement(this) {
    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

    vecVelocity[0] = 0.0;
    vecVelocity[1] = 0.0;

    set_pev(this, pev_velocity, vecVelocity);
}

bool:@Entity_IsInViewCone(this, const Float:vecTarget[3]) {
    static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, this, vecOrigin);
    static Float:flFOV; pev(this, pev_fov, flFOV);

    static Float:vecDir[3];
    xs_vec_sub(vecTarget, vecOrigin, vecDir);
    xs_vec_normalize(vecDir, vecDir);

    static Float:vecForward[3];
    pev(this, pev_v_angle, vecForward);
    angle_vector(vecForward, ANGLEVECTOR_FORWARD, vecForward);

    // static Float:flAngle; flAngle = xs_vec_dot(vecDir, vecForward);
    static Float:flAngle; flAngle = xs_rad2deg(xs_acos((vecDir[0] * vecForward[0]) + (vecDir[1] * vecForward[1]), radian));

    return flAngle <= (flFOV / 2);
}

Float:@Entity_GetPathCost(this, NavArea:newArea, NavArea:prevArea) {
    new NavAttributeType:iAttributes = Nav_Area_GetAttributes(newArea);

    // NPC can't jump or crouch
    if (iAttributes & NAV_JUMP || iAttributes & NAV_CROUCH) return -1.0;

    static Float:vecTarget[3]; Nav_Area_GetCenter(newArea, vecTarget);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Float:vecSrc[3];
    if (prevArea != Invalid_NavArea) {
        Nav_Area_GetCenter(prevArea, vecSrc);
    } else {
        xs_vec_copy(vecOrigin, vecSrc);
    }

    engfunc(EngFunc_TraceLine, vecSrc, vecTarget, IGNORE_MONSTERS, 0, g_pTrace);
    new pHit = get_tr2(g_pTrace, TR_pHit);

    // cancel if there is a wall
    if (!pHit) return -1.0;

    // cancel path if there is a obstacle
    if (pHit != -1 && !IS_PLAYER(pHit) && !UTIL_IsMonster(pHit)) return -1.0;

    // don't go through spawn area, path cost penalty for going through the spawn area in case we already in the spawn area
    new iSpawnAreaTeam = Hwn_Gamemode_GetSpawnAreaTeam(vecTarget);
    if (iSpawnAreaTeam) {
        return iSpawnAreaTeam == Hwn_Gamemode_GetSpawnAreaTeam(vecOrigin) ? 100.0 : -1.0;
    }

    new pTarget = 0;
    while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecTarget, 4.0)) > 0) {
        static szClassName[32]; pev(pTarget, pev_classname, szClassName, charsmax(szClassName));

        // don't go through the hurt entities
        if (equal(szClassName, "trigger_hurt")) return -1.0;
    }

    return 1.0;
}


/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (CE_IsInstanceOf(pEntity, ENTITY_NAME)) {
        CE_CallMethod(pEntity, TakeDamage, pInflictor, pAttacker, flDamage, iDamageBits);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public Float:NavPathCost(NavBuildPathTask:pTask, NavArea:newArea, NavArea:prevArea) {
    static pEntity; pEntity = Nav_Path_FindTask_GetUserToken(pTask);
    if (!pEntity) {
        return 1.0;
    }
    
    return CE_CallMethod(pEntity, GetPathCost, newArea, prevArea);
}

public NavPathCallback(NavBuildPathTask:pTask) {
    new pEntity = Nav_Path_FindTask_GetUserToken(pTask);
    new NavPath:pPath = Nav_Path_FindTask_GetPath(pTask);

    return CE_CallMethod(pEntity, HandlePath, pPath);
}
