#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Bucket"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_bucket"

enum Team
{
	Team_Undefined = 0,
	Team_Red,
	Team_Blue,
	Team_Spectators
};

new Float:g_vTeamColor[Team][3] = {
	{0.0, 0.0, 0.0},
	{128.0, 0.0, 0.0},
	{0.0, 0.0, 128.0},
	{128.0, 128.0, 128.0}
};

new Float:g_fNextCollectTime[33];

new g_sprBlood;
new g_sprBloodSpray;

new const g_szSndPointCollected[] = "hwn/misc/collected.wav";

new g_cvarBucketHealth;

new Float:g_fThinkDelay;

new g_maxPlayers;

public plugin_precache()
{
	g_sprBlood = precache_model("sprites/blood.spr");
	g_sprBloodSpray = precache_model("sprites/bloodspray.spr");
	precache_sound(g_szSndPointCollected);
	
	CE_Register(
		.szName = ENTITY_NAME,
		.modelIndex = precache_model("models/hwn/props/pumpkin_bucket.mdl"),
		.vMins = Float:{-28.0, -28.0, 0.0},
		.vMaxs = Float:{28.0, 28.0, 56.0},
		.preset = CEPreset_Prop
	);
	
	RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTakeDamage", .Post = 0);
	RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
	CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");
	CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
	
	g_cvarBucketHealth = register_cvar("hwn_bucket_health", "300");
}

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
	
	g_maxPlayers = get_maxplayers();
}

/*------------[ Hooks ]------------*/

public OnSpawn(ent)
{
	set_pev(ent, pev_solid, SOLID_BBOX);
	set_pev(ent, pev_movetype, MOVETYPE_FLY);
	set_pev(ent, pev_takedamage, DAMAGE_AIM);
	
	new team = pev(ent, pev_team);
	set_pev(ent, pev_renderfx, kRenderFxGlowShell);
	set_pev(ent, pev_renderamt, 0.125);	
	set_pev(ent, pev_rendercolor, g_vTeamColor[Team:team]);
	
	set_pev(ent, pev_health, float(get_pcvar_num(g_cvarBucketHealth)));
	
	engfunc(EngFunc_DropToFloor, ent);
	
	TaskThink(ent);
}

public OnRemove(ent)
{
	remove_task(ent);	
}

