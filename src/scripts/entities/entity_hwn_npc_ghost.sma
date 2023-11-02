#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_particles>

#include <hwn>
#include <hwn_utils>
#include <hwn_npc_stocks>

#define PLUGIN "[Custom Entity] Hwn NPC Ghost"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_ghost"

#define m_flDamage "flDamage"
#define m_vecGoal "vecGoal"
#define m_vecTarget "vecTarget"
#define m_flReleaseHit "flReleaseHit"
#define m_flTargetArrivalTime "flTargetArrivalTime"
#define m_flNextAIThink "flNextAIThink"
#define m_flNextAttack "flNextAttack"
#define m_flNextMoan "flNextMoan"
#define m_pKiller "pKiller"
#define m_pParticle "pParticle"

enum _:Sequence {
    Sequence_Idle = 0
};

const Float:NPC_Health = 1.0;
const Float:NPC_Speed = 100.0; // for jump velocity
const Float:NPC_Damage = 20.0;
const Float:NPC_HitRange = 32.0;
const Float:NPC_HitDelay = 0.25;
const Float:NPC_ViewRange = 1024.0;
const Float:NPC_TargetUpdateRate = 1.0;

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

new g_particlesEnabled;

new g_rgpPlayerKiller[MAX_PLAYERS + 1];

public plugin_precache() {
    precache_sound(g_szSndDisappeared);

    for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
        precache_sound(g_szSndAttack[i]);
    }

    for (new i = 0; i < sizeof(g_szSndIdle); ++i) {
        precache_sound(g_szSndIdle[i]);
    }

    CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/npc/ghost_v3.mdl",
        .vecMins = Float:{-12.0, -12.0, -32.0},
        .vecMaxs = Float:{12.0, 12.0, 32.0},
        .flLifeTime = HWN_NPC_LIFE_TIME,
        .flRespawnTime = HWN_NPC_RESPAWN_TIME,
        .iPreset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_InitPhysics, ENTITY_NAME, "@Entity_InitPhysics");
    CE_RegisterHook(CEFunction_Restart, ENTITY_NAME, "@Entity_Restart");
    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
}

public Hwn_Fw_ConfigLoaded() {
    g_particlesEnabled = get_cvar_num("hwn_enable_particles");
}

/*--------------------------------[ Hooks ]--------------------------------*/

@Entity_Restart(this) {
    @Entity_ResetPath(this);
}

@Entity_Spawned(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flDamage, NPC_Damage);
    CE_SetMember(this, m_flNextAttack, 0.0);
    CE_SetMember(this, m_flReleaseHit, 0.0);
    CE_SetMember(this, m_flNextAIThink, flGameTime);
    CE_SetMember(this, m_flNextMoan, flGameTime);
    CE_SetMember(this, m_flTargetArrivalTime, 0.0);
    CE_DeleteMember(this, m_vecGoal);
    CE_DeleteMember(this, m_vecTarget);
    CE_SetMember(this, m_pKiller, 0);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 1.0);
    set_pev(this, pev_rendercolor, {HWN_COLOR_PRIMARY_F});
    set_pev(this, pev_health, NPC_Health);
    set_pev(this, pev_takedamage, DAMAGE_AIM);
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 12.0});
    set_pev(this, pev_maxspeed, NPC_Speed);
    set_pev(this, pev_enemy, 0);
    set_pev(this, pev_framerate, 1.0);

    @Entity_CreateParticles(this);

    @Entity_FindEnemy(this);

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
        set_pev(this, pev_nextthink, flGameTime + 0.1);

        CE_SetMember(this, m_flNextAIThink, flGameTime + 0.1);

        // cancel first kill function to play duing animation
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

@Entity_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(this, pev_takedamage, DAMAGE_AIM);

    return PLUGIN_HANDLED;
}

@Entity_Killed(this) {
    @Entity_ResetPath(this);
    @Entity_DisappearEffect(this);
    @Entity_RemoveParticles(this);
}

@Entity_Remove(this) {
    @Entity_ResetPath(this);
    @Entity_RemoveParticles(this);
}

@Entity_Think(this) {
    if (!g_particlesEnabled) {
        @Entity_RemoveParticles(this);
    }

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

    UTIL_SetSequence(this, Sequence_Idle);

    set_pev(this, pev_ltime, flGameTime);
    set_pev(this, pev_nextthink, flGameTime + 0.01);
}

