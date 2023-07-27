#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_particles>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN    "[Custom Entity] Hwn NPC Ghost"
#define AUTHOR    "Hedgehog Fog"

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

new g_rgPlayerKiller[MAX_PLAYERS + 1];

new bool:g_bIsPrecaching;

public plugin_precache() {
    g_bIsPrecaching = true;

    precache_sound(g_szSndDisappeared);

    for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
        precache_sound(g_szSndAttack[i]);
    }

    for (new i = 0; i < sizeof(g_szSndIdle); ++i) {
        precache_sound(g_szSndIdle[i]);
    }

    CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/ghost_v3.mdl"),
        .vMins = Float:{-12.0, -12.0, -32.0},
        .vMaxs = Float:{12.0, 12.0, 32.0},
        .fLifeTime = 30.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");
}

public plugin_init() {
    g_bIsPrecaching = false;

    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded() {
    g_particlesEnabled = get_cvar_num("hwn_enable_particles");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(pEntity) {
    NPC_Create(pEntity);

    set_pev(pEntity, pev_solid, SOLID_TRIGGER);
    set_pev(pEntity, pev_movetype, MOVETYPE_NOCLIP);

    set_pev(pEntity, pev_framerate, 1.0);

    set_pev(pEntity, pev_rendermode, kRenderNormal);
    set_pev(pEntity, pev_renderfx, kRenderFxGlowShell);
    set_pev(pEntity, pev_renderamt, 1.0);
    set_pev(pEntity, pev_rendercolor, {HWN_COLOR_PRIMARY_F});

    set_pev(pEntity, pev_health, 1);

    new pEnemy = NPC_GetEnemy(pEntity);
    if (!pEnemy) {
        NPC_FindEnemy(pEntity, _, .reachableOnly = false, .visibleOnly = false, .allowMonsters = false);
    }

    Task_Think(pEntity);
}

public OnRemove(pEntity) {
    remove_task(pEntity);
    RemoveParticles(pEntity);
    NPC_Destroy(pEntity);
}

public OnKilled(pEntity) {
    RemoveParticles(pEntity);
    emit_sound(pEntity, CHAN_BODY, g_szSndDisappeared, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    g_rgPlayerKiller[pPlayer] = pKiller;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Think(pEntity) {
    if (!pev_valid(pEntity)) {
        return;
    }

    if (pev(pEntity, pev_deadflag) == DEAD_NO)
    {
        UpdateParticles(pEntity);

        new pEnemy = pev(pEntity, pev_enemy);

        if (NPC_IsValidEnemy(pEnemy)) {
            Attack(pEntity, pEnemy);
        } else if (IS_PLAYER(pEnemy) && !is_user_alive(pEnemy)) {
            Revenge(pEntity, pEnemy);
        } else {
            CE_Kill(pEntity);
        }
    }

    set_task(Hwn_GetUpdateRate(), "Task_Think", pEntity);
}

Attack(pEntity, pTarget) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    pev(pTarget, pev_origin, vecTarget);

    if (get_distance_f(vecOrigin, vecTarget) <= NPC_HitRange)
    {
        if (NPC_CanHit(pEntity, pTarget, NPC_HitRange)) {
            NPC_EmitVoice(pEntity, g_szSndAttack[random(sizeof(g_szSndAttack))], .supercede = true);
            NPC_Hit(pEntity, NPC_Damage, NPC_HitRange, NPC_HitDelay);
        }

        set_pev(pEntity, pev_velocity, Float:{0.0, 0.0, 0.0});
    }
    else
    {
        if (random(100) < 10) {
            NPC_EmitVoice(pEntity, g_szSndIdle[random(sizeof(g_szSndIdle))], 4.0, _, 0.5);
        }

        static Float:vecDirection[3];
        xs_vec_sub(vecTarget, vecOrigin, vecDirection);
        xs_vec_normalize(vecDirection, vecDirection);

        static Float:vecVelocity[3];
        xs_vec_mul_scalar(vecDirection, NPC_Speed, vecVelocity);
        set_pev(pEntity, pev_velocity, vecVelocity);

        xs_vec_mul_scalar(vecDirection, NPC_HitRange, vecDirection);
        xs_vec_sub(vecTarget, vecDirection, vecTarget);
        UTIL_TurnTo(pEntity, vecTarget);
    }
}

Revenge(pEntity, pTarget) {
    new pKiller = g_rgPlayerKiller[pTarget];
    if (pKiller == pTarget) {
        pKiller = 0;
    }

    new pBoss = 0;
    Hwn_Bosses_GetCurrent(pBoss);
    if (pKiller == pBoss) {
        pKiller = 0;
    }

    NPC_SetEnemy(pEntity, pKiller);
}

UpdateParticles(pEntity) {
    if (!g_particlesEnabled) {
        return;
    }

    if (g_bIsPrecaching) {
        return;
    }

    if (pev(pEntity, pev_iuser4)) {
        return;
    }

    new pParticle = Particles_Spawn("magic_glow", Float:{0.0, 0.0, 0.0}, 0.0);
    if (!pParticle) {
        return;
    }

    set_pev(pParticle, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(pParticle, pev_aiment, pEntity);
    set_pev(pEntity, pev_iuser4, pParticle);
}

RemoveParticles(pEntity) {
    if (!pev(pEntity, pev_iuser4)) {
        return;
    }

    Particles_Remove(pev(pEntity, pev_iuser4));
    set_pev(pEntity, pev_iuser4, 0);
}