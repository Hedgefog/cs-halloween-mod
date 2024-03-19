#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_player_effects>
#include <api_custom_entities>
#include <api_particles>

#include <hwn>
#include <hwn_stun>
#include <hwn_utils>

#include <entity_base_npc_const>

#define PLUGIN "[Custom Entity] Hwn NPC Ghost"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_ghost"

#define m_flNextMoan "flNextMoan"
#define m_pParticlesSystem "pParticlesSystem"

enum _:Sequence {
    Sequence_Idle = 0
};

const Float:NPC_Health = 1.0;
const Float:NPC_Speed = 100.0;
const Float:NPC_Damage = 20.0;
const Float:NPC_AttackRange = 48.0;
const Float:NPC_AttackDelay = 0.25;
const Float:NPC_ViewRange = 1024.0;
const Float:NPC_TargetUpdateRate = 1.0;

new const g_szModel[] = "models/hwn/npc/ghost_v3.mdl";

new const g_szSndDisappeared[] = "hwn/misc/gotohell.wav";

new const g_szSndAttack[][128] = {
    "hwn/npc/ghost/ghost_attack01.wav",
    "hwn/npc/ghost/ghost_attack02.wav",
    "hwn/npc/ghost/ghost_attack03.wav"
};

new const g_szSndIdle[][128] = {
    "hwn/npc/ghost/ghost_moan01.wav",
    "hwn/npc/ghost/ghost_moan02.wav",
    "hwn/npc/ghost/ghost_moan03.wav",
    "hwn/npc/ghost/ghost_moan04.wav"
};

new g_rgpPlayerKiller[MAX_PLAYERS + 1];

public plugin_precache() {
    precache_model(g_szModel);

    precache_sound(g_szSndDisappeared);

    for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
        precache_sound(g_szSndAttack[i]);
    }

    for (new i = 0; i < sizeof(g_szSndIdle); ++i) {
        precache_sound(g_szSndIdle[i]);
    }

    CE_RegisterDerived(ENTITY_NAME, "hwn_npc_base");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitPhysics, "@Entity_InitPhysics");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_RegisterMethod(ENTITY_NAME, Hit, "@Entity_Hit", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, StartAttack, "@Entity_StartAttack", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, ReleaseAttack, "@Entity_ReleaseAttack", CE_MP_Float, CE_MP_Float, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");
    CE_RegisterMethod(ENTITY_NAME, UpdateGoal, "@Entity_UpdateGoal");
    CE_RegisterMethod(ENTITY_NAME, ProcessGoal, "@Entity_ProcessGoal");
    CE_RegisterMethod(ENTITY_NAME, IsValidEnemy, "@Entity_IsValidEnemy", CE_MP_Cell);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
}

