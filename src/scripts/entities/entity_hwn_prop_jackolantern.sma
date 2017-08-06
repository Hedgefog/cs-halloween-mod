#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Prop Jack'O'Lantern"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_prop_jackolantern"

new Float:g_fThinkDelay;

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

public plugin_precache()
{	
	CE_Register(
		.szName = ENTITY_NAME,
		.modelIndex = precache_model("models/hwn/props/jackolantern.mdl"),
		.vMins = Float:{-16.0, -16.0, 0.0},
		.vMaxs = Float:{16.0, 16.0, 48.0},
		.preset = CEPreset_Prop
	);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");	
	CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
}

public OnSpawn(ent)
{
	set_pev(ent, pev_body, random(2));
	set_pev(ent, pev_movetype, MOVETYPE_FLY);
	engfunc(EngFunc_DropToFloor, ent);
	dllfunc(DLLFunc_Think, ent);
	
	if (~pev(ent, pev_spawnflags) & (1<<0)) {
		TaskThink(ent);
	}
}

public OnRemove(ent)
{
	remove_task(ent);
}

/*------------[ Tasks ]------------*/

public TaskThink(ent)
{
	if (!pev_valid(ent)) {
		return;
	}

	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	vOrigin[2] += 16.0;
	
	UTIL_Message_Dlight(vOrigin, 8, {64, 52, 4}, UTIL_DelayToLifeTime(g_fThinkDelay), 0);
	
	set_task(g_fThinkDelay, "TaskThink", ent);
}