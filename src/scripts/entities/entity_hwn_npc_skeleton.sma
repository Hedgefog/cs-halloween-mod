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

#define PLUGIN "[Custom Entity] Hwn NPC Skeleton"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_skeleton"
#define ENTITY_NAME_SMALL "hwn_npc_skeleton_small"

#define SKELETON_EGG_ENTITY_NAME "hwn_skeleton_egg"
#define SKELETON_EGG_COUNT 2

#define m_irgPath "irgPath"
#define m_vecGoal "vecGoal"
#define m_vecTarget "vecTarget"
#define m_pBuildPathTask "pBuildPathTask"
#define m_flReleaseHit "flReleaseHit"
#define m_flTargetArrivalTime "flTargetArrivalTime"
#define m_flNextAIThink "flNextAIThink"
#define m_flNextAttack "flNextAttack"
#define m_flNextPathSearch "flNextPathSearch"
#define m_flNextLaugh "flNextLaugh"
#define m_flDieTime "flDieTime"
#define m_bSmall "bSmall"

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

const Float:NPC_Health = 100.0;
const Float:NPC_Speed = 230.0;
const Float:NPC_Damage = 24.0;
const Float:NPC_HitRange = 48.0;
const Float:NPC_HitDelay = 0.35;
const Float:NPC_LifeTime = 30.0;
const Float:NPC_RespawnTime = 15.0;
const Float:NPC_ViewRange = 4096.0;
const Float:NPC_PathSearchDelay = 5.0;
const Float:NPC_TargetUpdateRate = 1.0;

const Float:NPC_Small_Health = 50.0;
const Float:NPC_Small_Speed = 250.0;
const Float:NPC_Small_Damage = 12.0;
const Float:NPC_Small_HitRange = 48.0;
const Float:NPC_Small_HitDelay = 0.35;

new const Float:NPC_TargetHitOffset[3] = {0.0, 0.0, 16.0};

new const g_szSndLaugh[][] = {
    "hwn/npc/skeleton/skelly_medium_01.wav",
    "hwn/npc/skeleton/skelly_medium_02.wav",
    "hwn/npc/skeleton/skelly_medium_03.wav",
    "hwn/npc/skeleton/skelly_medium_04.wav",
    "hwn/npc/skeleton/skelly_medium_05.wav"
};

new const g_szSndSmallLaugh[][] = {
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

new g_pCvarUseAstar;

new g_iGibsModelIndex;

new g_iBloodModelIndex;
new g_iBloodSprayModelIndex;

new g_iCeHandler;
new g_ceHandlerSmall;

public plugin_precache() {
    g_iBloodModelIndex = precache_model("sprites/blood.spr");
    g_iBloodSprayModelIndex = precache_model("sprites/bloodspray.spr");
    g_iGibsModelIndex = precache_model("models/bonegibs.mdl");

    precache_sound(g_szSndBreak);

    for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
        precache_sound(g_szSndLaugh[i]);
    }

    for (new i = 0; i < sizeof(g_szSndSmallLaugh); ++i) {
        precache_sound(g_szSndSmallLaugh[i]);
    }

    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/skeleton_v2.mdl"),
        .vMins = Float:{-12.0, -12.0, -32.0},
        .vMaxs = Float:{12.0, 12.0, 32.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Restart, ENTITY_NAME, "@Entity_Restart");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    g_ceHandlerSmall = CE_Register(
        ENTITY_NAME_SMALL,
        .modelIndex = precache_model("models/hwn/npc/skeleton_small_v3.mdl"),
        .vMins = Float:{-8.0, -8.0, -16.0},
        .vMaxs = Float:{8.0, 8.0, 16.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Init, ENTITY_NAME_SMALL, "@Entity_Init");
    CE_RegisterHook(CEFunction_Restart, ENTITY_NAME_SMALL, "@Entity_Restart");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_SMALL, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_SMALL, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME_SMALL, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME_SMALL, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME_SMALL, "@Entity_Think");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    g_pCvarUseAstar = register_cvar("hwn_npc_skeleton_use_astar", "1");
}

