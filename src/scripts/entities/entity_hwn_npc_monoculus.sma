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

#define ZERO_VECTOR_F Float:{0.0, 0.0, 0.0}

#define MONOCULUS_ROCKET_SPEED 720.0
#define MONOCULUS_PUSHBACK_SPEED 128.0
#define MONOCULUS_MIN_HEIGHT 128.0
#define MONOCULUS_MAX_HEIGHT 256.0
#define MONOCULUS_SPAWN_ROCKET_DISTANCE 80.0

#define m_flNextAIThink "flNextAIThink"
#define m_bIsStunned "bIsStunned"
#define m_bIsAngry "bIsAngry"
#define m_flDamageToStun "flDamageToStun"
#define m_flNextAction "flNextAction"
// #define m_flNextVoice "flNextVoice"
#define m_flNextSmokeEmit "flNextSmokeEmit"
// #define m_iNextPortal "iNextPortal"
#define m_flNextFloat "flNextFloat"
#define m_flNextAttack "flNextAttack"
#define m_flNextShot "flNextShot"
#define m_flReleaseAngry "flReleaseAngry"
#define m_flReleaseStun "flReleaseStun"
#define m_flLastDamage "flLastDamage"
#define m_flDamageCounter "flDamageCounter"
// #define m_flNextJumpToPortal "flNextJumpToPortal"
// #define m_flReleaseTeleport "flReleaseTeleport"
// #define m_flReleasePushBack "flReleasePushBack"
#define m_iCharge "iCharge"
// #define m_vecGoal "vecGoal"
// #define m_vecTarget "vecTarget"
#define m_pKiller "pKiller"

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

new const g_actions[Action][NPC_Action] = {
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
    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/npc/monoculus.mdl",
        .preset = CEPreset_NPC,
        .bloodColor = 212
    );

    Hwn_Bosses_Register(ENTITY_NAME, "Monoculus");

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

    CE_RegisterHook(CEFunction_Spawn, PORTAL_ENTITY_NAME, "@Portal_Spawn");

    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

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

@Entity_Init(this) {
    // NPC_Create(this, 0.0);
}

@Entity_Remove(this) {
    // NPC_Destroy(this);
}

