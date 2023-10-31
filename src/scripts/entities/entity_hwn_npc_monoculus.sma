#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>
#include <hwn_npc_stocks>

#define PLUGIN "[Custom Entity] Hwn NPC Monoculus"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_monoculus"
#define PORTAL_ENTITY_NAME "hwn_monoculus_portal"
#define ROCKET_ENTITY_NAME "hwn_monoculus_rocket"

#define MONOCULUS_ROCKET_SPEED 720.0
#define MONOCULUS_PUSHBACK_SPEED 128.0
#define MONOCULUS_MIN_HEIGHT 128.0
#define MONOCULUS_MAX_HEIGHT 256.0
#define MONOCULUS_SPAWN_ROCKET_DISTANCE 80.0

#define m_flReleaseHit "flReleaseHit"
#define m_flTargetArrivalTime "flTargetArrivalTime"
#define m_flNextAIThink "flNextAIThink"
#define m_flDamageToStun "flDamageToStun"
#define m_flNextAction "flNextAction"
#define m_flNextSmokeEmit "flNextSmokeEmit"
#define m_iNextPortal "iNextPortal"
#define m_flNextHeightUpdate "flNextHeightUpdate"
#define m_flNextAttack "flNextAttack"
#define m_flReleaseAngry "flReleaseAngry"
#define m_flReleaseStun "flReleaseStun"
#define m_flLastDamage "flLastDamage"
#define m_flDamageCounter "flDamageCounter"
#define m_flNextTeleportation "flNextTeleportation"
#define m_flReleaseTeleportion "flReleaseTeleportion"
// #define m_flReleasePushBack "flReleasePushBack"
#define m_iCharge "iCharge"
#define m_vecTarget "vecTarget"
#define m_vecGoal "vecGoal"
#define m_pKiller "pKiller"
#define m_flHeight "flHeight"

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

