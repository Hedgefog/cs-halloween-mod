#include <amxmodx>
#include <xs>

#include <api_particles>

#define PLUGIN "[Particle] Magic Glow"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

public plugin_precache() {
    new rgiSprites[API_PARTICLES_MAX_SPRITES];
    rgiSprites[0] = precache_model("sprites/muz2.spr");
    rgiSprites[1] = precache_model("sprites/muz3.spr");
    rgiSprites[2] = precache_model("sprites/muz4.spr");
    rgiSprites[3] = precache_model("sprites/muz5.spr");
    rgiSprites[4] = precache_model("sprites/muz6.spr");
    rgiSprites[5] = precache_model("sprites/muz7.spr");
    rgiSprites[6] = precache_model("sprites/muz8.spr");

    Particles_Register(
        .szName = "magic_glow",
        .szTransformCallback = "Transform",
        .sprites = rgiSprites,
        .flLifeTime = 0.8,
        .flScale = 0.05,
        .renderMode = kRenderTransAdd,
        .flRenderAmt = 255.0,
        .spawnCount = 1
    );

    new rgiPurpleSprites[API_PARTICLES_MAX_SPRITES];
    rgiPurpleSprites[0] = precache_model("sprites/muz4.spr");
    rgiPurpleSprites[1] = precache_model("sprites/muz7.spr");

    Particles_Register(
        .szName = "magic_glow_purple",
        .szTransformCallback = "Transform",
        .sprites = rgiPurpleSprites,
        .flLifeTime = 0.8,
        .flScale = 0.05,
        .renderMode = kRenderTransAdd,
        .flRenderAmt = 255.0,
        .spawnCount = 1
    );
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

public Transform(Float:vecOrigin[3], Float:vecVelocity[3]) {
    static Float:vecRandom[3];
    UTIL_RandomVector(-16.0, 16.0, vecRandom);
    xs_vec_add(vecOrigin, vecRandom, vecOrigin);

    UTIL_RandomVector(0.0, 32.0, vecVelocity);
}

stock UTIL_RandomVector(const Float:flMin, const Float:flMax, Float:vecOut[3]) {
    for (new i = 0; i < 3; ++i) random_float(flMin, flMax);
}
