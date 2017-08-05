#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <astar>
#include <api_custom_entities>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN	"[Custom Entity] Hwn NPC HHH"
#define AUTHOR	"Hedgehog Fog"

#define TASKID_SUM_HIT 			1000
#define TASKID_SUM_IDLE_SOUND	2000

#define ENTITY_NAME "hwn_npc_hhh"

enum _:Sequence 
{
	Sequence_Idle = 0,
	
	Sequence_Run,
	
	Sequence_Attack,
	Sequence_RunAttack,
	Sequence_Shake,
	Sequence_Spawn
};

enum Action
{
	Action_Idle = 0,
	Action_Run,
	Action_Attack,
	Action_RunAttack,
	Action_Shake,
	Action_Spawn
};

enum _:HHH
{
	HHH_AStar_Idx,
	Array:HHH_AStar_Path,
	Array:HHH_AStar_Target,
	Float:HHH_AStar_ArrivalTime,
	Float:HHH_AStar_NextSearch
};

new const g_szSndAttack[][128] = {
	"hwn/npc/hhh/hhh_attack01.wav",
	"hwn/npc/hhh/hhh_attack02.wav",
	"hwn/npc/hhh/hhh_attack03.wav",
	"hwn/npc/hhh/hhh_attack04.wav"
};

new const g_szSndLaugh[][128] = {
	"hwn/npc/hhh/hhh_laugh01.wav",
	"hwn/npc/hhh/hhh_laugh02.wav",
	"hwn/npc/hhh/hhh_laugh03.wav",
	"hwn/npc/hhh/hhh_laugh04.wav"
};

new const g_szSndPain[][128] = {
	"hwn/npc/hhh/hhh_pain01.wav",
	"hwn/npc/hhh/hhh_pain02.wav",
	"hwn/npc/hhh/hhh_pain03.wav"
};

new const g_szSndStep[][128] = {
	"hwn/npc/hhh/hhh_step01.wav",
	"hwn/npc/hhh/hhh_step02.wav"
};

new const g_szSndHit[] = "hwn/npc/hhh/hhh_axe_hit.wav";
new const g_szSndSpawn[] = "hwn/npc/hhh/hhh_spawn.wav";
new const g_szSndDying[] = "hwn/npc/hhh/hhh_dying.wav";
new const g_szSndDeath[] = "hwn/npc/hhh/hhh_death.wav";

new const g_actions[Action][NPC_Action] = {
	{	Sequence_Idle,			Sequence_Idle,		0.0	},
	{	Sequence_Run,			Sequence_Run,		0.0	},
	{	Sequence_Attack,		Sequence_Attack,	1.0	},
	{	Sequence_RunAttack,		Sequence_RunAttack,	1.0	},
	{	Sequence_Shake,			Sequence_Shake,		2.0	},
	{	Sequence_Spawn,			Sequence_Spawn,		2.0	}
};

new Float:NPC_Health 		= 3000.0;
const Float:NPC_Speed 		= 320.0;
const Float:NPC_Damage 		= 80.0;
const Float:NPC_HitRange 	= 96.0;
const Float:NPC_HitDelay 	= 0.75;

new g_sprBlood;
new g_sprBloodSpray;

new g_mdlGibs;

new Float:g_fThinkDelay;

new g_astarEnt[10];

new g_cvarUseAstar;

new g_ceHandler;
new g_bossHandler;

new g_maxPlayers;

public plugin_precache()
{
	g_ceHandler = CE_Register(
		.szName = ENTITY_NAME,
		.modelIndex = precache_model("models/hwn/npc/headless_hatman.mdl"),
		.vMins = Float:{-16.0, -16.0, -48.0},
		.vMaxs = Float:{16.0, 16.0, 48.0},
		.preset = CEPreset_NPC
	);
	
	g_bossHandler = Hwn_Bosses_RegisterBoss(ENTITY_NAME);

	g_sprBlood		= precache_model("sprites/blood.spr");
	g_sprBloodSpray	= precache_model("sprites/bloodspray.spr");
	
	g_mdlGibs = precache_model("models/hwn/npc/headless_hatman_gibs.mdl");
	
	for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
		precache_sound(g_szSndAttack[i]);
	}
	
	for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
		precache_sound(g_szSndLaugh[i]);
	}

	for (new i = 0; i < sizeof(g_szSndPain); ++i) {
		precache_sound(g_szSndPain[i]);
	}
	
	for (new i = 0; i < sizeof(g_szSndStep); ++i) {
		precache_sound(g_szSndStep[i]);
	}
	
	precache_sound(g_szSndHit);
	precache_sound(g_szSndSpawn);
	precache_sound(g_szSndDying);	
	precache_sound(g_szSndDeath);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
	CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
	CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");
	
	RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);
	
	g_cvarUseAstar = register_cvar("hwn_npc_hhh_use_astar", "1");
}

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
	
	g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver()
{
	NPC_Health += 200.0;
}

