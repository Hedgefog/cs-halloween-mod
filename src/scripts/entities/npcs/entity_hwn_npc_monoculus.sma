#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#include <entity_base_npc_const>

#define PLUGIN "[Custom Entity] Hwn NPC Monoculus"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_monoculus"
#define PORTAL_ENTITY_NAME "hwn_monoculus_portal"
#define ROCKET_ENTITY_NAME "hwn_projectile_rocket"

#define m_flDamageToStun "flDamageToStun"
#define m_flNextSmokeEmit "flNextSmokeEmit"
#define m_iNextPortal "iNextPortal"
#define m_flNextHeightUpdate "flNextHeightUpdate"
#define m_flReleaseAngry "flReleaseAngry"
#define m_flReleaseStun "flReleaseStun"
#define m_flLastDamage "flLastDamage"
#define m_flDamageCounter "flDamageCounter"
#define m_flNextTeleportation "flNextTeleportation"
#define m_flReleaseTeleportion "flReleaseTeleportion"
#define m_iCharge "iCharge"
#define m_flHeight "flHeight"
#define m_flNextLookAround "flNextLookAround"

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

new const g_szModel[] = "models/hwn/npc/monoculus.mdl";

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
    { Sequence_Idle, Sequence_Idle, 0.0 },
    { Sequence_Stunned, Sequence_Stunned, 4.5 },
    { Sequence_Attack1, Sequence_Attack1, 1.0 },
    { Sequence_Attack2, Sequence_Attack3, 2.0 },
    { Sequence_Spawn, Sequence_Spawn, 4.5 },
    { Sequence_Laugh, Sequence_Laugh, 1.3 },
    { Sequence_TeleportIn, Sequence_TeleportIn, 1.0 },
    { Sequence_TeleportOut, Sequence_TeleportOut, 1.0 },
    { Sequence_Death, Sequence_Death, 8.36 },
    { Sequence_LookAround1, Sequence_LookAround3, 1.0}
};

const Float:NPC_Health = 8000.0;
const Float:NPC_HealthPerLevel = 3000.0;
const Float:NPC_Speed = 16.0;
const Float:NPC_ViewRange = 512.0;
const Float:NPC_FindRange = 2048.0;
const Float:NPC_AttackRange = 3072.0;
const Float:NPC_AttackDelay = 0.33;
const Float:NPC_RocketSpeed = 720.0;
const Float:NPC_PushBackSpeed = 64.0;
const Float:NPC_MinFloatHeight = 128.0;
const Float:NPC_MaxFloatHeight = 256.0;
const Float:NPC_SpawnRocketDistance = 80.0;

new g_iSmokeModelIndex;

new g_pCvarAngryTime;
new g_pCvarDamageToStun;
new g_pCvarJumpTimeMin;
new g_pCvarJumpTimeMax;