/*--------------------------------[ Hooks ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
    CE_SetMember(this, m_irgPath, ArrayCreate(3));

    NPC_Create(this);
}

@Entity_Restart(this) {
    @Entity_ResetPath(this);
}

@Entity_Spawn(this) {
    new Float:flGameTime = get_gametime();

    new bool:bSmall = CE_GetHandlerByEntity(this) == CE_GetHandler(ENTITY_NAME_SMALL);

    CE_SetMember(this, m_bSmall, bSmall);
    CE_SetMember(this, m_flNextAttack, 0.0);
    CE_SetMember(this, m_flReleaseHit, 0.0);
    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_flNextLaugh, flGameTime);
    CE_SetMember(this, m_flNextPathSearch, flGameTime);
    CE_SetMember(this, m_flTargetArrivalTime, 0.0);
    CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);

    set_pev(this, pev_groupinfo, 128);
    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, Float:{0.0, 0.0, 0.0});
    set_pev(this, pev_health, bSmall ? NPC_Small_Health : NPC_Health);
    set_pev(this, pev_takedamage, DAMAGE_AIM);
    set_pev(this, pev_view_ofs, Flaot:{0.0, 0.0, 32.0});
    set_pev(this, pev_maxspeed, bSmall ? NPC_Small_Speed : NPC_Speed);
    set_pev(this, pev_dmg, bSmall ? NPC_Small_Damage : NPC_Damage);
    set_pev(this, pev_enemy, 0);

    engfunc(EngFunc_DropToFloor, this);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, bSmall ? 8 : 16, {HWN_COLOR_SECONDARY}, 20, 8);

    @Entity_PlayAction(this, Action_Spawn, false);
    @Entity_UpdateColor(this);
    // CE_SetMember(this, "flNextUpdate", get_gametime() + g_actions[Action_Spawn][NPC_Action_Time]);

    set_pev(this, pev_nextthink, flGameTime + g_actions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Kill(this) {
    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            NPC_StopMovement(this);

            set_pev(this, pev_takedamage, DAMAGE_NO);
            set_pev(this, pev_deadflag, DEAD_DYING);

            CE_SetMember(this, m_flNextAIThink, get_gametime() + 0.1);
            CE_SetMember(this, m_flDieTime, get_gametime() + 0.1);

            // cancel first kill function to play duing animation
            return PLUGIN_HANDLED;
        }
        case DEAD_DYING: {
            set_pev(this, pev_deadflag, DEAD_DEAD);
            return PLUGIN_CONTINUE;
        }
    }

    return PLUGIN_HANDLED;
}

@Entity_Killed(this) {
    @Entity_ResetPath(this);

    new bool:bSmall = CE_GetMember(this, m_bSmall);
    if (!bSmall) {
        @Entity_SpawnEggs(this);
    }

    @Entity_DisappearEffect(this);
}

@Entity_Remove(this) {
    @Entity_ResetPath(this);

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    ArrayDestroy(irgPath);

    NPC_Destroy(this);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 10, 32);
}

@Entity_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (IS_PLAYER(pAttacker) && NPC_IsValidEnemy(pAttacker)) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        static Float:vecTarget[3];
        pev(pAttacker, pev_origin, vecTarget);

        new bool:bSmall = CE_GetMember(this, m_bSmall);    
        new Float:flHitRange = bSmall ? NPC_Small_HitRange : NPC_HitRange;

        if (get_distance_f(vecOrigin, vecTarget) <= flHitRange && NPC_IsVisible(this, vecTarget)) {
            if (get_gametime() - NPC_GetEnemyTime(this) > 6.0) {
                NPC_SetEnemy(this, pAttacker);
            }
        }
    }
}

@Entity_TraceAttack(this, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    static Float:vecEnd[3];
    get_tr2(pTrace, TR_vecEndPos, vecEnd);

    UTIL_Message_BloodSprite(vecEnd, g_iBloodSprayModelIndex, g_iBloodModelIndex, 242, floatround(flDamage / 4));
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

                static Float:flMaxSpeed;
                pev(this, pev_maxspeed, flMaxSpeed);
                NPC_MoveToTarget(this, vecTarget, flMaxSpeed);
            }
        }
        case DEAD_DYING: {
            new Float:flDieTime = CE_GetMember(this, m_flDieTime);
            if (flDieTime <= flGameTime) {
                CE_Kill(this);
            }
        }
    }

    // animations update based on NPC activity
    if (bShouldUpdateAI) {
        new Action:iAction = @Entity_GetAction(this);
        @Entity_PlayAction(this, iAction, false);
    }

    set_pev(this, pev_ltime, flGameTime);
    set_pev(this, pev_nextthink, flGameTime + 0.01);

    return HAM_HANDLED;
}

@Entity_AIThink(this) {
    new bool:bSmall = CE_GetMember(this, m_bSmall);

    static Float:flLastThink;
    pev(this, pev_ltime, flLastThink);

    static Float:flGameTime; flGameTime = get_gametime();
    // new Float:flRate = Hwn_GetNpcUpdateRate();
    // new Float:flDelta = flGameTime - flLastThink;

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    new Float:flHitRange = bSmall ? NPC_Small_HitRange : NPC_HitRange;
    new Float:flHitDelay = bSmall ? NPC_Small_HitDelay : NPC_HitDelay;

    static Float:flReleaseHit; flReleaseHit = CE_GetMember(this, m_flReleaseHit);
    if (!flReleaseHit) {
        static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
        if (flNextAttack <= get_gametime()) {
            static pEnemy; pEnemy = NPC_GetEnemy(this);
            if (pEnemy && NPC_CanHit(this, pEnemy, flHitRange, NPC_TargetHitOffset)) {
                CE_SetMember(this, m_flReleaseHit, flGameTime + flHitDelay);

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

        NPC_Hit(this, NPC_Damage, flHitRange, 0.0, NPC_TargetHitOffset);

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
            if (bSmall) {
                NPC_EmitVoice(this, g_szSndSmallLaugh[random(sizeof(g_szSndSmallLaugh))], 2.0);
            } else {
                NPC_EmitVoice(this, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
            }

            CE_SetMember(this, m_flNextLaugh, flGameTime + random_float(1.0, 2.0));
        }
    }

    static Action:iAction; iAction = @Entity_GetAction(this);
    @Entity_PlayAction(this, iAction, false);
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
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static iTeam; iTeam = pev(this, pev_team);
    static pClosestTarget; pClosestTarget = 0;
    static Float:flClosestTargetPriority; flClosestTargetPriority = 0.0;

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, flMaxDistance)) > 0) {
        if (this == pTarget) {
            continue;
        }

        if (!NPC_IsValidEnemy(pTarget, iTeam)) {
            continue;
        }

        static Float:vecTarget[3];
        pev(pTarget, pev_origin, vecTarget);

        static Float:flDistance; flDistance = xs_vec_distance(vecOrigin, vecTarget);
        static Float:flTargetPriority; flTargetPriority = 1.0 - (flDistance / flMaxDistance);

        if (IS_PLAYER(pTarget)) {
            flTargetPriority *= 1.0;
        } else if (UTIL_IsMonster(pTarget)) {
            flTargetPriority *= 0.075;
        } else {
            flTargetPriority *= 0.0;
        }

        if (flTargetPriority >= flMinPriority && !NPC_IsReachable(this, vecTarget, pTarget)) {
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

@Entity_PlayAction(this, Action:iAction, bool:bSupercede) {
    NPC_PlayAction(this, g_actions[iAction], bSupercede);
    // CE_SetMember(this, "flNextUpdate", get_gametime() + g_actions[iAction][NPC_Action_Time]);
}

Action:@Entity_GetAction(this) {
    new Action:iAction = Action_Idle;

    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (CE_GetMember(this, m_flReleaseHit) > 0.0) {
                iAction = Action_Attack;
            }

            if (pev(this, pev_flags) | FL_ONGROUND) {
                static Float:vecVelocity[3];
                pev(this, pev_velocity, vecVelocity);

                if (xs_vec_len(vecVelocity) > 10.0) {
                    iAction = iAction == Action_Attack ? Action_RunAttack : Action_Run;
                }
            }
        }
    }

    return iAction;
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
    new NavAttributeType:iAttributes = Nav_Area_GetAttributes(newArea);

    // NPC can't jump or crouch
    if (iAttributes & NAV_JUMP || iAttributes & NAV_CROUCH) {
        return -1.0;
    }

    static Float:vecTarget[3];
    Nav_Area_GetCenter(newArea, vecTarget);

    static Float:vecSrc[3];
    if (prevArea != Invalid_NavArea) {
        Nav_Area_GetCenter(prevArea, vecSrc);
    } else {
        pev(this, pev_origin, vecSrc);
    }

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecSrc, vecTarget, IGNORE_MONSTERS, 0, pTrace);
    new pHit = get_tr2(pTrace, TR_pHit);
    free_tr2(pTrace);

    // cancel if there is a wall
    if (!pHit) {
        return -1.0;
    }

    // cancel path if there is a obstacle
    if (pHit != -1 && !IS_PLAYER(pHit) && !UTIL_IsMonster(pHit)) {
        return -1.0;
    }

    new pTarget = 0;
    while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecTarget, 64.0)) > 0) {
        static szClassName[32];
        pev(pTarget, pev_classname, szClassName, charsmax(szClassName));

        // don't go through the hurt entities
        if (equal(szClassName, "trigger_hurt")) {
            return -1.0;
        }

        // path cost penalty for going through the spawn area
        if (equal(szClassName, "info_player_start") || equal(szClassName, "info_player_deathmatch")) {
            return 100.0;
        }
    }

    return 1.0;
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


@Entity_UpdateColor(this) {
    new iTeam = pev(this, pev_team);

    switch (iTeam) {
        case 0: set_pev(this, pev_rendercolor, {HWN_COLOR_SECONDARY_F});
        case 1: set_pev(this, pev_rendercolor, {HWN_COLOR_RED_F});
        case 2: set_pev(this, pev_rendercolor, {HWN_COLOR_BLUE_F});
    }
}

@Entity_DisappearEffect(this) {
    new bool:bSmall = CE_GetMember(this, m_bSmall);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new Float:vecVelocity[3];
    UTIL_RandomVector(-48.0, 48.0, vecVelocity);

    UTIL_Message_Dlight(vecOrigin, bSmall ? 8 : 16, {HWN_COLOR_SECONDARY}, 10, 32);
    UTIL_Message_BreakModel(vecOrigin, Float:{16.0, 16.0, 16.0}, vecVelocity, 10, g_iGibsModelIndex, 5, 25, 0);

    emit_sound(this, CHAN_BODY, g_szSndBreak, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_SpawnEggs(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    for (new i = 0; i < SKELETON_EGG_COUNT; ++i) {
        new pEgg = CE_Create(SKELETON_EGG_ENTITY_NAME, vecOrigin);
        if (!pEgg) {
            continue;
        }

        set_pev(pEgg, pev_team, pev(this, pev_team));
        set_pev(pEgg, pev_owner, pev(this, pev_owner));
        dllfunc(DLLFunc_Spawn, pEgg);

        new Float:vecVelocity[3];
        xs_vec_set(vecVelocity, random_float(-96.0, 96.0), random_float(-96.0, 96.0), 128.0);
        set_pev(pEgg, pev_velocity, vecVelocity);
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler == CE_GetHandlerByEntity(pEntity)) {
        @Entity_TraceAttack(pEntity, pAttacker, flDamage, vecDirection, pTrace, iDamageBits);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (g_iCeHandler == CE_GetHandlerByEntity(pEntity)) {
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