@Entity_Spawn(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_bIsStunned, false);
    CE_SetMember(this, m_bIsAngry, false);
    CE_SetMember(this, m_flDamageToStun, get_pcvar_float(g_pCvarDamageToStun));
    // CE_SetMember(this, m_flLastAction, flGameTime);
    CE_SetMember(this, m_flNextSmokeEmit, flGameTime);
    // CE_SetMember(this, m_iNextPortal, flGameTime);
    CE_SetMember(this, m_flNextFloat, flGameTime);
    CE_SetMember(this, m_flNextAttack, flGameTime);
    CE_SetMember(this, m_flNextShot, flGameTime);
    // CE_SetMember(this, m_flNextVoice, flGameTime);
    CE_SetMember(this, m_flNextAction, flGameTime);
    // CE_SetMember(this, m_flNextJumpToPortal, flGameTime + 5.0);
    // CE_SetMember(this, m_flReleaseTeleport, 0.0);
    CE_SetMember(this, m_flReleaseAngry, 0.0);
    CE_SetMember(this, m_flReleaseStun, 0.0);
    // CE_SetMember(this, m_flReleasePushBack, 0.0);
    CE_SetMember(this, m_iCharge, 0);
    CE_SetMember(this, m_flDamageCounter, 0.0);
    CE_SetMember(this, m_flLastDamage, 0.0);

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        flRenderColor[i] *= 0.2;
    }

    set_pev(this, pev_health, NPC_Health + (g_iLevel * NPC_HealthPerLevel));
    set_pev(this, pev_solid, SOLID_BBOX);
    set_pev(this, pev_movetype, MOVETYPE_FLY);
    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, flRenderColor);
    set_pev(this, pev_takedamage, DAMAGE_NO);
    set_pev(this, pev_maxspeed, NPC_Speed);

    engfunc(EngFunc_SetSize, this, {-48.0, -48.0, -48.0}, {48.0, 48.0, 48.0});

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    @Entity_EmitVoice(this, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 1.0);
    @Entity_PlayAction(this, Action_Spawn, true);

    set_pev(this, pev_nextthink, flGameTime + g_actions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Kill(this, pKiller) {
    new iDeadFlag = pev(this, pev_deadflag);

    CE_SetMember(this, m_pKiller, pKiller);

    if (pKiller && iDeadFlag == DEAD_NO) {
        NPC_StopMovement(this);

        set_pev(this, pev_takedamage, DAMAGE_NO);
        set_pev(this, pev_deadflag, DEAD_DYING);

        // cancel first kill function to play duing animation
        return PLUGIN_HANDLED;
    }

    if (pKiller) {
        g_iLevel++;
    } else {
        g_iLevel = max(g_iLevel - 1, 0);
    }

    return PLUGIN_CONTINUE;
}

@Entity_Killed(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    TeleportEffect(vecOrigin);
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

            new pEnemy = NPC_GetEnemy(this);
            if (pEnemy) {
                static Float:flTurnSpeed; flTurnSpeed = 180.0 * floatmax(flGameTime - flLastThink, 0.1);
                static Float:vecTarget[3]; pev(pEnemy, pev_origin, vecTarget);
                UTIL_TurnTo(this, vecTarget, bool:{false, false, true}, flTurnSpeed);
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

    if (bShouldUpdateAI) {
        @Entity_PlayAction(this, Action_Idle, false);
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

    static Float:flReleaseStun; flReleaseStun = CE_GetMember(this, m_flReleaseStun);
    if (flReleaseStun && flReleaseStun <= flGameTime) {
        CE_SetMember(this, m_bIsStunned, false);
        CE_SetMember(this, m_flReleaseStun, 0.0);
    }

    new bool:bIsStunned = CE_GetMember(this, m_bIsStunned);
    if (bIsStunned) {
        return;
    }

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    new pEnemy = NPC_GetEnemy(this);
    if (pEnemy) {
        static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
        if (flNextAttack <= flGameTime) {
            static Float:vecTarget[3];
            pev(pEnemy, pev_origin, vecTarget);

            if (NPC_IsVisible(this, vecTarget) && NPC_IsInViewCone(this, vecTarget, 10.0)) {
                @Entity_Attack(this);
                CE_SetMember(this, m_flNextAttack, flGameTime + 1.25);
            }
        }
    } else {
        @Entity_PlayAction(this, Action_LookAround, false);
        @Entity_UpdateEnemy(this, NPC_HitRange, 0.0);
    }

    static Float:flNextFloat; flNextFloat = CE_GetMember(this, m_flNextFloat);
    if (flNextFloat < flGameTime) {
        @Entity_Float(this);
        CE_SetMember(this, m_flNextFloat, flGameTime + 1.0);
    }

    if (CE_GetMember(this, m_iCharge) > 0) {
        static Float:flNextShot; flNextShot = CE_GetMember(this, m_flNextShot);
        if (flNextShot <= flGameTime) {
            @Entity_Shot(this);
            CE_SetMember(this, m_flNextShot, flGameTime + NPC_AttackDelay);
        }
    }

    static Float:flNextSmokeEmit; flNextSmokeEmit = CE_GetMember(this, m_flNextSmokeEmit);
    if (flNextSmokeEmit <= flGameTime) {
        @Entity_EmitSmoke(this);
        CE_SetMember(this, m_flNextSmokeEmit, flGameTime + 0.1);
    }

    static Float:flReleaseAngry; flReleaseAngry = CE_GetMember(this, m_flReleaseAngry);
    if (flReleaseAngry && flReleaseAngry <= flGameTime) {
        @Entity_CalmDown(this);
        CE_SetMember(this, m_flReleaseAngry, 0.0);
    }



    // static Float:flReleasePushBack; flReleasePushBack = CE_GetMember(this, m_flReleasePushBack);
    // if (flReleasePushBack) {
    //     if (flReleasePushBack > flGameTime) {
    //         static Float:vecVelocity[3];
    //         UTIL_GetDirectionVector(this, vecVelocity, -MONOCULUS_PUSHBACK_SPEED);
    //         set_pev(this, pev_velocity, vecVelocity);
    //     } else {
    //         CE_SetMember(this, m_flReleasePushBack, 0.0);
    //     }
    // }

    // new Float:flLastAction = CE_GetMember(this, m_flLastAction);
    // if (get_gametime() - flLastAction > 5.0) {
    //     @Entity_JumpToPortal(this);
    // }

    // static Float:flNextJumpToPortal; flNextJumpToPortal= CE_GetMember(this, m_flNextJumpToPortal);
    // if (flNextJumpToPortal < flGameTime) {
    //     @Entity_JumpToPortal(this);

    //     new Float:flMinTime = get_pcvar_float(g_pCvarJumpTimeMin);
    //     new Float:flMaxTime = get_pcvar_float(g_pCvarJumpTimeMax);
    //     CE_SetMember(this, m_flNextJumpToPortal, random_float(flMinTime, flMaxTime));
    // }

    // static Float:flReleaseTeleport; flReleaseTeleport = CE_GetMember(this, m_flReleaseTeleport);
    // if (flReleaseTeleport && flReleaseTeleport <= flGameTime) {
    //     @Entity_Teleport(this);
    //     CE_SetMember(this, m_flReleaseTeleport, 0.0);
    // }
}

@Entity_UpdateEnemy(this, Float:flMaxDistance, Float:flMinPriority) {
    new pEnemy = pev(this, pev_enemy);
    if (!NPC_IsValidEnemy(pEnemy)) {
        set_pev(this, pev_enemy, 0);
    }

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

        if (!IS_PLAYER(pTarget)) {
            continue;
        }

        if (!NPC_IsValidEnemy(pTarget, iTeam)) {
            continue;
        }

        static Float:vecTarget[3];
        pev(pTarget, pev_origin, vecTarget);

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

@Entity_Attack(this) {
    log_amx("Entity_Attack");
    static Float:flGameTime; flGameTime = get_gametime();
    CE_SetMember(this, m_iCharge, CE_GetMember(this, m_bIsAngry) ? 3 : 1);
    CE_SetMember(this, m_flNextShot, flGameTime + NPC_AttackDelay);
    @Entity_PlayAction(this, CE_GetMember(this, m_bIsAngry) ? Action_AngryAttack : Action_Attack, true);
}

@Entity_Laugh(this) {
    @Entity_PlayAction(this, Action_Laugh, true);
    @Entity_EmitVoice(this, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}

@Entity_Stun(this) {
    set_pev(this, pev_velocity, ZERO_VECTOR_F);
    CE_SetMember(this, m_bIsStunned, true);
    @Entity_EmitVoice(this, g_szSndStunned[random(sizeof(g_szSndStunned))], 1.0);
    CE_SetMember(this, m_flReleaseStun, get_gametime() + g_actions[Action_Stunned][NPC_Action_Time]);
    @Entity_PlayAction(this, Action_Stunned, true);
}

@Entity_PlayAction(this, Action:iAction, bool:bSupercede) {
    static Float:flGameTime; flGameTime = get_gametime();
    if (!bSupercede && CE_GetMember(this, m_flNextAction) > flGameTime) {
        return;
    }

    new iSequence = random_num(g_actions[iAction][NPC_Action_StartSequence], g_actions[iAction][NPC_Action_EndSequence]);
    if (!UTIL_SetSequence(this, iSequence)) {
        return;
    }

    log_amx("@Entity_PlayAction(%d, %d, %d)", this, iAction, bSupercede);

    CE_SetMember(this, m_flNextAction, flGameTime + g_actions[iAction][NPC_Action_Time]);
}


@Entity_EmitVoice(this, const szSound[], Float:flDuration) {
    emit_sound(this, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    // CE_SetMember(this, m_flNextVoice, flGameTime + flDuration);
}

@Entity_MakeAngry(this) {
    new bool:bIsAngry = CE_GetMember(this, m_bIsAngry);
    if (bIsAngry) {
        return;
    }

    CE_SetMember(this, m_bIsAngry, true);
    CE_SetMember(this, m_flReleaseAngry, get_gametime() + get_pcvar_float(g_pCvarAngryTime));
}

@Entity_SetHeight(this, Float:flHeight) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new Float:flDistanceToFloor = UTIL_GetDistanceToFloor(this, vecOrigin);
    if (flDistanceToFloor == -1.0) {
        set_pev(this, pev_velocity, ZERO_VECTOR_F);
        return;
    }

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    new iDirection = (flDistanceToFloor > flHeight) ? -1 : 1;
    vecVelocity[2] = NPC_Speed * iDirection;

    set_pev(this, pev_velocity, vecVelocity);
}

@Entity_AlignHeight(this, const Float:vecTarget[3]) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
 
    new Float:flHeightDiff = vecOrigin[2] - vecTarget[2];
    vecOrigin[2] -= flHeightDiff;

    new Float:flDistanceToFloor = UTIL_GetDistanceToFloor(this, vecOrigin);
    if (flDistanceToFloor == -1.0) {
        return;
    }

    @Entity_SetHeight(this, flDistanceToFloor < MONOCULUS_MIN_HEIGHT ? MONOCULUS_MIN_HEIGHT : flDistanceToFloor);
}

@Entity_SpawnRocket(this) {
    static Float:vecDirection[3];
    UTIL_GetDirectionVector(this, vecDirection);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    xs_vec_add_scaled(vecOrigin, vecDirection, MONOCULUS_SPAWN_ROCKET_DISTANCE, vecOrigin);

    new pRocket = CE_Create("hwn_monoculus_rocket", vecOrigin);
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

// @Entity_PushBack(this) {
//     CE_SetMember(this, m_flReleasePushBack, get_gametime() + 0.25);
// }

// @Entity_JumpToPortal(this) {
//     if (g_irgPortals == Invalid_Array) {
//         return;
//     }

//     new iProtalsNum = ArraySize(g_irgPortals);
//     if (!iProtalsNum) {
//         return;
//     }

//     new bool:bIsStunned = CE_GetMember(this, m_bIsStunned);
//     if (bIsStunned) {
//         return;
//     }

//     new iPortal = random(iProtalsNum);
//     if (iPortal == CE_GetMember(this, m_iNextPortal)) {
//         return;
//     }

//     CE_SetMember(this, m_iNextPortal, iPortal);
//     CE_SetMember(this, m_flReleaseTeleport, get_gametime() + g_actions[Action_TeleportIn][NPC_Action_Time]);
// }

@Entity_EmitSmoke(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_FireField(vecOrigin, 16, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);
}

@Entity_Float(this) {
    new pEnemy = NPC_GetEnemy(this);
    if (pEnemy) {
        static Float:vecTarget[3];
        pev(pEnemy, pev_origin, vecTarget);
        @Entity_AlignHeight(this, vecTarget);
    } else {
        new Float:flHeight = random_float(MONOCULUS_MIN_HEIGHT, MONOCULUS_MAX_HEIGHT);
        @Entity_SetHeight(this, flHeight);
    }
}

@Entity_Shot(this) {
    new iCharge = CE_GetMember(this, m_iCharge);
    if (!iCharge) {
        return;
    }

    log_amx("Entity_Shot");
    
    CE_SetMember(this, m_iCharge, iCharge - 1);

    // @Entity_PushBack(this);
    @Entity_SpawnRocket(this);
    @Entity_EmitVoice(this, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.3);
}

@Entity_CalmDown(this) {
    CE_SetMember(this, m_bIsAngry, false);
}

// @Entity_Teleport(this) {
//     static iPortal; iPortal = CE_GetMember(this, m_iNextPortal);

//     static Float:vecOrigin[3];
//     pev(this, pev_origin, vecOrigin);

//     static Float:vecTargetOrigin[3];
//     ArrayGetArray(g_irgPortals, iPortal, vecTargetOrigin);

//     static Float:vecTargetAngles[3];
//     ArrayGetArray(g_irgPortalAngles, iPortal, vecTargetAngles);
    
//     engfunc(EngFunc_SetOrigin, this, vecTargetOrigin);
//     set_pev(this, pev_angles, vecTargetAngles);

//     TeleportEffect(vecOrigin);
//     TeleportEffect(vecTargetOrigin);

//     @Entity_PlayAction(this, Action_TeleportOut, false);

//     client_cmd(0, "spk %s", g_szSndMoved);
//     NPC_EmitVoice(this, g_szSndSpawn, 1.0);
// }

TeleportEffect(const Float:vecOrigin[3]) {
    UTIL_Message_FireField(vecOrigin, 64, g_iSmokeModelIndex, 10, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 20);
    UTIL_Message_Dlight(vecOrigin, 48, {HWN_COLOR_PRIMARY}, 5, 32);
}
