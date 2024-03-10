#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_particles>

#include <hwn_utils>

#define PLUGIN "[Particle] Magic Trail"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define EFFECT_NAME "hwn-magic-trail"

#define EFFECT_PARTICLE_LIFETIME 1.5
#define EFFECT_EMIT_RATE 0.125
#define EFFECT_MAX_PARTICLES floatround(EFFECT_PARTICLE_LIFETIME / EFFECT_EMIT_RATE, floatround_ceil)
#define EFFECT_PARTICLE_SCALE 0.065
#define EFFECT_PARTICLE_AMT 220.0
#define EFFECT_RADIUS 4.0
#define EFFECT_PARTICLE_SPEED 10.0
#define EFFECT_PARTICLE_EMIT_AMOUNT 2

new g_szParticleModel[] = "sprites/animglow01.spr";

new const Float:g_rglfColors[][3] = {
    { 200.0, 75.0, 130.0 },
    { 80.0, 65.0, 150.0 },
    { 70.0, 10.0, 185.0 },
    { 105.0, 75.0, 120.0 },
    { 100.0, 50.0, 150.0 },
    { 230.0, 75.0, 90.0 }
};

public plugin_precache() {
    precache_model(g_szParticleModel);
    
    ParticleEffect_Register(EFFECT_NAME, EFFECT_EMIT_RATE, EFFECT_PARTICLE_LIFETIME, EFFECT_MAX_PARTICLES, EFFECT_PARTICLE_EMIT_AMOUNT);
    ParticleEffect_RegisterHook(EFFECT_NAME, ParticleEffectHook_Particle_Init, "@Effect_Particle_Init");
    ParticleEffect_RegisterHook(EFFECT_NAME, ParticleEffectHook_Particle_Think, "@Effect_Particle_Think");
    ParticleEffect_RegisterHook(EFFECT_NAME, ParticleEffectHook_Particle_EntityInit, "@Effect_Particle_EntityInit");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

@Effect_Particle_Init(Particle:this) {
    static Float:vecOrigin[3];
    xs_vec_set(vecOrigin, random_float(-EFFECT_RADIUS, EFFECT_RADIUS), random_float(-EFFECT_RADIUS, EFFECT_RADIUS), random_float(-EFFECT_RADIUS, EFFECT_RADIUS));
    Particle_SetOrigin(this, vecOrigin);
}

@Effect_Particle_Think(Particle:this) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flCreatedTime; flCreatedTime = Particle_GetCreatedTime(this);
    static Float:flKillTime; flKillTime = Particle_GetKillTime(this);
    static Float:flProgress; flProgress = (flGameTime - flCreatedTime) / (flKillTime - flCreatedTime);

    static Float:vecVelocity[3];
    vecVelocity[0] = random_float(-EFFECT_RADIUS, EFFECT_RADIUS);
    vecVelocity[1] = random_float(-EFFECT_RADIUS, EFFECT_RADIUS);
    vecVelocity[2] = EFFECT_PARTICLE_SPEED;

    Particle_SetVelocity(this, vecVelocity);

    new pEntity = Particle_GetEntity(this);

    static Float:flRenderAmt; flRenderAmt = EFFECT_PARTICLE_AMT;
    if (flProgress <= 0.25) {
        flRenderAmt *= flProgress / 0.25;
    } else if (flProgress > 0.75) {
        flRenderAmt *= (1.0 - flProgress) / 0.25;
    }

    set_pev(pEntity, pev_renderamt, flRenderAmt);
}

@Effect_Particle_EntityInit(Particle:this, pEntity) {
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

    set_pev(pEntity, pev_rendercolor, g_rglfColors[random(sizeof(g_rglfColors))]);
}
