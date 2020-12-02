#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_particles>

#define PLUGIN "[Particle] Magic Glow"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

public plugin_precache()
{
    new sprites[API_PARTICLES_MAX_SPRITES];
    sprites[0] = precache_model("sprites/muz2.spr");
    sprites[1] = precache_model("sprites/muz3.spr");
    sprites[2] = precache_model("sprites/muz4.spr");
    sprites[3] = precache_model("sprites/muz5.spr");
    sprites[4] = precache_model("sprites/muz6.spr");
    sprites[5] = precache_model("sprites/muz7.spr");
    sprites[6] = precache_model("sprites/muz8.spr");

    Particles_Register(
        .szName = "magic_glow",
        .szTransformCallback = "Transform",
        .sprites = sprites,
        .fLifeTime = 0.8,
        .fScale = 0.05,
        .renderMode = kRenderTransAdd,
        .fRenderAmt = 255.0,
        .spawnCount = 1
    );

    new purpleSprites[API_PARTICLES_MAX_SPRITES];
    purpleSprites[0] = precache_model("sprites/muz4.spr");
    purpleSprites[1] = precache_model("sprites/muz7.spr");

    Particles_Register(
        .szName = "magic_glow_purple",
        .szTransformCallback = "Transform",
        .sprites = purpleSprites,
        .fLifeTime = 0.8,
        .fScale = 0.05,
        .renderMode = kRenderTransAdd,
        .fRenderAmt = 255.0,
        .spawnCount = 1
    );
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

public Transform(Float:vOrigin[3], Float:vVelocity[3])
{
    static Float:vRandom[3];

    {
        UTIL_RandomVector(-16.0, 16.0, vRandom);
        xs_vec_add(vOrigin, vRandom, vOrigin);
    }

    {
        UTIL_RandomVector(0.0, 32.0, vVelocity);
    }
}

stock UTIL_RandomVector(const Float:fMin, const Float:fMax, Float:vOut[3])
{
    for (new i = 0; i < 3; ++i) {
        vOut[i] = random_float(fMin, fMax);
    }
}
