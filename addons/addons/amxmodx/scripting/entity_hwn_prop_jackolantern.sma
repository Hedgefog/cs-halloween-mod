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
	
	RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "OnThink", .Post = 1);	
}

public OnSpawn(ent)
{
	set_pev(ent, pev_body, random(2));
	engfunc(EngFunc_DropToFloor, ent);
	dllfunc(DLLFunc_Think, ent);
}

/*------------[ Hooks ]------------*/

public OnThink(ent)
{
	if (!pev_valid(ent)) {
		return;
	}

	if (!CE_CheckAssociation(ent)) {
		return;
	}

	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	vOrigin[2] += 16.0;
	
	UTIL_Message_Dlight(vOrigin, 8, {64, 52, 4}, UTIL_DelayToLifeTime(g_fThinkDelay), 0);
	
	set_pev(ent, pev_nextthink, get_gametime() + g_fThinkDelay);
}