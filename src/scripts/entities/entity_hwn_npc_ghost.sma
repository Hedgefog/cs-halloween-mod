#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_particles>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN "[Custom Entity] Hwn NPC Ghost"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_ghost"

const Float:NPC_Speed = 100.0;
const Float:NPC_Damage = 20.0;
const Float:NPC_HitRange = 32.0;
const Float:NPC_HitDelay = 3.0;

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
        .fLifeTime = 30.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
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

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    g_rgpPlayerKiller[pPlayer] = pKiller;
}

@Entity_Spawn(this) {
    NPC_Create(this);

    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(this, pev_framerate, 1.0);
    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 1.0);
    set_pev(this, pev_rendercolor, {HWN_COLOR_PRIMARY_F});
    set_pev(this, pev_health, 1);

    engfunc(EngFunc_SetSize, this, {-12.0, -12.0, -32.0}, {12.0, 12.0, 32.0});

    new pEnemy = NPC_GetEnemy(this);
    if (!pEnemy) {
        NPC_FindEnemy(this, _, .reachableOnly = false, .visibleOnly = false, .allowMonsters = false);
    }

    @Entity_CreateParticles(this);

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Remove(this) {
    @Entity_RemoveParticles(this);
    NPC_Destroy(this);
}

@Entity_Killed(this) {
    @Entity_RemoveParticles(this);
    emit_sound(this, CHAN_BODY, g_szSndDisappeared, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_Think(this) {
    if (!g_particlesEnabled) {
        @Entity_RemoveParticles(this);
    }

    if (pev(this, pev_deadflag) == DEAD_NO) {
        new pEnemy = pev(this, pev_enemy);

        if (NPC_IsValidEnemy(pEnemy)) {
            @Entity_Attack(this, pEnemy);
        } else if (IS_PLAYER(pEnemy) && !is_user_alive(pEnemy)) {
            @Entity_Revenge(this, pEnemy);
        } else {
            CE_Kill(this);
        }
    }

    set_pev(this, pev_nextthink, get_gametime() + Hwn_GetUpdateRate());
}

@Entity_Attack(this, pTarget) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    pev(pTarget, pev_origin, vecTarget);

    if (get_distance_f(vecOrigin, vecTarget) <= NPC_HitRange) {
        if (NPC_CanHit(this, pTarget, NPC_HitRange)) {
            NPC_EmitVoice(this, g_szSndAttack[random(sizeof(g_szSndAttack))], .supercede = true);
            NPC_Hit(this, NPC_Damage, NPC_HitRange, NPC_HitDelay);
        }

        set_pev(this, pev_velocity, Float:{0.0, 0.0, 0.0});
    } else {
        if (random(100) < 10) {
            NPC_EmitVoice(this, g_szSndIdle[random(sizeof(g_szSndIdle))], 4.0, _, 0.5);
        }

        static Float:vecDirection[3];
        xs_vec_sub(vecTarget, vecOrigin, vecDirection);
        xs_vec_normalize(vecDirection, vecDirection);

        static Float:vecVelocity[3];
        xs_vec_mul_scalar(vecDirection, NPC_Speed, vecVelocity);
        set_pev(this, pev_velocity, vecVelocity);

        xs_vec_mul_scalar(vecDirection, NPC_HitRange, vecDirection);
        xs_vec_sub(vecTarget, vecDirection, vecTarget);
        UTIL_TurnTo(this, vecTarget);
    }
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

    set_pev(this, pev_enemy, pKiller);
}

@Entity_CreateParticles(this) {
    new pParticle = CE_GetMember(this, "pParticle");
    if (pParticle) {
        return;
    }
    
    pParticle = Particles_Spawn("magic_glow", Float:{0.0, 0.0, 0.0}, 0.0);
    set_pev(pParticle, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(pParticle, pev_aiment, this);
    CE_SetMember(this, "pParticle", pParticle);
}

@Entity_RemoveParticles(this) {
    new pParticle = CE_GetMember(this, "pParticle");
    if (!pParticle) {
        return;
    }

    Particles_Remove(pParticle);
    CE_SetMember(this, "pParticle", 0);
}
