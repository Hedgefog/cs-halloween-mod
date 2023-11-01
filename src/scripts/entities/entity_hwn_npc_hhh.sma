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

#define PLUGIN "[Custom Entity] Hwn NPC HHH"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_hhh"

#define m_flDamage "flDamage"
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
#define m_flNextEffectEmit "flNextEffectEmit"
#define m_flNextSmokeEmit "flNextSmokeEmit"
#define m_flNextLaugh "flNextLaugh"
#define m_flNextFootStep "flNextFootStep"
#define m_pKiller "pKiller"

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

new const g_rgActions[Action][NPC_Action] = {
    { Sequence_Idle, Sequence_Idle, 0.0 },
    { Sequence_Run, Sequence_Run, 0.0 },
    { Sequence_Attack, Sequence_Attack, 0.75 },
    { Sequence_RunAttack, Sequence_RunAttack, 0.75 },
    { Sequence_Shake, Sequence_Shake, 2.0 },
    { Sequence_Spawn, Sequence_Spawn, 6.0 }
};

const Float:NPC_Health = 4000.0;
const Float:NPC_HealthBonusPerPlayer = 300.0;
const Float:NPC_Speed = 300.0;
const Float:NPC_Damage = 160.0;
const Float:NPC_HitRange = 96.0;
const Float:NPC_HitDelay = 0.75;
const Float:NPC_PathSearchDelay = 5.0;
const Float:NPC_TargetUpdateRate = 1.0;
const Float:NPC_ViewRange = 512.0;
const Float:NPC_FindRange = 4096.0;
new const Float:NPC_TargetHitOffset[3] = {0.0, 0.0, 16.0};

new gmsgScreenShake;

new g_iSmokeModelIndex;
new g_iGibsModelIndex;

new g_iCeHandler;
new g_iBossHandler;

new g_pCvarUseAstar;

new Float:g_flStartHealth = NPC_Health;

public plugin_precache() {
    Nav_Precache();

    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke_tiny.spr");
    g_iGibsModelIndex = precache_model("models/hwn/npc/headless_hatman_gibs.mdl");

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

    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/npc/headless_hatman.mdl",
        .vecMins = Float:{-16.0, -16.0, -48.0},
        .vecMaxs = Float:{16.0, 16.0, 48.0},
        .iPreset = CEPreset_NPC,
        .iBloodColor = 212
    );

    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Restart, ENTITY_NAME, "@Entity_Restart");
    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    g_iBossHandler = Hwn_Bosses_Register(ENTITY_NAME, "Horseless Headless Horsemann");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    g_pCvarUseAstar = register_cvar("hwn_npc_hhh_use_astar", "1");

    gmsgScreenShake = get_user_msgid("ScreenShake");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver() {
    g_flStartHealth += NPC_HealthBonusPerPlayer;
}

public client_disconnected(pPlayer) {
    g_flStartHealth -= NPC_HealthBonusPerPlayer;
}

public Hwn_Bosses_Fw_BossTeleport(pEntity, iBoss) {
    if (iBoss != g_iBossHandler) {
        return;
    }

    @Entity_ResetPath(pEntity);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMember(this, m_pBuildPathTask, Invalid_NavBuildPathTask);
    CE_SetMember(this, m_irgPath, ArrayCreate(3));
}

@Entity_Restart(this) {
    @Entity_ResetPath(this);
}

