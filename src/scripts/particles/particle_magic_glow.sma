#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_particles>

#define PLUGIN "[Particle] Magic Glow"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

new Array:g_sprites;

public plugin_precache()
{
	g_sprites = ArrayCreate();
	ArrayPushCell(g_sprites, precache_model("sprites/muz2.spr"));
	ArrayPushCell(g_sprites, precache_model("sprites/muz3.spr"));
	ArrayPushCell(g_sprites, precache_model("sprites/muz4.spr"));
	ArrayPushCell(g_sprites, precache_model("sprites/muz5.spr"));
	ArrayPushCell(g_sprites, precache_model("sprites/muz6.spr"));
	ArrayPushCell(g_sprites, precache_model("sprites/muz7.spr"));
	ArrayPushCell(g_sprites, precache_model("sprites/muz8.spr"));
	
	Particles_Register(
		.szName = "magic_glow",
		.szTransformCallback = "TransformParticle",
		.sprites = g_sprites,
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

public plugin_end()
{
	ArrayDestroy(g_sprites);
}

public TransformParticle(Float:vOrigin[3], Float:vVelocity[3])
{
	static Float:vRandom[3];

	{
		UTIL_RandomVector(-16.0, 16.0, vRandom);
		xs_vec_add(vOrigin, vRandom, vOrigin);
	}

	{
		UTIL_RandomVector(0.0, 1.0, vVelocity);
	}
}

stock UTIL_RandomVector(Float:fMin, Float:fMax, Float:vOut[3])
{
	for (new i = 0; i < 3; ++i) {
		vOut[i] = random_float(fMin, fMax);
	}
}