new const g_rgActions[Action][NPC_Action] = {
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
const Float:NPC_ViewRange = 3072.0;
const Float:NPC_HitRange = 3072.0;
const Float:NPC_HitDelay = 0.33;

new const Float:NPC_TargetHitOffset[3] = {0.0, 0.0, 0.0};

new g_iSmokeModelIndex;

new g_pCvarAngryTime;
new g_pCvarDamageToStun;
new g_pCvarJumpTimeMin;
new g_pCvarJumpTimeMax;

new g_iCeHandler;

new Array:g_irgPortals;
new Array:g_irgPortalAngles;
new g_iLevel = 0;

public plugin_precache() {
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

    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/npc/monoculus.mdl",
        .vMins = Float:{-48.0, -48.0, -48.0},
        .vMaxs = Float:{48.0, 48.0, 48.0},
        .bloodColor = 212
    );

    CE_RegisterHook(CEFunction_InitPhysics, ENTITY_NAME, "@Entity_InitPhysics");
    CE_RegisterHook(CEFunction_Restart, ENTITY_NAME, "@Entity_Restart");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    CE_RegisterHook(CEFunction_Spawn, PORTAL_ENTITY_NAME, "@Portal_Spawn");

    Hwn_Bosses_Register(ENTITY_NAME, "Monoculus");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

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

/*--------------------------------[ Methods ]--------------------------------*/

@Portal_Spawn(pEntity) {
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

@Entity_Restart(this) {
    @Entity_ResetTarget(this);
}

@Entity_Spawn(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flNextAttack, 0.0);
    CE_SetMember(this, m_flReleaseHit, 0.0);
    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_flNextHeightUpdate, 0.0);
    CE_SetMember(this, m_flNextSmokeEmit, 0.0);
    CE_SetMember(this, m_iNextPortal, -1);
    CE_SetMember(this, m_flNextAction, 0.0);
    CE_SetMember(this, m_flTargetArrivalTime, 0.0);
    CE_SetMember(this, m_flDamageToStun, get_pcvar_float(g_pCvarDamageToStun));
    CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
    CE_SetMember(this, m_flHeight, 0.0);
    CE_SetMember(this, m_pKiller, 0);
    CE_SetMember(this, m_flNextTeleportation, flGameTime + 5.0);
    CE_SetMember(this, m_flReleaseTeleportion, 0.0);
    CE_SetMember(this, m_flReleaseAngry, 0.0);
    CE_SetMember(this, m_flReleaseStun, 0.0);
    // CE_SetMember(this, m_flReleasePushBack, 0.0);
    CE_SetMember(this, m_iCharge, 0);
    CE_SetMember(this, m_flDamageCounter, 0.0);
    CE_SetMember(this, m_flLastDamage, 0.0);

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    xs_vec_mul_scalar(flRenderColor, 0.2, flRenderColor);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_health, NPC_Health + (g_iLevel * NPC_HealthPerLevel));
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 32.0});
    set_pev(this, pev_maxspeed, NPC_Speed);
    set_pev(this, pev_enemy, 0);
    set_pev(this, pev_rendercolor, flRenderColor);
    set_pev(this, pev_takedamage, DAMAGE_NO);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    @Entity_EmitVoice(this, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 1.0);
    @Entity_PlayAction(this, Action_Spawn, true);

    set_pev(this, pev_nextthink, flGameTime + g_rgActions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Kill(this, pKiller) {
    new Float:flGameTime = get_gametime();

    new iDeadFlag = pev(this, pev_deadflag);

    CE_SetMember(this, m_pKiller, pKiller);

    if (pKiller && iDeadFlag == DEAD_NO) {
        NPC_StopMovement(this);

        set_pev(this, pev_takedamage, DAMAGE_NO);
        set_pev(this, pev_deadflag, DEAD_DYING);
        set_pev(this, pev_movetype, MOVETYPE_TOSS);
        set_pev(this, pev_nextthink, flGameTime + g_rgActions[Action_Death][NPC_Action_Time]);

        CE_SetMember(this, m_flNextAIThink, flGameTime + g_rgActions[Action_Death][NPC_Action_Time]);

        @Entity_PlayAction(this, Action_Death, true);
    
        // cancel first kill function to play duing animation
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

@Entity_Killed(this, pKiller) {
    @Entity_ResetTarget(this);
    @Entity_DisappearEffect(this);

    if (pKiller) {
        g_iLevel++;
    } else {
        g_iLevel = max(g_iLevel - 1, 0);
    }
}

@Entity_Remove(this) {
    @Entity_ResetTarget(this);
}

@Entity_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_BBOX);
    set_pev(this, pev_movetype, MOVETYPE_FLY);

    set_pev(this, pev_controller_0, 125);
    set_pev(this, pev_controller_1, 125);
    set_pev(this, pev_controller_2, 125);
    set_pev(this, pev_controller_3, 125);
    
    set_pev(this, pev_gamestate, 1);
    set_pev(this, pev_gravity, 0.01);
    set_pev(this, pev_fixangle, 1);
    set_pev(this, pev_friction, 0.25);
}

@Entity_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flDamageCounter; flDamageCounter = CE_GetMember(this, m_flDamageCounter);
    static Float:flLastDamage; flLastDamage = CE_GetMember(this, m_flLastDamage);
    static Float:flDamageToStun; flDamageToStun = CE_GetMember(this, m_flDamageToStun);

    if (flDamage > flDamageToStun) {
        @Entity_Stun(this);
        CE_SetMember(this, m_flDamageToStun, get_pcvar_float(g_pCvarDamageToStun));
    } else {
        CE_SetMember(this, m_flDamageToStun, flDamageToStun - flDamage);
    }

    if (flDamageCounter > 300.0) {
        @Entity_MakeAngry(this);
        CE_SetMember(this, m_flDamageCounter, 0.0);
    } else {
        if (flGameTime - flLastDamage < 1.0) {
            CE_SetMember(this, m_flDamageCounter, flDamageCounter + flDamage);
        } else {
            CE_SetMember(this, m_flDamageCounter, 0.0);
        }
    }

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

    if (random(100) < 10) {
        @Entity_EmitVoice(this, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }

    CE_SetMember(this, m_flLastDamage, flGameTime);
}

@Entity_Think(this) {
    static Float:flLastThink; pev(this, pev_ltime, flLastThink);
    static Float:flGameTime; flGameTime = get_gametime();
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

            @Entity_Float(this);
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

    if (pev(this, pev_deadflag) == DEAD_DYING) {
        @Entity_EmitVoice(this, g_szSndDeath, 1.0);
        set_pev(this, pev_deadflag, DEAD_DEAD);
        CE_Kill(this);
        return;
    }

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    static Float:flReleaseStun; flReleaseStun = CE_GetMember(this, m_flReleaseStun);
    if (flReleaseStun) {
        if (flReleaseStun <= flGameTime) {
            CE_SetMember(this, m_flReleaseStun, 0.0);
        } else {
            return;
        }
    }

    static Float:flReleaseTeleportion; flReleaseTeleportion = CE_GetMember(this, m_flReleaseTeleportion);
    if (flReleaseTeleportion) {
        if (flReleaseTeleportion <= flGameTime) {
            @Entity_Teleport(this);
            CE_SetMember(this, m_flReleaseTeleportion, 0.0);
        } else {
            return;
        }
    }

    new Float:flHitRange = NPC_HitRange;
    new Float:flHitDelay = NPC_HitDelay;

    static Float:flReleaseHit; flReleaseHit = CE_GetMember(this, m_flReleaseHit);
    if (!flReleaseHit) {
        static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
        if (flNextAttack <= flGameTime && CE_GetMember(this, m_flNextAction) <= flGameTime) {
            static pEnemy; pEnemy = NPC_GetEnemy(this);
            if (pEnemy && NPC_CanHit(this, pEnemy, flHitRange, NPC_TargetHitOffset)) {
                static Float:vecTarget[3];
                pev(pEnemy, pev_origin, vecTarget);

                CE_SetMember(this, m_iCharge, Float:CE_GetMember(this, m_flReleaseAngry) ? 3 : 1);
                CE_SetMember(this, m_flReleaseHit, flGameTime + flHitDelay);
            }
        }
    } else if (flReleaseHit <= flGameTime) {
        if (CE_GetMember(this, m_iCharge) > 0) {
            @Entity_Shot(this);
            CE_SetMember(this, m_flReleaseHit, flGameTime + flHitDelay);
        } else {
            CE_SetMember(this, m_flReleaseHit, 0.0);
            CE_SetMember(this, m_flNextAttack, flGameTime + 0.8);
        }
    } else {
        @Entity_PlayAction(this, Action_LookAround, false);
        @Entity_UpdateEnemy(this, NPC_HitRange, 0.0);
    }

    @Entity_UpdateGoal(this);
    @Entity_UpdateTarget(this);

    static Float:flNextHeightUpdate; flNextHeightUpdate = CE_GetMember(this, m_flNextHeightUpdate);
    if (flNextHeightUpdate <= flGameTime) {
        @Entity_UpdateHeight(this);
        CE_SetMember(this, m_flNextHeightUpdate, flGameTime + 1.0);
    }

    static Float:flNextSmokeEmit; flNextSmokeEmit = CE_GetMember(this, m_flNextSmokeEmit);
    if (flNextSmokeEmit <= flGameTime) {
        @Entity_EmitSmoke(this);
        CE_SetMember(this, m_flNextSmokeEmit, flGameTime + 0.1);
    }

    static Float:flReleaseAngry; flReleaseAngry = CE_GetMember(this, m_flReleaseAngry);
    if (flReleaseAngry && flReleaseAngry <= flGameTime) {
        CE_SetMember(this, m_flReleaseAngry, 0.0);
    }

    static Float:flNextTeleportation; flNextTeleportation = CE_GetMember(this, m_flNextTeleportation);
    if (flNextTeleportation <= flGameTime) {
        new Float:flMinTime = get_pcvar_float(g_pCvarJumpTimeMin);
        new Float:flMaxTime = get_pcvar_float(g_pCvarJumpTimeMax);

        CE_SetMember(this, m_iNextPortal, @Entity_FindPortal(this));
        CE_SetMember(this, m_flReleaseTeleportion, flGameTime + g_rgActions[Action_TeleportIn][NPC_Action_Time]);
        CE_SetMember(this, m_flNextTeleportation, flGameTime + random_float(flMinTime, flMaxTime));

        @Entity_PlayAction(this, Action_TeleportIn, true);
    }

    static Action:iAction; iAction = @Entity_GetAction(this);
    @Entity_PlayAction(this, iAction, false);
}

@Entity_MoveTo(this, const Float:vecTarget[3]) {
    NPC_MoveTo(this, vecTarget);
}

@Entity_EmitVoice(this, const szSound[], Float:flDuration) {
    emit_sound(this, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_UpdateGoal(this) {
    new pEnemy = NPC_GetEnemy(this);

    if (@Entity_UpdateEnemy(this, NPC_ViewRange, 0.0)) {
        pEnemy = pev(this, pev_enemy);
    }

    if (pEnemy) {
        static Float:vecMins[3];
        pev(pEnemy, pev_mins, vecMins);

        static Float:vecGoal[3];
        pev(pEnemy, pev_origin, vecGoal);
        vecGoal[2] += vecMins[2];

        CE_SetMemberVec(this, m_vecGoal, vecGoal);
    }
}

@Entity_UpdateEnemy(this, Float:flMaxDistance, Float:flMinPriority) {
    new pEnemy = pev(this, pev_enemy);
    if (!NPC_IsValidEnemy(pEnemy)) {
        set_pev(this, pev_enemy, 0);
    }

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static pClosestTarget; pClosestTarget = 0;
    static Float:flClosestTargetPriority; flClosestTargetPriority = 0.0;

    for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
        if (!NPC_IsValidEnemy(pTarget)) {
            continue;
        }

        static Float:vecTarget[3]; pev(pTarget, pev_origin, vecTarget);

        if (!NPC_IsVisible(this, vecTarget, pTarget)) {
            continue;
        }

        static Float:flDistance; flDistance = xs_vec_distance(vecOrigin, vecTarget);
        static Float:flTargetPriority; flTargetPriority = 1.0 - (flDistance / flMaxDistance);

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

    if (CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3];
        CE_GetMemberVec(this, m_vecGoal, vecGoal);

        if (!NPC_IsReachable(this, vecGoal, pev(this, pev_enemy))) {
            CE_DeleteMember(this, m_vecGoal);
            CE_DeleteMember(this, m_vecTarget);
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
    static Float:flGametime; flGametime = get_gametime();
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
            if (CE_GetMember(this, m_flReleaseStun) > 0.0) {
                iAction = Action_Stunned;
            } else if (CE_GetMember(this, m_flReleaseHit) > 0.0) {
                iAction = Float:CE_GetMember(this, m_flReleaseAngry) ? Action_AngryAttack : Action_Attack;
            }
        }
    }

    return iAction;
}

@Entity_ResetTarget(this) {
    // CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
}

@Entity_DisappearEffect(this) {
    @Entity_TeleportEffect(this);
}

@Entity_Laugh(this) {
    @Entity_PlayAction(this, Action_Laugh, true);
    @Entity_EmitVoice(this, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}

@Entity_Stun(this) {
    @Entity_ResetTarget(this);
    @Entity_EmitVoice(this, g_szSndStunned[random(sizeof(g_szSndStunned))], 1.0);
    CE_SetMember(this, m_flReleaseStun, get_gametime() + g_rgActions[Action_Stunned][NPC_Action_Time]);
}

@Entity_MakeAngry(this) {
    static Float:flReleaseAngry; flReleaseAngry = CE_GetMember(this, m_flReleaseAngry);
    if (flReleaseAngry) {
        return;
    }

    CE_SetMember(this, m_flReleaseAngry, get_gametime() + get_pcvar_float(g_pCvarAngryTime));
}

@Entity_Float(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new Float:flDistanceToFloor = UTIL_GetDistanceToFloor(this, vecOrigin);
    if (flDistanceToFloor == -1.0) {
        return;
    }

    new Float:flHeight = CE_GetMember(this, m_flHeight);
    new iDirection = (flDistanceToFloor > flHeight) ? -1 : 1;

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);
    vecVelocity[2] = NPC_Speed * iDirection;
    set_pev(this, pev_velocity, vecVelocity);
}

@Entity_UpdateHeight(this) {
    new pEnemy = NPC_GetEnemy(this);

    new Float:flHeight = random_float(MONOCULUS_MIN_HEIGHT, MONOCULUS_MAX_HEIGHT);

    if (pEnemy) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        static Float:vecTarget[3];
        pev(pEnemy, pev_origin, vecTarget);

        if (vecOrigin[2] < vecTarget[2]) {
            flHeight += vecTarget[2] - vecOrigin[2];
        }
    }

    CE_SetMember(this, m_flHeight, flHeight);
}

@Entity_EmitSmoke(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_FireField(vecOrigin, 16, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);
}

@Entity_Shot(this) {
    new iCharge = CE_GetMember(this, m_iCharge);
    if (!iCharge) {
        return;
    }
    
    CE_SetMember(this, m_iCharge, iCharge - 1);

    // @Entity_PushBack(this);
    @Entity_SpawnRocket(this);
    @Entity_EmitVoice(this, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.3);
}

@Entity_FindPortal(this) {
    if (g_irgPortals == Invalid_Array) {
        return -1;
    }

    new iProtalsNum = ArraySize(g_irgPortals);
    if (!iProtalsNum) {
        return - 1;
    }

    new iPrevPortal = CE_GetMember(this, m_iNextPortal);

    new iPortal;
    do {
        iPortal = random(iProtalsNum);
    } while (iPortal == iPrevPortal && iProtalsNum > 1);

    return iPortal;
}

@Entity_Teleport(this) {
    static iPortal; iPortal = CE_GetMember(this, m_iNextPortal);
    if (iPortal == -1) {
        return;
    }

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecTargetOrigin[3]; ArrayGetArray(g_irgPortals, iPortal, vecTargetOrigin);
    static Float:vecTargetAngles[3]; ArrayGetArray(g_irgPortalAngles, iPortal, vecTargetAngles);

    @Entity_TeleportEffect(this);

    engfunc(EngFunc_SetOrigin, this, vecTargetOrigin);
    set_pev(this, pev_angles, vecTargetAngles);

    @Entity_TeleportEffect(this);

    @Entity_PlayAction(this, Action_TeleportOut, true);

    @Entity_EmitVoice(this, g_szSndSpawn, 1.0);

    client_cmd(0, "spk %s", g_szSndMoved);

    @Entity_ResetTarget(this);
}

@Entity_TeleportEffect(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    UTIL_Message_FireField(vecOrigin, 64, g_iSmokeModelIndex, 10, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 20);
    UTIL_Message_Dlight(vecOrigin, 48, {HWN_COLOR_PRIMARY}, 5, 32);
}

@Entity_SpawnRocket(this) {
    static Float:vecDirection[3];
    UTIL_GetDirectionVector(this, vecDirection);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    xs_vec_add_scaled(vecOrigin, vecDirection, MONOCULUS_SPAWN_ROCKET_DISTANCE, vecOrigin);

    new pRocket = CE_Create(ROCKET_ENTITY_NAME, vecOrigin);
    if (!pRocket) {
        return;
    }

    set_pev(pRocket, pev_owner, this);

    static Float:vecAngles[3];
    pev(this, pev_angles, vecAngles);
    set_pev(pRocket, pev_angles, vecAngles);

    static Float:vecVelocity[3];
    xs_vec_mul_scalar(vecDirection, MONOCULUS_ROCKET_SPEED, vecVelocity);
    set_pev(pRocket, pev_velocity, vecVelocity);

    dllfunc(DLLFunc_Spawn, pRocket);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (g_iCeHandler == CE_GetHandlerByEntity(pEntity)) {
        @Entity_TakeDamage(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits);
    }
}

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    if (pKiller && g_iCeHandler == CE_GetHandlerByEntity(pKiller)) {
        if (random_num(0, 100) < 30) {
            @Entity_Laugh(pKiller);
        }
    }
}