#if AMXX_VERSION_NUM < 183
	public client_disconnect(id)
#else
	public client_disconnected(id)
#endif
{
	NPC_Health -= 200.0;
}

public Hwn_Bosses_Fw_BossTeleport(ent, handler)
{
	if (handler != g_bossHandler) {
		return;
	}

	AStar_Reset(ent);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	
	UTIL_Message_Dlight(vOrigin, 32, {HWN_COLOR_PURPLE}, 60, 4);
	
	set_pev(ent, pev_rendermode, kRenderNormal);
	set_pev(ent, pev_renderfx, kRenderFxGlowShell);
	set_pev(ent, pev_renderamt, 4.0);
	set_pev(ent, pev_rendercolor, {24.0, 16.0, 64.0});
		
	set_pev(ent, pev_health, NPC_Health);
	
	NPC_Create(ent);
	HHH_Create(ent);
	AStar_Reset(ent);
	
	engfunc(EngFunc_DropToFloor, ent);

	set_pev(ent, pev_takedamage, DAMAGE_NO);
	NPC_EmitVoice(ent, g_szSndSpawn);	
	NPC_PlayAction(ent, g_actions[Action_Spawn]);
	
	set_task(6.0, "TaskThink", ent);
}

public OnRemove(ent)
{
	remove_task(ent);
	remove_task(ent+TASKID_SUM_HIT);
	remove_task(ent+TASKID_SUM_IDLE_SOUND);

	{
		new Float:vOrigin[3];
		pev(ent, pev_origin, vOrigin);
		
		UTIL_Message_Dlight(vOrigin, 32, {HWN_COLOR_PURPLE}, 10, 32);
	}
	
	AStar_Reset(ent);
	
	NPC_Destroy(ent);
	HHH_Destroy(ent);	
}

public OnKill(ent)
{
	new deadflag = pev(ent, pev_deadflag);

	if (deadflag == DEAD_NO) {
		NPC_EmitVoice(ent, g_szSndDying, .supercede = true);
		NPC_PlayAction(ent, g_actions[Action_Shake], .supercede = true);
		
		set_pev(ent, pev_velocity, Float:{0.0, 0.0, 0.0});
		set_pev(ent, pev_deadflag, DEAD_DYING);
		
		remove_task(ent);
		set_task(2.0, "TaskThink", ent);
	} else if (deadflag == DEAD_DEAD) {
		return PLUGIN_CONTINUE;
	}
	
	return PLUGIN_HANDLED;
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
	if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
		return HAM_IGNORED;
	}
	
	if (UTIL_IsPlayer(attacker)) {
		static Float:vOrigin[3];
		pev(attacker, pev_origin, vOrigin);
		/*if (!NPC_IsReachable(ent, vOrigin)) {
			return HAM_SUPERCEDE;
		} else */
		if (random(100) < 30) {
			set_pev(ent, pev_enemy, attacker);
		}
	}
	
	static Float:vEnd[3];
	get_tr2(trace, TR_vecEndPos, vEnd);

	UTIL_Message_BloodSprite(vEnd, g_sprBloodSpray, g_sprBlood, 212, floatround(fDamage/4));
	if (random(100) < 10) {
		NPC_EmitVoice(ent, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
	}
	
	return HAM_IGNORED;
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public AStar_OnPathDone(astarIdx, Array:path, Float:Distance, NodesAdded, NodesValidated, NodesCleared)
{
	if (path == Invalid_Array) {
		return;
	}
	
	new ent = g_astarEnt[astarIdx];

	if (!pev_valid(ent)) {
		return;
	}

	if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
		return;
	}

	new Array:hhh = HHH_Get(ent);
	ArraySetCell(hhh, HHH_AStar_Path, path);
}

/*--------------------------------[ Methods ]--------------------------------*/

HHH_Create(ent)
{
	new Array:hhh = ArrayCreate(HHH);
	for (new i = 0; i < HHH; ++i) {
		ArrayPushCell(hhh, 0);
	}
	
	new Array:target = ArrayCreate(3, 1);
	ArraySetCell(hhh, HHH_AStar_Target, target);
	ArrayPushArray(target, Float:{0.0, 0.0, 0.0});
	
	set_pev(ent, pev_iuser2, hhh);
}

