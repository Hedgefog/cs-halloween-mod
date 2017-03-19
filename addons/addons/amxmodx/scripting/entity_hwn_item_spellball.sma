#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Item Spellball"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_spellball"

new g_sprSmoke;

new Float:g_fThinkDelay;

new g_ceHandler;

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
	
	RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
}

public plugin_precache()
{
	g_ceHandler = CE_Register(
		.szName = ENTITY_NAME,
		.vMins = Float:{-8.0, -8.0, -8.0},
		.vMaxs = Float:{8.0, 8.0, 8.0},
		.fLifeTime = 30.0,		
		.preset = CEPreset_None
	);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
	CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
	
	g_sprSmoke = precache_model("sprites/black_smoke1.spr");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
	set_pev(ent, pev_rendermode, kRenderTransAdd);
	set_pev(ent, pev_renderamt, 255.0);
	set_pev(ent, pev_gravity, 0.25);
	set_pev(ent, pev_health, 1.0);
	
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	
	TaskThink(ent);
}

public OnRemove(ent)
{
	remove_task(ent);
}

public OnTouch(ent, target)
{
	if (!pev_valid(ent)) {
		return;
	}

	if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
		return;
	}
	
	if (target == pev(ent, pev_owner)) {
		return;
	}

	ExecuteHamB(Ham_Killed, ent, 0, 0);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskThink(ent)
{
	if (!pev_valid(ent)) {
		return;
	}
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	
	//Fix for smoke origin
	{
		static Float:vVelocity[3];
		pev(ent, pev_velocity, vVelocity);
		
		static Float:vSub[3];
		xs_vec_normalize(vVelocity, vSub);
		xs_vec_mul_scalar(vSub, 32.0, vSub);
		vSub[2] += 18.0;
		
		xs_vec_sub(vOrigin, vSub, vOrigin);
	}
	
	static color[3];
	pev(ent, pev_rendercolor, color);
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
	write_byte(TE_SMOKE);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]);
	write_short(g_sprSmoke);
	write_byte(10);
	write_byte(90);
	message_end();
	
	UTIL_Message_Dlight(vOrigin, 16, color, UTIL_DelayToLifeTime(g_fThinkDelay), 0);
	
	set_task(g_fThinkDelay, "TaskThink", ent);
}