@Entity_AIThink(this) {
    static pEnemy; pEnemy = pev(this, pev_enemy);

    if (!NPC_IsValidEnemy(pEnemy)) {
        if (IS_PLAYER(pEnemy) && !is_user_alive(pEnemy)) {
            @Entity_Revenge(this, pEnemy);
        } else {
            set_pev(this, pev_deadflag, DEAD_DYING);
        }
    }

    static Float:flLastThink;
    pev(this, pev_ltime, flLastThink);

    static Float:flGameTime; flGameTime = get_gametime();

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    static Float:flHitRange; flHitRange = NPC_HitRange;
    static Float:flHitDelay; flHitDelay = NPC_HitDelay;

    static Float:flReleaseHit; flReleaseHit = CE_GetMember(this, m_flReleaseHit);
    if (!flReleaseHit) {
        static Float:flNextAttack; flNextAttack = CE_GetMember(this, m_flNextAttack);
        if (flNextAttack <= flGameTime) {
            static pEnemy; pEnemy = NPC_GetEnemy(this);
            if (pEnemy && NPC_CanHit(this, pEnemy, flHitRange)) {
                CE_SetMember(this, m_flReleaseHit, flGameTime + flHitDelay);

                static Float:vecTargetVelocity[3];
                pev(pEnemy, pev_velocity, vecTargetVelocity);
                if (xs_vec_len(vecTargetVelocity) < flHitRange) {
                    NPC_StopMovement(this);
                }

                @Entity_EmitVoice(this, g_szSndAttack[random(sizeof(g_szSndAttack))], 1.0);
            }
        }
    } else if (flReleaseHit <= flGameTime) {
        static pEnemy; pEnemy = NPC_GetEnemy(this);
        
        if (pEnemy) {
            static Float:flDamage; flDamage = CE_GetMember(this, m_flDamage);
            ExecuteHamB(Ham_TakeDamage, pEnemy, this, this, flDamage, DMG_GENERIC);
            CE_SetMember(this, m_flReleaseHit, 0.0);
            CE_SetMember(this, m_flNextAttack, flGameTime + 3.0);
        }
    }

    @Entity_UpdateGoal(this);
    @Entity_UpdateTarget(this);

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    if (!flReleaseHit && xs_vec_len(vecVelocity) > 50.0) {
        static Float:flNextMoan; flNextMoan = CE_GetMember(this, m_flNextMoan);
        if (flNextMoan <= flGameTime) {
            @Entity_EmitVoice(this, g_szSndIdle[random(sizeof(g_szSndIdle))], 4.0);
            CE_SetMember(this, m_flNextMoan, flGameTime + random_float(4.0, 6.0));
        }
    }
}

@Entity_MoveTo(this, const Float:vecTarget[3]) {
    NPC_MoveTo(this, vecTarget);
}

@Entity_EmitVoice(this, const szSound[], Float:flDuration) {
    emit_sound(this, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_UpdateGoal(this) {
    new pEnemy = NPC_GetEnemy(this);

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

    if (CE_HasMember(this, m_vecGoal)) {
        static Float:vecGoal[3];
        CE_GetMemberVec(this, m_vecGoal, vecGoal);
        CE_DeleteMember(this, m_vecGoal);
        @Entity_SetTarget(this, vecGoal);
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

@Entity_ResetPath(this) {
    CE_DeleteMember(this, m_vecTarget);
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

    if (!NPC_IsValidEnemy(pKiller)) {
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

@Entity_CreateParticles(this) {
    new pParticle = CE_GetMember(this, m_pParticle);
    if (pParticle) return;
    
    pParticle = Particles_Spawn("magic_glow", Float:{0.0, 0.0, 0.0}, 0.0);
    set_pev(pParticle, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(pParticle, pev_aiment, this);
    CE_SetMember(this, m_pParticle, pParticle);
}

@Entity_RemoveParticles(this) {
    new pParticle = CE_GetMember(this, m_pParticle);
    if (!pParticle) return;

    Particles_Remove(pParticle);
    CE_SetMember(this, m_pParticle, 0);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    g_rgpPlayerKiller[pPlayer] = pKiller;
}