HHH_Destroy(ent)
{
	new Array:hhh = any:pev(ent, pev_iuser2);
	
	new Array:target = ArrayGetCell(hhh, HHH_AStar_Target);
	ArrayDestroy(target);
	
	new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);	
	if (path != Invalid_Array) {
		ArrayDestroy(path);
	}
	
	ArrayDestroy(hhh);
}

Array:HHH_Get(ent)
{
	return Array:pev(ent, pev_iuser2);
}

AStar_FindPath(ent)
{
	new enemy = pev(ent, pev_enemy);

	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	
	static Float:vTarget[3];
	pev(enemy, pev_origin, vTarget);
	
	new Float:fDistanceToFloor = UTIL_GetDistanceToFloor(vOrigin, ent);// + 8.0;
	new astarIdx = AStarThreaded(vOrigin, vTarget, "AStar_OnPathDone", 30, DONT_IGNORE_MONSTERS, ent, floatround(fDistanceToFloor), 50);	
	
	new Array:hhh = HHH_Get(ent);
	ArraySetCell(hhh, HHH_AStar_Idx, astarIdx);
	
	if (astarIdx != -1) {
		g_astarEnt[astarIdx] = ent;
	}
}

AStar_ProcessPath(ent, Array:path)
{
	new Array:hhh = HHH_Get(ent);

	new Float:fArrivalTime = ArrayGetCell(hhh, HHH_AStar_ArrivalTime);

	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);

	static Float:vTarget[3];
	new Array:target = ArrayGetCell(hhh, HHH_AStar_Target);
	ArrayGetArray(target, 0, vTarget);

	if (ArraySize(path) > 0) {
		if (get_gametime() >= fArrivalTime) {
			static curStep[3];
			ArrayGetArray(path, 0, curStep);
			ArrayDeleteItem(path, 0);
			
			for (new i = 0; i < 3; ++i) {
				vTarget[i] = float(curStep[i]);
			}
			
			//if (NPC_IsReachable(ent, vTarget)) {
			new Float:fDistance = get_distance_f(vOrigin, vTarget);
			ArraySetArray(target, 0, vTarget);
			
			ArraySetCell(hhh, HHH_AStar_ArrivalTime, get_gametime() + (fDistance/NPC_Speed));
			/*} else {
				AStar_Reset(ent);
			}*/
		}
		
		NPC_PlayAction(ent, g_actions[Action_Run]);
		NPC_MoveToTarget(ent, vTarget, NPC_Speed);			
	} else {
		vOrigin[2] = vTarget[2];
		if (get_distance_f(vOrigin, vTarget) <= 64.0 && get_gametime() >= fArrivalTime) {
			AStar_Reset(ent);
			NPC_PlayAction(ent, g_actions[Action_Idle]);
		}
	}
}

