#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>
#include <api_player_cosmetic>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Bosses"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SPAWN_BOSS 0
#define TASKID_REMOVE_BOSS 1

#define MIN_DAMAGE_TO_WIN 300

#define BOSS_TARGET_ENTITY_CLASSNAME "hwn_boss_target"

new const g_szSndBossSpawn[] = "hwn/misc/halloween_boss_summoned.wav";
new const g_szSndBossDefeat[] = "hwn/misc/halloween_boss_defeated.wav";
new const g_szSndBossEscape[] = "hwn/misc/halloween_boss_escape.wav";
new const g_szSndCongratulations[] = "hwn/misc/congratulations.wav";

new g_cvarBossSpawnDelay;
new g_cvarBossLifeTime;

new g_fwResult;
new g_fwBossSpawn;
new g_fwBossKill;
new g_fwBossEscape;
new g_fwWinner;

new Array:g_bosses;
new Array:g_bossSpawnPoints;

new Array:g_playerTotalDamage;

new g_bossEnt = 0;
new g_bossSpawnPoint;

new g_maxPlayers;

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	g_maxPlayers = get_maxplayers();
	g_playerTotalDamage = ArrayCreate(1, g_maxPlayers+1);
	for (new i = 0; i <= g_maxPlayers; ++i) {
		ArrayPushCell(g_playerTotalDamage, 0);
	}
	
	g_cvarBossSpawnDelay = register_cvar("hwn_boss_spawn_delay", "600.0");
	g_cvarBossLifeTime = register_cvar("hwn_boss_life_time", "120.0");
	
	g_fwBossSpawn = CreateMultiForward("Hwn_Bosses_Fw_BossSpawn", ET_IGNORE, FP_CELL);
	g_fwBossKill = CreateMultiForward("Hwn_Bosses_Fw_BossKill", ET_IGNORE, FP_CELL);
	g_fwBossEscape = CreateMultiForward("Hwn_Bosses_Fw_BossEscape", ET_IGNORE, FP_CELL);
	g_fwWinner = CreateMultiForward("Hwn_Bosses_Fw_Winner", ET_IGNORE, FP_CELL);
	
	CreateBossSpawnTask();
}

public plugin_end()
{
	ArrayDestroy(g_playerTotalDamage);

	if (g_bosses != Invalid_Array) {
		ArrayDestroy(g_bosses);
	}
	
	if (g_bossSpawnPoints != Invalid_Array) {
		ArrayDestroy(g_bossSpawnPoints);
	}
}

public plugin_precache()
{
	CE_RegisterHook(CEFunction_Spawn, BOSS_TARGET_ENTITY_CLASSNAME, "OnBossTargetSpawn");
	
	precache_sound(g_szSndBossSpawn);
	precache_sound(g_szSndBossDefeat);
	precache_sound(g_szSndBossEscape);
	precache_sound(g_szSndCongratulations);
	
	RegisterHam(Ham_TakeDamage, "info_target", "OnTargetTakeDamage", .Post = 1);
	RegisterHam(Ham_Touch, "trigger_hurt", "OnHurtTouch", .Post = 0);
}