new CE:g_iCeHandler;

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

    precache_model(g_szModel);
    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke.spr");

    g_iCeHandler = CE_RegisterDerived(ENTITY_NAME, "hwn_npc_base");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitPhysics, "@Entity_InitPhysics");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_RegisterMethod(ENTITY_NAME, TakeDamage, "@Entity_TakeDamage", CE_MP_Cell, CE_MP_Cell, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, PlayAction, "@Entity_PlayAction", CE_MP_Cell, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");
    CE_RegisterMethod(ENTITY_NAME, StartAttack, "@Entity_StartAttack", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, ReleaseAttack, "@Entity_ReleaseAttack", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, ProcessGoal, "@Entity_ProcessGoal");
    CE_RegisterMethod(ENTITY_NAME, Dying, "@Entity_Dying");

    CE_RegisterHook(PORTAL_ENTITY_NAME, CEFunction_Spawned, "@Portal_Spawn");

    Hwn_Bosses_Register(ENTITY_NAME, "Monoculus");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

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

@Entity_Init(this) {
    CE_SetMember(this, CE_MEMBER_BLOODCOLOR, 212);
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-48.0, -48.0, -48.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{48.0, 48.0, 48.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMember(this, m_flAttackRange, NPC_AttackRange);
    CE_SetMember(this, m_flAttackDelay, NPC_AttackDelay);
    CE_SetMember(this, m_flFindRange, NPC_FindRange);
    CE_SetMember(this, m_flViewRange, NPC_ViewRange);
    CE_SetMember(this, m_flAttackRate, 0.8);
}

@Entity_Spawned(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flNextHeightUpdate, 0.0);
    CE_SetMember(this, m_flNextSmokeEmit, 0.0);
    CE_SetMember(this, m_iNextPortal, -1);
    CE_SetMember(this, m_flDamageToStun, get_pcvar_float(g_pCvarDamageToStun));
    CE_SetMember(this, m_flHeight, 0.0);
    CE_SetMember(this, m_flNextTeleportation, 0.0);
    CE_SetMember(this, m_flReleaseTeleportion, 0.0);
    CE_SetMember(this, m_flNextLookAround, 0.0);
    CE_SetMember(this, m_flReleaseAngry, 0.0);
    CE_SetMember(this, m_flReleaseStun, 0.0);
    CE_SetMember(this, m_iCharge, 0);
    CE_SetMember(this, m_flDamageCounter, 0.0);
    CE_SetMember(this, m_flLastDamage, 0.0);
    CE_SetMember(this, m_flDieDuration, g_rgActions[Action_Death][NPC_Action_Time]);

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    xs_vec_mul_scalar(flRenderColor, 0.2, flRenderColor);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_health, NPC_Health + (g_iLevel * NPC_HealthPerLevel));
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 32.0});
    set_pev(this, pev_maxspeed, NPC_Speed);
    set_pev(this, pev_rendercolor, flRenderColor);
    set_pev(this, pev_takedamage, DAMAGE_NO);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    CE_CallMethod(this, EmitVoice, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 1.0);
    
    CE_CallMethod(this, PlayAction, Action_Spawn, true);

    set_pev(this, pev_nextthink, flGameTime + g_rgActions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Dying(this) {
    CE_CallMethod(this, PlayAction, Action_Death, true);
}

@Entity_Killed(this, pKiller) {
    @Entity_DisappearEffect(this);

    if (pKiller) {
        g_iLevel++;
    } else {
        g_iLevel = max(g_iLevel - 1, 0);
    }
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

    return PLUGIN_HANDLED;
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

    if (IS_PLAYER(pAttacker) && CE_CallMethod(this, IsValidEnemy, pAttacker)) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        static Float:vecTarget[3];
        pev(pAttacker, pev_origin, vecTarget);

        if (get_distance_f(vecOrigin, vecTarget) <= NPC_ViewRange && CE_CallMethod(this, IsVisible, vecTarget, 0)) {
            if (random(100) < 10) {
                set_pev(this, pev_enemy, pAttacker);
            }
        }
    }

    if (random(100) < 10) {
        CE_CallMethod(this, EmitVoice, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }

    CE_SetMember(this, m_flLastDamage, flGameTime);
}

@Entity_Think(this) {
    static iDeadFlag; iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            @Entity_FloatThink(this);
        }
    }
}

@Entity_AIThink(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (pev(this, pev_deadflag) == DEAD_DYING) {
        CE_CallMethod(this, EmitVoice, g_szSndDeath, 1.0);
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

    CE_CallBaseMethod();

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
        if (flNextTeleportation > 0.0) {
            CE_SetMember(this, m_iNextPortal, @Entity_FindPortal(this));
            CE_SetMember(this, m_flReleaseTeleportion, flGameTime + g_rgActions[Action_TeleportIn][NPC_Action_Time]);

            CE_CallMethod(this, PlayAction, Action_TeleportIn, true);
        }

        new Float:flMinTime = get_pcvar_float(g_pCvarJumpTimeMin);
        new Float:flMaxTime = get_pcvar_float(g_pCvarJumpTimeMax);
        CE_SetMember(this, m_flNextTeleportation, flGameTime + random_float(flMinTime, flMaxTime));
    }

    if (CE_GetMember(this, m_flNextAction) <= flGameTime) {
        if (CE_GetMember(this, m_flNextLookAround) <= flGameTime) {
            if (random(100) < 5) {
                CE_CallMethod(this, PlayAction, Action_LookAround, false);
            }

            CE_SetMember(this, m_flNextLookAround, flGameTime + 3.0);
        }
    }
    
    new Action:iAction = @Entity_GetAction(this);
    CE_CallMethod(this, PlayAction, iAction, false);
}