AStar_Reset(ent)
{
	new Array:hhh = HHH_Get(ent);
	
	new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
	if (path != Invalid_Array) {
		ArrayDestroy(path);
	}
	
	new astarIdx = ArrayGetCell(hhh, HHH_AStar_Idx);
	AStarAbort(astarIdx);
	
	ArraySetCell(hhh, HHH_AStar_Idx, -1);
	ArraySetCell(hhh, HHH_AStar_Path, Invalid_Array);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskHit(taskID)
{
	new ent = taskID - TASKID_SUM_HIT;
	if (NPC_Hit(ent, NPC_Damage, NPC_HitRange, NPC_HitDelay, Float:{0.0, 0.0, 16.0})) {
		emit_sound(ent, CHAN_WEAPON, g_szSndHit, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	}
}

public TaskThink(ent)
{
	if (!pev_valid(ent)) {
		return;
	}
	
	static Float:vOrigin[3];	
	pev(ent, pev_origin, vOrigin);
	
	if (pev(ent, pev_deadflag) == DEAD_DYING)
	{
		UTIL_Message_ExplodeModel(vOrigin, random_float(-512.0, 512.0), g_mdlGibs, 5, 25);	
		NPC_EmitVoice(ent, g_szSndDeath, .supercede = true);
		set_pev(ent, pev_deadflag, DEAD_DEAD);
		CE_Kill(ent);
		
		return;
	}
	
	if (pev(ent, pev_takedamage) == DAMAGE_NO) {
		set_pev(ent, pev_takedamage, DAMAGE_AIM);	
	}
	
	{
		static lifeTime;
		if (!lifeTime) {
			lifeTime = UTIL_DelayToLifeTime(g_fThinkDelay);	
		}
		
		UTIL_Message_Dlight(vOrigin, 4, {HWN_COLOR_PURPLE}, lifeTime, 0);
		
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
		write_byte(TE_ELIGHT);
		write_short(0);
		engfunc(EngFunc_WriteCoord, vOrigin[0]);
		engfunc(EngFunc_WriteCoord, vOrigin[1]);
		engfunc(EngFunc_WriteCoord, vOrigin[2]+42.0);
		write_coord(16);
		write_byte(64);
		write_byte(52);
		write_byte(4);
		write_byte(lifeTime);
		write_coord(0);
		message_end();
	}

	new bool:astarRequired = false;

	new enemy = pev(ent, pev_enemy);
	if (NPC_IsValidEnemy(enemy))
	{
		if (!Attack(ent, enemy) && (get_pcvar_num(g_cvarUseAstar) > 0)) {
			astarRequired = true;
		}
	}
	else
	{
		if (!NPC_FindEnemy(ent, g_maxPlayers) && get_pcvar_num(g_cvarUseAstar) > 0) {
			astarRequired = true;
		} else {
			NPC_PlayAction(ent, g_actions[Action_Idle]);	
		}
	}
	
	new Float:fGametime = get_gametime();	
	
	if (astarRequired)
	{	
		new Array:hhh = HHH_Get(ent);
		new astarIdx = ArrayGetCell(hhh, HHH_AStar_Idx);
		new Array:path = ArrayGetCell(hhh, HHH_AStar_Path);
		new Float:fNextSearch = ArrayGetCell(hhh, HHH_AStar_NextSearch);
	
		if (astarIdx == -1) {
			if (NPC_IsValidEnemy(enemy) || NPC_FindEnemy(ent, g_maxPlayers, .reachableOnly = false)) {
				AStar_FindPath(ent);				
				ArraySetCell(hhh, HHH_AStar_NextSearch, fGametime + 10.0);
			}
			
			NPC_PlayAction(ent, g_actions[Action_Idle]);
		} else if (path != Invalid_Array) {
			AStar_ProcessPath(ent, path);
			NPC_EmitFootStep(ent, g_szSndStep[random(sizeof(g_szSndStep))]);
		} else {
			if (fGametime > fNextSearch) {
				AStar_Reset(ent);
			}
		
			NPC_PlayAction(ent, g_actions[Action_Idle]);
		}
	}
	
	set_task(g_fThinkDelay, "TaskThink", ent);
}

bool:Attack(ent, target)
{
	static Float:vOrigin[3];	
	pev(ent, pev_origin, vOrigin);

	new bool:canHit = NPC_CanHit(ent, target, NPC_HitRange);
		
	if (canHit && !task_exists(ent+TASKID_SUM_HIT)) {
		set_task(NPC_HitDelay, "TaskHit", ent+TASKID_SUM_HIT);
		NPC_PlayAction(ent, g_actions[Action_RunAttack]);
		NPC_EmitVoice(ent, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.5);
	}

	static Float:vTarget[3];
	if (NPC_GetTarget(ent, NPC_Speed, vTarget)) {
		if (!canHit) {
			NPC_PlayAction(ent, g_actions[Action_Run]);
			
			if (random(100) < 10) {
				NPC_EmitVoice(ent, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
			}
			
			NPC_EmitFootStep(ent, g_szSndStep[random(sizeof(g_szSndStep))]);
		}
		
		AStar_Reset(ent);
		NPC_MoveToTarget(ent, vTarget, NPC_Speed);
		
		for (new id = 1; id <= g_maxPlayers; ++id) {
			if (!is_user_connected(id)) {
				continue;
			}
		
			if (!is_user_alive(id)) {
				continue;
			}
			
			static Float:vUserOrigin[3];
			pev(id, pev_origin, vUserOrigin);
			
			if (get_distance_f(vOrigin, vUserOrigin) > 512.0) {
				continue;
			}
			
			message_begin(MSG_ONE, get_user_msgid("ScreenShake"), .player = id);
			write_short(UTIL_FixedUnsigned16(8.0, 1<<12));
			write_short(UTIL_FixedUnsigned16(1.0, 1<<12));
			write_short(UTIL_FixedUnsigned16(1.0, 1<<8));
			message_end();
		}
		
		return true;
	}

	return false;
}