/*--------------------------------[ Hooks ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, -32.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 32.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMember(this, m_flAttackRange, NPC_AttackRange);
    CE_SetMember(this, m_flAttackDelay, NPC_AttackDelay);
    CE_SetMember(this, m_flViewRange, NPC_ViewRange);
    CE_SetMember(this, m_flDamage, NPC_Damage);
    CE_SetMember(this, m_flAttackRate, 3.0);

    new ParticleSystem:pParticlesSystem = ParticleSystem_Create("hwn-magic-trail", Float:{0.0, 0.0, -4.0}, _, this);
    CE_SetMember(this, m_pParticlesSystem, pParticlesSystem);
}

@Entity_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(this, pev_takedamage, DAMAGE_AIM);

    return PLUGIN_HANDLED;
}

@Entity_Spawned(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flDamage, NPC_Damage);
    CE_SetMember(this, m_flNextMoan, flGameTime);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 1.0);
    set_pev(this, pev_rendercolor, {HWN_COLOR_PRIMARY_F});
    set_pev(this, pev_health, NPC_Health);
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 12.0});
    set_pev(this, pev_maxspeed, NPC_Speed);

    @Entity_FindEnemy(this);

    new ParticleSystem:pParticlesSystem = CE_GetMember(this, m_pParticlesSystem);
    ParticleSystem_Activate(pParticlesSystem);
}

@Entity_Killed(this) {
    @Entity_DisappearEffect(this);

    new ParticleSystem:pParticlesSystem = CE_GetMember(this, m_pParticlesSystem);
    ParticleSystem_Deactivate(pParticlesSystem);
}

@Entity_Remove(this) {
    new ParticleSystem:pParticlesSystem = CE_GetMember(this, m_pParticlesSystem);
    ParticleSystem_Destroy(pParticlesSystem);
}

@Entity_Think(this) {
    UTIL_SetSequence(this, Sequence_Idle);
}

@Entity_AIThink(this) {
    CE_CallBaseMethod();

    static Float:flLastThink; pev(this, pev_ltime, flLastThink);
    static Float:flGameTime; flGameTime = get_gametime();

    static pEnemy; pEnemy = pev(this, pev_enemy);
    if (IS_PLAYER(pEnemy) && !is_user_alive(pEnemy)) {
        @Entity_Revenge(this, pEnemy);
    }

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    static Float:flReleaseAttack; flReleaseAttack = CE_GetMember(this, m_flReleaseAttack);
    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

    if (!flReleaseAttack && xs_vec_len(vecVelocity) > 50.0) {
        static Float:flNextMoan; flNextMoan = CE_GetMember(this, m_flNextMoan);
        if (flNextMoan <= flGameTime) {
            CE_CallMethod(this, EmitVoice, g_szSndIdle[random(sizeof(g_szSndIdle))], 4.0);
            CE_SetMember(this, m_flNextMoan, flGameTime + random_float(4.0, 6.0));
        }
    }
}

@Entity_Hit(this, Float:flDamage, Float:flAttackRange, Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_alive(pPlayer)) continue;
        if (entity_range(this, pPlayer) > 128.0) continue;

        PlayerEffect_Set(pPlayer, "hwn-fear", true, 5.0);
    }
}

@Entity_StartAttack(this, Float:flDamage, Float:flAttackRange, Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    CE_CallBaseMethod(flDamage, flAttackRange, vecHitOffset, flAttackDelay, pEnemy);
    CE_CallMethod(this, EmitVoice, g_szSndAttack[random(sizeof(g_szSndAttack))], 1.0);
}

@Entity_ReleaseAttack(this, Float:flDamage, Float:flAttackRange, Float:vecHitOffset[3], Float:flAttackDelay, pEnemy) {
    CE_CallBaseMethod(flDamage, flAttackRange, vecHitOffset, flAttackDelay, pEnemy);
}

bool:@Entity_IsValidEnemy(this, pEnemy) {
    if (!IS_PLAYER(pEnemy)) return false;
    if (Hwn_Stun_Get(pEnemy)) return false;

    return CE_CallBaseMethod(pEnemy);
}

@Entity_ProcessGoal(this) {
    if (CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3];
        CE_GetMemberVec(this, m_vecGoal, vecGoal);
        CE_DeleteMember(this, m_vecGoal);
        CE_CallMethod(this, SetTarget, vecGoal);
    }
}

@Entity_UpdateGoal(this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);


    if (flNextAttack <= flGameTime) {
        CE_CallBaseMethod();

        if (!CE_HasMember(this, m_vecGoal)) {
            CE_SetMember(this, m_flNextAttack, flGameTime + 10.0);
        }
    }

    if (!CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3];
        CE_GetMemberVec(this, CE_MEMBER_ORIGIN, vecGoal);
        CE_SetMemberVec(this, m_vecGoal, vecGoal);
    }
}

@Entity_DisappearEffect(this) {
    emit_sound(this, CHAN_BODY, g_szSndDisappeared, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_Revenge(this, pTarget) {
    new pKiller = g_rgpPlayerKiller[pTarget];

    if (pKiller) {
        if (pKiller == pTarget) {
            pKiller = 0;
        }

        new pBoss = 0;
        Hwn_Bosses_GetCurrent(pBoss);
        if (pKiller == pBoss) {
            pKiller = 0;
        }
    }

    if (!CE_CallMethod(this, IsValidEnemy, pKiller)) {
        pKiller = 0;
    }

    set_pev(this, pev_enemy, pKiller);
}

@Entity_FindEnemy(this) {
    new pClosestPlayer = 0;
    new Float:flClosestPlayerDistance = -1.0;

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_alive(pPlayer)) continue;

        static Float:flDistance; flDistance = entity_range(this, pPlayer);

        if (flClosestPlayerDistance < 0.0 || flDistance < flClosestPlayerDistance) {
            flClosestPlayerDistance = flDistance;
            pClosestPlayer = pPlayer;
        }
    }

    if (pClosestPlayer) {
        set_pev(this, pev_enemy, pClosestPlayer);
    }

    return pClosestPlayer;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    g_rgpPlayerKiller[pPlayer] = pKiller;
}