@Entity_Spawned(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flDamage, NPC_Damage);
    CE_SetMember(this, m_flNextAttack, 0.0);
    CE_SetMember(this, m_flReleaseHit, 0.0);
    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_flNextAction, flGameTime);
    CE_SetMember(this, m_flNextLaugh, flGameTime);
    CE_SetMember(this, m_flNextPathSearch, flGameTime);
    CE_SetMember(this, m_flNextFootStep, flGameTime);
    CE_SetMember(this, m_flNextEffectEmit, flGameTime);
    CE_SetMember(this, m_flNextSmokeEmit, flGameTime);
    CE_SetMember(this, m_flTargetArrivalTime, 0.0);
    CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
    CE_SetMember(this, m_pKiller, 0);

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        flRenderColor[i] *= 0.2;
    }

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, flRenderColor);
    set_pev(this, pev_team, 666);
    set_pev(this, pev_health, g_flStartHealth);
    set_pev(this, pev_takedamage, DAMAGE_NO);
    set_pev(this, pev_view_ofs, Flaot:{0.0, 0.0, 32.0});
    set_pev(this, pev_maxspeed, NPC_Speed);
    set_pev(this, pev_enemy, 0);

    engfunc(EngFunc_DropToFloor, this);

    @Entity_EmitVoice(this, g_szSndSpawn, 1.0);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    @Entity_PlayAction(this, Action_Spawn, false);

    set_pev(this, pev_nextthink, flGameTime + g_rgActions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Kill(this, pKiller) {
    new Float:flGameTime = get_gametime();

    new iDeadFlag = pev(this, pev_deadflag);

    CE_SetMember(this, m_pKiller, pKiller);

    if (pKiller && iDeadFlag == DEAD_NO) {
        @Entity_EmitVoice(this, g_szSndDying, 1.0);
        @Entity_PlayAction(this, Action_Shake, true);

        NPC_StopMovement(this);

        set_pev(this, pev_takedamage, DAMAGE_NO);
        set_pev(this, pev_deadflag, DEAD_DYING);
        set_pev(this, pev_nextthink, flGameTime + 2.0);

        CE_SetMember(this, m_flNextAIThink, flGameTime + 2.0);

        // cancel first kill function to play duing animation
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

@Entity_Killed(this, pKiller) {
    @Entity_ResetPath(this);

    if (pKiller) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        UTIL_Message_ExplodeModel(vecOrigin, random_float(-512.0, 512.0), g_iGibsModelIndex, 5, 25);
        @Entity_EmitVoice(this, g_szSndDeath, 1.0);
    }
}

@Entity_Remove(this) {
    @Entity_ResetPath(this);

    new Array:irgPath = CE_GetMember(this, m_irgPath);
    ArrayDestroy(irgPath);

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

        if (get_distance_f(vecOrigin, vecTarget) <= NPC_HitRange && NPC_IsVisible(this, vecTarget)) {
            if (random(100) < 10) {
                set_pev(this, pev_enemy, pAttacker);
            }
        }
    }

    if (random(100) < 50) {
        @Entity_EmitVoice(this, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
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
                @Entity_AIThink(this);
                CE_SetMember(this, m_flNextAIThink, flGameTime + Hwn_GetNpcUpdateRate());
            }

            // update velocity at high rate to avoid inconsistent velocity
            if (CE_HasMember(this, m_vecTarget)) {
                static Float:vecTarget[3];
                CE_GetMemberVec(this, m_vecTarget, vecTarget);

                static Float:flMaxSpeed;
                pev(this, pev_maxspeed, flMaxSpeed);
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
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flLastThink; pev(this, pev_ltime, flLastThink);

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    static Float:flReleaseHit; flReleaseHit = CE_GetMember(this, m_flReleaseHit);
    if (!flReleaseHit) {
        static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
        if (flNextAttack <= flGameTime) {
            static pEnemy; pEnemy = NPC_GetEnemy(this);
            if (pEnemy && NPC_CanHit(this, pEnemy, NPC_HitRange, NPC_TargetHitOffset)) {
                @Entity_EmitVoice(this, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.5);
                CE_SetMember(this, m_flReleaseHit, flGameTime + NPC_HitDelay);

                static Float:vecTargetVelocity[3];
                pev(pEnemy, pev_velocity, vecTargetVelocity);
                if (xs_vec_len(vecTargetVelocity) < NPC_HitRange) {
                    NPC_StopMovement(this);
                }
            }
        }
    } else if (flReleaseHit <= flGameTime) {
        static Float:flDamage; flDamage = CE_GetMember(this, m_flDamage);
        if (NPC_Hit(this, flDamage, NPC_HitRange, NPC_TargetHitOffset)) {
            emit_sound(this, CHAN_WEAPON, g_szSndHit, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }

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
            @Entity_EmitVoice(this, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
            CE_SetMember(this, m_flNextLaugh, flGameTime + random_float(1.0, 2.0));
        }

        static Float:flNextFootStep; flNextFootStep = CE_GetMember(this, m_flNextFootStep);
        if (flNextFootStep <= flGameTime) {
            @Entity_EmitFootStep(this);
            @Entity_ScareAway(this);
            CE_SetMember(this, m_flNextFootStep, flGameTime + 0.25);
        }
    }

    static Float:flNextEffectEmit; flNextEffectEmit = CE_GetMember(this, m_flNextEffectEmit);
    if (flNextEffectEmit <= flGameTime) {
        @Entity_EmitLight(this);
        @Entity_EmitSmoke(this);
        CE_SetMember(this, m_flNextEffectEmit, flGameTime + 0.1);
    }

    static Action:iAction; iAction = @Entity_GetAction(this);
    @Entity_PlayAction(this, iAction, false);
}

@Entity_MoveTo(this, const Float:vecTarget[3]) {
    NPC_MoveTo(this, vecTarget);
}

@Entity_EmitFootStep(this) {
    emit_sound(this, CHAN_BODY, g_szSndStep[random(sizeof(g_szSndStep))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_EmitVoice(this, const szSound[], Float:flDuration) {
    emit_sound(this, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_UpdateEnemy(this) {
    if (NPC_UpdateEnemy(this, NPC_ViewRange, 0.0, false, true, true)) {
        return true;
    }

    if (NPC_UpdateEnemy(this, NPC_FindRange, 0.0, false, false, false)) {
        return true;
    }

    return false;
}

@Entity_UpdateGoal(this) {
    new pEnemy = NPC_GetEnemy(this);

    if (@Entity_UpdateEnemy(this)) {
        pEnemy = pev(this, pev_enemy);
    }

    if (pEnemy) {
        static Float:vecGoal[3];
        pev(pEnemy, pev_origin, vecGoal);
        CE_SetMemberVec(this, m_vecGoal, vecGoal);
    }
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
    new Action:iAction = Action_Idle;

    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (CE_GetMember(this, m_flReleaseHit) > 0.0) {
                iAction = Action_Attack;
            }

            static Float:vecVelocity[3];
            pev(this, pev_velocity, vecVelocity);

            if (xs_vec_len_2d(vecVelocity) > 10.0) {
                iAction = iAction == Action_Attack ? Action_RunAttack : Action_Run;
            }
        }
        case DEAD_DYING: {
            iAction = Action_Shake;
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

@Entity_EmitLight(this) {
    new Float:flRate = Hwn_GetNpcUpdateRate();

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

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

@Entity_EmitSmoke(this) {
    new Float:flNextSmokeEmit = CE_GetMember(this, m_flNextSmokeEmit);
    if (get_gametime() < flNextSmokeEmit) {
        return;
    }

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += random_float(-16.0, 16.0);
    UTIL_Message_FireField(vecOrigin, 8, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);

    CE_SetMember(this, m_flNextSmokeEmit, get_gametime() + 0.1);
}

@Entity_ScareAway(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_alive(pPlayer)) {
            continue;
        }

        static Float:vecUserOrigin[3];
        pev(pPlayer, pev_origin, vecUserOrigin);

        if (get_distance_f(vecOrigin, vecUserOrigin) > 512.0) {
            continue;
        }

        message_begin(MSG_ONE, gmsgScreenShake, .player = pPlayer);
        write_short(UTIL_FixedUnsigned16(8.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<8));
        message_end();
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

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
