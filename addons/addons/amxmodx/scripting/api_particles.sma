#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#define PLUGIN "[API] Particles"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_TARGET_TICK 1000
#define TASKID_SUM_REMOVE_TARGET 2000
#define TASKID_SUM_REMOVE_PARTICLE 3000

new Trie:g_particles;
new Array:g_particlePluginID;
new Array:g_particleFuncID;
new Array:g_particleSprites;
new Array:g_particleLifeTime;
new Array:g_particleScale;
new Array:g_particleRenderMode;
new Array:g_particleRenderAmt;
new Array:g_particleSpawnCount;
new g_particleCount = 0;

new g_ptrTargetClassname;
new g_ptrParticleClassname;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	g_ptrTargetClassname = engfunc(EngFunc_AllocString, "info_target");
	g_ptrParticleClassname = engfunc(EngFunc_AllocString, "env_sprite");
}

public plugin_end()
{
	if (g_particleCount) {
		TrieDestroy(g_particles);
		ArrayDestroy(g_particlePluginID);
		ArrayDestroy(g_particleFuncID);
		ArrayDestroy(g_particleSprites);
		ArrayDestroy(g_particleLifeTime);
		ArrayDestroy(g_particleScale);
		ArrayDestroy(g_particleRenderMode);
		ArrayDestroy(g_particleRenderAmt);
		ArrayDestroy(g_particleSpawnCount);
	}
}

public plugin_natives()
{
	register_library("api_particles");
	register_native("Particles_Register", "Native_Register");
	register_native("Particles_Spawn", "Native_Spawn");
	register_native("Particles_Remove", "Native_Remove");
}

public Native_Register(pluginID, argc)
{
	new szName[32];
	get_string(1, szName, charsmax(szName));

	new szTransformCallback[32];
	get_string(2, szTransformCallback, charsmax(szTransformCallback));
	new funcID = get_func_id(szTransformCallback, pluginID);	
	
	new Array:sprites = any:get_param(3);
	new Float:fLifeTime = get_param_f(4);
	new Float:fScale = get_param_f(5);
	new renderMode = get_param(6);
	new Float:fRenderAmt = get_param_f(7);
	new spawnCount = get_param(8);

	RegisterParticle(szName, pluginID, funcID, sprites, fLifeTime, fScale, renderMode, fRenderAmt, spawnCount);
}

public Native_Spawn(pluginID, argc)
{
	new szName[32];
	get_string(1, szName, charsmax(szName));
	
	new Float:vOrigin[3];
	get_array_f(2, vOrigin, sizeof(vOrigin));
	
	new Float:fPlayTime = get_param_f(3);
	
	return SpawnParticles(szName, vOrigin, fPlayTime);
}

public Native_Remove(pluginID, argc)
{
	new ent = get_param(1);
	RemoveParticles(ent);
}

RegisterParticle(const szName[], pluginID, funcID, Array:sprites, Float:fLifeTime, Float:fScale, renderMode, Float:fRenderAmt, spawnCount)
{
	if (!g_particleCount) {
		g_particles = TrieCreate();
		g_particlePluginID = ArrayCreate();
		g_particleFuncID = ArrayCreate();
		g_particleSprites = ArrayCreate();
		g_particleLifeTime = ArrayCreate();
		g_particleScale = ArrayCreate();
		g_particleRenderMode = ArrayCreate();
		g_particleRenderAmt = ArrayCreate();
		g_particleSpawnCount = ArrayCreate();
	}

	new index = g_particleCount;

	TrieSetCell(g_particles, szName, index);
	ArrayPushCell(g_particlePluginID, pluginID);
	ArrayPushCell(g_particleFuncID, funcID);
	ArrayPushCell(g_particleLifeTime, fLifeTime);
	ArrayPushCell(g_particleScale, fScale);
	ArrayPushCell(g_particleRenderMode, renderMode);
	ArrayPushCell(g_particleRenderAmt, fRenderAmt);
	ArrayPushCell(g_particleSpawnCount, spawnCount);
	ArrayPushCell(g_particleSprites, sprites);
	
	g_particleCount++;
	
	return index;
}

SpawnParticles(const szName[], const Float:vOrigin[3], Float:fPlayTime)
{
	new index;
	TrieGetCell(g_particles, szName, index);

	new ent = engfunc(EngFunc_CreateNamedEntity, g_ptrTargetClassname);
	engfunc(EngFunc_SetOrigin, ent, vOrigin);
	dllfunc(DLLFunc_Spawn, ent);
	
	set_pev(ent, pev_iuser1, index);
	
	set_task(0.04, "TaskTargetTick", ent+TASKID_SUM_TARGET_TICK, _, _, "b");
	
	if (fPlayTime > 0.0) {
		set_task(fPlayTime, "TaskRemoveTarget", ent+TASKID_SUM_REMOVE_TARGET);	
	}
	
	return ent;
}

RemoveParticles(ent)
{
	remove_task(ent+TASKID_SUM_TARGET_TICK);
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
}

public TaskRemoveTarget(taskID)
{
	new ent = taskID - TASKID_SUM_REMOVE_TARGET;
	RemoveParticles(ent);
}

public TaskTargetTick(taskID)
{
	new ent = taskID - TASKID_SUM_TARGET_TICK;
	new index = pev(ent, pev_iuser1);

	new pluginID			= ArrayGetCell(g_particlePluginID, index);
	new funcID				= ArrayGetCell(g_particleFuncID, index);
	new Float:fLifeTime		= ArrayGetCell(g_particleLifeTime, index);
	new Float:fScale		= ArrayGetCell(g_particleScale, index);
	new renderMode			= ArrayGetCell(g_particleRenderMode, index);
	new Float:fRenderAmt	= ArrayGetCell(g_particleRenderAmt, index);
	new spawnCount			= ArrayGetCell(g_particleSpawnCount, index);
	new Array:sprites		= ArrayGetCell(g_particleSprites, index);

	static Float:vOrigin[3];
	static Float:vVelocity[3];
	
	for (new i = 0; i < spawnCount; ++i)
	{
		pev(ent, pev_origin, vOrigin);
		xs_vec_set(vVelocity, 0.0, 0.0, 0.0);
		
		if (callfunc_begin_i(funcID, pluginID) == 1) {
			callfunc_push_array(_:vOrigin, 3);
			callfunc_push_array(_:vVelocity, 3);
			callfunc_end();
		}
		
		static modelindex;
		{
			new size = ArraySize(sprites);
			modelindex = ArrayGetCell(sprites, random(size));
		}
		
		static particleEnt;
		{
			particleEnt = engfunc(EngFunc_CreateNamedEntity, g_ptrParticleClassname);
			engfunc(EngFunc_SetOrigin, particleEnt, vOrigin);	
			set_pev(particleEnt, pev_velocity, vVelocity);
			set_pev(particleEnt, pev_modelindex, modelindex);
			set_pev(particleEnt, pev_solid, SOLID_TRIGGER);
			set_pev(particleEnt, pev_movetype, MOVETYPE_NOCLIP);
			set_pev(particleEnt, pev_rendermode, renderMode);
			set_pev(particleEnt, pev_renderamt, fRenderAmt);
			set_pev(particleEnt, pev_scale, fScale);
			
			set_task(fLifeTime, "TaskRemoveParticle", particleEnt+TASKID_SUM_REMOVE_PARTICLE);
		}
	}
}

public TaskRemoveParticle(taskID)
{
	new ent = taskID - TASKID_SUM_REMOVE_PARTICLE;
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
}