public OnTakeDamage(ent, inflictor, attacker, Float:fDamage)
{
	if (!attacker) {
		return HAM_IGNORED;
	}

	if (!CE_CheckAssociation(ent)) {
		return HAM_IGNORED;
	}

	new team = pev(ent, pev_team);
	if (team == get_pdata_int(attacker, m_iTeam)) {
		return HAM_SUPERCEDE;
	}

	new teamPoints = Hwn_Collector_GetTeamPoints(team);
	if (teamPoints <= 0) {
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
	if (!CE_CheckAssociation(ent)) {
		return;
	}
	
	static Float:vEnd[3];
	get_tr2(trace, TR_vecEndPos, vEnd);

	UTIL_Message_BloodSprite(vEnd, g_sprBloodSpray, g_sprBlood, 103, floatround(fDamage/4));
}

public OnKilled(ent)
{
	if (!CE_CheckAssociation(ent)) {
		return PLUGIN_CONTINUE;
	}

	static Float:fHealth;
	pev(ent, pev_health, fHealth);
	
	new extractCount = 1;
	if (fHealth < 0) {
		extractCount += -floatround(fHealth)/get_pcvar_num(g_cvarBucketHealth);
	}
	
	set_pev(ent, pev_health, float(get_pcvar_num(g_cvarBucketHealth)));
	ExtractPoints(ent, extractCount);
	
	return PLUGIN_HANDLED;
}

/*------------[ Tasks ]------------*/

public TaskThink(ent)
{
	if (!pev_valid(ent)) {
		return;
	}

	new Float:fGametime = get_gametime();
	for (new id = 1; id <= g_maxPlayers; ++id)
	{
		if (!is_user_alive(id)) {
			continue;
		}
		
		new playerTeam = get_pdata_int(id, m_iTeam);
		new bucketTeam = pev(ent, pev_team);
		
		if (playerTeam != bucketTeam) {
			continue;
		}
		
		if (GetDistanceBetweenEntity(ent, id) < 256.0) {
			if (fGametime >= g_fNextCollectTime[id]) {
				TakePlayerPoint(ent, id);
				g_fNextCollectTime[id] = fGametime + 1.0;
			}
		}
	}
	
	set_task(g_fThinkDelay, "TaskThink", ent);
}

/*------------[ Private ]------------*/

TakePlayerPoint(ent, id)
{
	new playerPoints = Hwn_Collector_GetPlayerPoints(id);
	if (playerPoints <= 0) {
		return;
	}
	
	new team = get_pdata_int(id, m_iTeam);
	new teamPoints = Hwn_Collector_GetTeamPoints(team);
	
	Hwn_Collector_SetPlayerPoints(id, playerPoints-1);	
	Hwn_Collector_SetTeamPoints(team, teamPoints+1);
	
	ExecuteHamB(Ham_AddPoints, id, 1, false);
	
	client_cmd(id, "spk %s", g_szSndPointCollected);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	vOrigin[2] += 24.0;
	
	static Float:vUserOrigin[3];
	pev(id, pev_origin, vUserOrigin);
	
	static Float:vVelocity[3];
	xs_vec_sub(vOrigin, vUserOrigin, vVelocity);
	xs_vec_normalize(vVelocity, vVelocity);
	xs_vec_mul_scalar(vVelocity, 1024.0, vVelocity);
	
	new modelIndex = CE_GetModelIndex("hwn_item_pumpkin");
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
	write_byte(TE_PROJECTILE);
	engfunc(EngFunc_WriteCoord, vUserOrigin[0]);
	engfunc(EngFunc_WriteCoord, vUserOrigin[1]);
	engfunc(EngFunc_WriteCoord, vUserOrigin[2]);
	engfunc(EngFunc_WriteCoord, vVelocity[0]);
	engfunc(EngFunc_WriteCoord, vVelocity[1]);
	engfunc(EngFunc_WriteCoord, vVelocity[2]);
	write_short(modelIndex);
	write_byte(10);
	write_byte(id);
	message_end();
}

ExtractPoints(ent, count = 1)
{
	if (count <= 0) {
		return;
	}

	new team = pev(ent, pev_team);

	new teamPoints = Hwn_Collector_GetTeamPoints(team);
	count = (teamPoints > count) ? (count) : (teamPoints);
	Hwn_Collector_SetTeamPoints(team, teamPoints - count);
	
	{
		static Float:vOrigin[3];
		pev(ent, pev_origin, vOrigin);
		
		static Float:vMaxs[3];
		pev(ent, pev_maxs, vMaxs);
		vOrigin[2] += vMaxs[2];
		
		for (new i = 0; i < count; ++i)
		{
			new pumpkinEnt = CE_Create("hwn_item_pumpkin", vOrigin);

			if (!pumpkinEnt) {
				continue;
			}
			
			static Float:vVelocity[3];
			vVelocity[0] = random_float(-640.0, 640.0);
			vVelocity[1] = random_float(-640.0, 640.0);
			vVelocity[2] = random_float(0.0, 256.0);
			
			set_pev(pumpkinEnt, pev_velocity, vVelocity);

			dllfunc(DLLFunc_Spawn, pumpkinEnt);
		}
	}
}

stock Float:GetDistanceBetweenEntity(ent1, ent2)
{
	static Float:vOrigin1[3];
	pev(ent1, pev_origin, vOrigin1);
	
	static Float:vOrigin2[3];
	pev(ent2, pev_origin, vOrigin2);
	
	return get_distance_f(vOrigin1, vOrigin2);
}