@Entity_StartAttack(this, Float:flDamage, Float:flAttackRange, Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    static Float:flGameTime; flGameTime = get_gametime();

    static Float:vecTarget[3]; pev(pEnemy, pev_origin, vecTarget);

    CE_SetMember(this, m_iCharge, Float:CE_GetMember(this, m_flReleaseAngry) ? 3 : 1);
    CE_SetMember(this, m_flReleaseAttack, flGameTime + flAttackDelay);
}

@Entity_ReleaseAttack(this, Float:flDamage, Float:flAttackRange, Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (CE_GetMember(this, m_iCharge) > 0) {
        @Entity_Shot(this);
        CE_SetMember(this, m_flReleaseAttack, flGameTime + flAttackDelay);
    } else {
        CE_CallBaseMethod(flDamage, flAttackRange, vecHitOffset, flAttackDelay, pEnemy);
        CE_CallMethod(this, StopMovement);
    }
}

@Entity_ProcessGoal(this) {
    if (CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3];
        CE_GetMemberVec(this, m_vecGoal, vecGoal);

        if (!CE_CallMethod(this, IsReachable, vecGoal, pev(this, pev_enemy), 0.0)) {
            CE_DeleteMember(this, m_vecGoal);
            CE_DeleteMember(this, m_vecTarget);
        } else {
            CE_DeleteMember(this, m_vecGoal);
            CE_CallMethod(this, SetTarget, vecGoal);
        }
    }
}

bool:@Entity_PlayAction(this, Action:iAction, bool:bSupercede) {
    return CE_CallBaseMethod(g_rgActions[iAction][NPC_Action_StartSequence], g_rgActions[iAction][NPC_Action_EndSequence], g_rgActions[iAction][NPC_Action_Time], bSupercede);
}

Action:@Entity_GetAction(this) {
    new Action:iAction = Action_Idle;

    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (CE_GetMember(this, m_flReleaseStun) > 0.0) {
                iAction = Action_Stunned;
            } else if (CE_GetMember(this, m_flReleaseAttack) > 0.0) {
                iAction = Float:CE_GetMember(this, m_flReleaseAngry) ? Action_AngryAttack : Action_Attack;
            }
        }
    }

    return iAction;
}

@Entity_DisappearEffect(this) {
    @Entity_TeleportEffect(this);
}

@Entity_Laugh(this) {
    CE_CallMethod(this, StopMovement);
    CE_CallMethod(this, PlayAction, Action_Laugh, true);
    CE_CallMethod(this, EmitVoice, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}

@Entity_Stun(this) {
    CE_CallMethod(this, StopMovement);
    CE_CallMethod(this, ResetPath);
    CE_CallMethod(this, EmitVoice, g_szSndStunned[random(sizeof(g_szSndStunned))], 1.0);
    CE_SetMember(this, m_flReleaseStun, get_gametime() + g_rgActions[Action_Stunned][NPC_Action_Time]);
}

@Entity_MakeAngry(this) {
    static Float:flReleaseAngry; flReleaseAngry = CE_GetMember(this, m_flReleaseAngry);
    if (flReleaseAngry) return;

    CE_SetMember(this, m_flReleaseAngry, get_gametime() + get_pcvar_float(g_pCvarAngryTime));
}

@Entity_FloatThink(this) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Float:flDistanceToFloor; flDistanceToFloor = UTIL_GetDistanceToFloor(this, vecOrigin);
    if (flDistanceToFloor == -1.0) return;

    static Float:flHeight; flHeight = CE_GetMember(this, m_flHeight);
    static iDirection; iDirection = (flDistanceToFloor > flHeight) ? -1 : 1;

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);
    vecVelocity[2] = NPC_Speed * iDirection;
    set_pev(this, pev_velocity, vecVelocity);
}

