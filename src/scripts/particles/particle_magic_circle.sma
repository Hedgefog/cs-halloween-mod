#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_particles>

#define PLUGIN "Particles Test"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define EFFECT_NAME "hwn-magic-circle"

#define EFFECT_PARTICLE_EMIT_NUM 2
#define EFFECT_ROTATION_SPEED 90.0
#define EFFECT_DURATION (360.0 / EFFECT_ROTATION_SPEED / EFFECT_PARTICLE_EMIT_NUM)
#define EFFECT_EMIT_RATE (EFFECT_DURATION / 10 * EFFECT_PARTICLE_EMIT_NUM)
#define EFFECT_MAX_PARTICLES floatround(EFFECT_DURATION / EFFECT_EMIT_RATE * EFFECT_PARTICLE_EMIT_NUM, floatround_ceil)
#define EFFECT_PARTICLE_SCALE 0.065
#define EFFECT_PARTICLE_AMT 220.0

new const Float:g_rglfColors[][3] = {
    { 90.0, 240.0, 130.0 },
    { 185.0, 215.0, 180.0 },
    { 160.0, 250.0, 200.0 },
    { 210.0, 220.0, 195.0 }
};

new const Float:g_rglfRareColors[][3] = {
    { 200.0, 75.0, 130.0 },
    { 80.0, 65.0, 150.0 },
    { 70.0, 10.0, 185.0 },
    { 105.0, 75.0, 120.0 },
    { 100.0, 50.0, 150.0 },
    { 230.0, 75.0, 90.0 }
};

new const g_szTestModel[] = "models/w_backpack.mdl"
new g_szParticleModel[] = "sprites/animglow01.spr";

// new g_pTestEnt = -1;

public plugin_precache() {
    precache_model(g_szTestModel);
    precache_model(g_szParticleModel);

    ParticleEffect_Register(EFFECT_NAME, EFFECT_EMIT_RATE, EFFECT_DURATION, EFFECT_MAX_PARTICLES, EFFECT_PARTICLE_EMIT_NUM);
    ParticleEffect_RegisterHook(EFFECT_NAME, ParticleEffectHook_System_Init, "@Effect_System_Init");
    ParticleEffect_RegisterHook(EFFECT_NAME, ParticleEffectHook_Particle_Init, "@Effect_Particle_Init");
    ParticleEffect_RegisterHook(EFFECT_NAME, ParticleEffectHook_Particle_Think, "@Effect_Particle_Think");
    ParticleEffect_RegisterHook(EFFECT_NAME, ParticleEffectHook_Particle_EntityInit, "@Effect_Particle_EntityInit");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

@Effect_System_Init(ParticleSystem:this) {
    ParticleSystem_SetMember(this, "flRadius", 16.0);
    ParticleSystem_SetMember(this, "bRare", false);
}

@Effect_Particle_Init(Particle:this) {
    static ParticleSystem:sSystem; sSystem = Particle_GetSystem(this);
    static Float:flRadius; flRadius = ParticleSystem_GetMember(sSystem, "flRadius");
    static iBatchIndex; iBatchIndex = Particle_GetBatchIndex(this);
    static iDir; iDir = iBatchIndex % 2 ? -1 : 1;

    static Float:vecOffset[3];
    vecOffset[0] = -flRadius * floatcos(iDir * xs_deg2rad(90.0));
    vecOffset[1] = -flRadius * floatsin(iDir * xs_deg2rad(90.0));
    vecOffset[2] = 2.0;

    Particle_SetOrigin(this, vecOffset);
}

@Effect_Particle_Think(Particle:this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flCreatedTime; flCreatedTime = Particle_GetCreatedTime(this);
    static Float:flKillTime; flKillTime = Particle_GetKillTime(this);
    static Float:flLifeDelta; flLifeDelta = flGameTime - flCreatedTime;
    static ParticleSystem:sSystem; sSystem = Particle_GetSystem(this);
    static Float:flRadius; flRadius = ParticleSystem_GetMember(sSystem, "flRadius");
    static Float:flSpeed; flSpeed = xs_deg2rad(EFFECT_ROTATION_SPEED);
    static iBatchIndex; iBatchIndex = Particle_GetBatchIndex(this);
    static iDir; iDir = iBatchIndex % 2 ? -1 : 1;

    static Float:vecVelocity[3];
    vecVelocity[0] = -flRadius * flSpeed * iDir * floatcos(flSpeed * flLifeDelta);
    vecVelocity[1] = flRadius * flSpeed * iDir * floatsin(flSpeed * flLifeDelta);
    vecVelocity[2] = 0.0;

    Particle_SetVelocity(this, vecVelocity);
}

@Effect_Particle_EntityInit(Particle:this, pEntity) {
    static ParticleSystem:sSystem; sSystem = Particle_GetSystem(this);
    static iModelIndex; iModelIndex = engfunc(EngFunc_ModelIndex, g_szParticleModel);

    set_pev(pEntity, pev_rendermode, kRenderTransAdd);
    set_pev(pEntity, pev_renderfx, kRenderFxLightMultiplier);
    set_pev(pEntity, pev_scale, EFFECT_PARTICLE_SCALE);
    set_pev(pEntity, pev_modelindex, iModelIndex);
    set_pev(pEntity, pev_renderamt, EFFECT_PARTICLE_AMT);
    set_pev(pEntity, pev_animtime, get_gametime());
    set_pev(pEntity, pev_framerate, 1.0);
    set_pev(pEntity, pev_spawnflags, SF_SPRITE_STARTON);

    engfunc(EngFunc_SetModel, pEntity, g_szParticleModel);

    if (ParticleSystem_GetMember(sSystem, "bRare")) {
        set_pev(pEntity, pev_rendercolor, g_rglfRareColors[random(sizeof(g_rglfRareColors))]);
    } else {
        set_pev(pEntity, pev_rendercolor, g_rglfColors[random(sizeof(g_rglfColors))]);
    }
}