public plugin_natives()
{
	register_library("hwn");
	register_native("Hwn_Bosses_RegisterBoss", "Native_Register");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
	new szClassname[32];
	get_string(1, szClassname, charsmax(szClassname));

	if (!g_bosses) {
		g_bosses = ArrayCreate(32);
	}
	
	ArrayPushString(g_bosses, szClassname);
	
	CE_RegisterHook(CEFunction_Remove, szClassname, "OnBossRemove");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver(id)
{
	ArraySetCell(g_playerTotalDamage, id, 0);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnBossTargetSpawn(ent)
{
	if (!g_bossSpawnPoints) {
		g_bossSpawnPoints = ArrayCreate(3);
	}
	
	new Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	ArrayPushArray(g_bossSpawnPoints, vOrigin);
	
	CE_Remove(ent);
}

public OnBossRemove(ent)
{
	if (g_bossEnt != ent) {
		return;
	}
	
	if (pev(ent, pev_deadflag) != DEAD_NO) {
		client_cmd(0, "spk %s", g_szSndBossDefeat);
		ExecuteForward(g_fwBossKill, g_fwResult, g_bossEnt);
		SelectWinners();
	} else {
		client_cmd(0, "spk %s", g_szSndBossEscape);
		ExecuteForward(g_fwBossEscape, g_fwResult, g_bossEnt);
	}
	
	g_bossEnt = 0;
	remove_task(TASKID_REMOVE_BOSS);
	
	CreateBossSpawnTask();
}

public OnTargetTakeDamage(ent, inflictor, attacker, Float:fDamage)
{
	if (ent != g_bossEnt) {
		return;
	}

	if (!UTIL_IsPlayer(attacker)) {
		return;
	}
	
	new totalDamage = ArrayGetCell(g_playerTotalDamage, attacker) + floatround(fDamage);
	ArraySetCell(g_playerTotalDamage, attacker, totalDamage);
}

public OnHurtTouch(ent, toucher)
{
	if (toucher != g_bossEnt) {
		return HAM_IGNORED;
	}
	
	static Float:vOrigin[3];
	ArrayGetArray(g_bossSpawnPoints, g_bossSpawnPoint, vOrigin);
	engfunc(EngFunc_SetOrigin, g_bossEnt, vOrigin);
	
	return HAM_SUPERCEDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

SpawnBoss()
{
	if (g_bossEnt) {
		return;
	}

	if (g_bosses == Invalid_Array) {
		return;
	}
	
	if (g_bossSpawnPoints == Invalid_Array) {
		return;
	}
	
	ResetPlayerTotalDamage();
	
	new bossCount = ArraySize(g_bosses);
	new bossIdx = random(bossCount);
	
	static szClassname[32];
	ArrayGetString(g_bosses, bossIdx, szClassname, charsmax(szClassname));
	
	new targetCount = ArraySize(g_bossSpawnPoints);
	new targetIdx = random(targetCount);
	
	static Float:vOrigin[3];
	ArrayGetArray(g_bossSpawnPoints, targetIdx, vOrigin);
	
	g_bossEnt = CE_Create(szClassname, vOrigin);

	if (!g_bossEnt) {
		return;
	}

	dllfunc(DLLFunc_Spawn, g_bossEnt);
	
	g_bossSpawnPoint = targetIdx;
	
	client_cmd(0, "spk %s", g_szSndBossSpawn);
	set_task(get_pcvar_float(g_cvarBossLifeTime), "TaskRemoveBoss", TASKID_REMOVE_BOSS);
	
	ExecuteForward(g_fwBossSpawn, g_fwResult, g_bossEnt);
}

CreateBossSpawnTask()
{
	set_task(get_pcvar_float(g_cvarBossSpawnDelay), "TaskSpawnBoss", TASKID_SPAWN_BOSS);
}

ResetPlayerTotalDamage()
{
	for (new i = 0; i <= g_maxPlayers; ++i) {
		ArraySetCell(g_playerTotalDamage, i, 0);
	}
}

SelectWinners()
{
	for (new id = 1; id < g_maxPlayers; ++id)
	{
		if (!is_user_connected(id)) {
			continue;
		}
		
		new damage = ArrayGetCell(g_playerTotalDamage, id);
		if (damage >= MIN_DAMAGE_TO_WIN)
		{
			ExecuteForward(g_fwWinner, g_fwResult, id);
			
			static cvarGiftCosmeticMaxTime;
			if (!cvarGiftCosmeticMaxTime) {
				cvarGiftCosmeticMaxTime = get_cvar_pointer("hwn_gifts_cosmetic_max_time");	
			}
			
			new count = Hwn_Cosmetic_GetCount();
			new cosmetic = Hwn_Cosmetic_GetCosmetic(random(count));
			
			PCosmetic_Give(id, cosmetic, PCosmetic_Type_Unusual, get_pcvar_num(cvarGiftCosmeticMaxTime));
			
			client_cmd(id, "spk %s", g_szSndCongratulations);
		}
	}
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskSpawnBoss()
{
	SpawnBoss();
}

public TaskRemoveBoss()
{
	CE_Remove(g_bossEnt);
}