@Entity_UpdateHeight(this) {
    new pEnemy = CE_CallMethod(this, GetEnemy);

    new Float:flHeight = random_float(NPC_MinFloatHeight, NPC_MaxFloatHeight);

    if (pEnemy) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        static Float:vecTarget[3]; pev(pEnemy, pev_origin, vecTarget);

        if (vecOrigin[2] < vecTarget[2]) {
            flHeight += vecTarget[2] - vecOrigin[2];
        }
    }

    CE_SetMember(this, m_flHeight, flHeight);
}

@Entity_EmitSmoke(this) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    UTIL_Message_FireField(vecOrigin, 16, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);
}

@Entity_Shot(this) {
    new iCharge = CE_GetMember(this, m_iCharge);
    if (!iCharge) return;
    
    CE_SetMember(this, m_iCharge, iCharge - 1);

    @Entity_SpawnRocket(this);
    @Entity_PushBack(this);

    CE_CallMethod(this, EmitVoice, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.3);
}

@Entity_PushBack(this) {
    static Float:vecForce[3]; UTIL_GetDirectionVector(this, vecForce, -NPC_PushBackSpeed);

    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
    xs_vec_add(vecVelocity, vecForce, vecVelocity);
    set_pev(this, pev_velocity, vecVelocity);
}

@Entity_FindPortal(this) {
    if (g_irgPortals == Invalid_Array) return - 1;

    new iProtalsNum = ArraySize(g_irgPortals);
    if (!iProtalsNum) return - 1;

    new iPrevPortal = CE_GetMember(this, m_iNextPortal);

    new iPortal;
    do {
        iPortal = random(iProtalsNum);
    } while (iPortal == iPrevPortal && iProtalsNum > 1);

    return iPortal;
}

@Entity_Teleport(this) {
    static iPortal; iPortal = CE_GetMember(this, m_iNextPortal);
    if (iPortal == -1) return;

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecTargetOrigin[3]; ArrayGetArray(g_irgPortals, iPortal, vecTargetOrigin);
    static Float:vecTargetAngles[3]; ArrayGetArray(g_irgPortalAngles, iPortal, vecTargetAngles);

    @Entity_TeleportEffect(this);

    engfunc(EngFunc_SetOrigin, this, vecTargetOrigin);
    set_pev(this, pev_angles, vecTargetAngles);

    @Entity_TeleportEffect(this);

    CE_CallMethod(this, PlayAction, Action_TeleportOut, true);
    CE_CallMethod(this, EmitVoice, g_szSndSpawn, 1.0);

    client_cmd(0, "spk %s", g_szSndMoved);

    CE_CallMethod(this, ResetPath);
}

@Entity_TeleportEffect(this) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    UTIL_Message_FireField(vecOrigin, 64, g_iSmokeModelIndex, 10, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 20);
    UTIL_Message_Dlight(vecOrigin, 48, {HWN_COLOR_PRIMARY}, 5, 32);
}

@Entity_SpawnRocket(this) {
    static Float:vecDirection[3]; UTIL_GetDirectionVector(this, vecDirection);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    xs_vec_add_scaled(vecOrigin, vecDirection, NPC_SpawnRocketDistance, vecOrigin);

    new pRocket = CE_Create(ROCKET_ENTITY_NAME, vecOrigin);
    if (!pRocket) return;

    set_pev(pRocket, pev_owner, this);

    dllfunc(DLLFunc_Spawn, pRocket);

    static Float:vecVelocity[3]; xs_vec_mul_scalar(vecDirection, NPC_RocketSpeed, vecVelocity);
    CE_CallMethod(pRocket, "Launch", vecVelocity);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    if (pKiller && g_iCeHandler == CE_GetHandlerByEntity(pKiller)) {
        if (random_num(0, 100) < 30) {
            @Entity_Laugh(pKiller);
        }
    }
}
