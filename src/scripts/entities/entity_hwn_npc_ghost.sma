#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_particles>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN	"[Custom Entity] Hwn NPC Ghost"
#define AUTHOR	"Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_ghost"

const Float:NPC_Speed = 150.0;
const Float:NPC_Damage = 10.0;
const Float:NPC_HitRange = 32.0;
const Float:NPC_HitDelay = 3.0;

new const g_szSndDisappeared[] = "hwn/misc/gotohell.wav";

new const g_szSndAttack[][128] = {
	"hwn/npc/ghost/ghost_attack01.wav",
	"hwn/npc/ghost/ghost_attack02.wav",
	"hwn/npc/ghost/ghost_attack03.wav"
};

new const g_szSndIdle[][128] = {
	"hwn/npc/ghost/ghost_moan01.wav",
	"hwn/npc/ghost/ghost_moan02.wav",
	"hwn/npc/ghost/ghost_moan03.wav",
	"hwn/npc/ghost/ghost_moan04.wav"
};

new Float:g_fThinkDelay;
new g_particlesEnabled;

new Array:g_playerKiller;

new g_maxPlayers;

public plugin_precache()
{	
	precache_sound(g_szSndDisappeared);
	
	for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
		precache_sound(g_szSndAttack[i]);
	}
	
	for (new i = 0; i < sizeof(g_szSndIdle); ++i) {
		precache_sound(g_szSndIdle[i]);
	}

	CE_Register(
		.szName = ENTITY_NAME,
		.modelIndex = precache_model("models/hwn/npc/ghost_v2.mdl"),
		.vMins = Float:{-12.0, -12.0, -32.0},
		.vMaxs = Float:{12.0, 12.0, 32.0},
		.fLifeTime = 30.0,
		.preset = CEPreset_NPC
	);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
	CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
	CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");
}

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
	g_particlesEnabled = get_cvar_num("hwn_enable_particles");
	
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
	
	g_maxPlayers = get_maxplayers();
	
	g_playerKiller = ArrayCreate(1, g_maxPlayers+1);
	for (new i = 0; i <= g_maxPlayers; ++i) {
		ArrayPushCell(g_playerKiller, 0);
	}
}

public plugin_end()
{
	ArrayDestroy(g_playerKiller);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
	NPC_Create(ent);

	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_movetype, MOVETYPE_NOCLIP);
	
	set_pev(ent, pev_framerate, 1.0);

	set_pev(ent, pev_rendermode, kRenderNormal);
	set_pev(ent, pev_renderfx, kRenderFxGlowShell);
	set_pev(ent, pev_renderamt, 1.0);
	set_pev(ent, pev_rendercolor, {HWN_COLOR_PURPLE_F});
	
	set_pev(ent, pev_health, 1);

	if (!UTIL_IsPlayer(pev(ent, pev_enemy))) {
		NPC_FindEnemy(ent, .maxplayers = g_maxPlayers, .reachableOnly = false);
	}
	
	if (g_particlesEnabled)
	{
		new particleEnt = Particles_Spawn("magic_glow", Float:{0.0, 0.0, 0.0}, 0.0);
		set_pev(particleEnt, pev_movetype, MOVETYPE_FOLLOW);
		set_pev(particleEnt, pev_aiment, ent);
		set_pev(ent, pev_iuser4, particleEnt);
	}
	
	TaskThink(ent);
}

public OnRemove(ent)
{
	remove_task(ent);

	if (g_particlesEnabled) {
		Particles_Remove(pev(ent, pev_iuser4));	
	}
	
	NPC_Destroy(ent);
}

public OnKilled(ent)
{
	if (g_particlesEnabled) {
		Particles_Remove(pev(ent, pev_iuser4));	
	}

	emit_sound(ent, CHAN_BODY, g_szSndDisappeared, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public OnPlayerKilled(id, killer)
{	
	ArraySetCell(g_playerKiller, id, killer);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskThink(ent)
{
	if (!pev_valid(ent)) {
		return;
	}
	
	if (pev(ent, pev_deadflag) == DEAD_NO)
	{
		static Float:vOrigin[3];
		pev(ent, pev_origin, vOrigin);
	
		new enemy = pev(ent, pev_enemy);
		if (NPC_IsValidEnemy(enemy))
		{
			static Float:vTarget[3];
			pev(enemy, pev_origin, vTarget);
	
			if (get_distance_f(vOrigin, vTarget) <= NPC_HitRange)
			{
				if (NPC_CanHit(ent, enemy, NPC_HitRange)) {				
					NPC_EmitVoice(ent, g_szSndAttack[random(sizeof(g_szSndAttack))], .supercede = true);
					NPC_Hit(ent, NPC_Damage, NPC_HitRange, NPC_HitDelay);
				}
	
				set_pev(ent, pev_velocity, Float:{0.0, 0.0, 0.0});
			}
			else
			{
				if (random(100) < 10) {
					NPC_EmitVoice(ent, g_szSndIdle[random(sizeof(g_szSndIdle))], 4.0);
				}
	
				static Float:vDirection[3];
				xs_vec_sub(vTarget, vOrigin, vDirection);
				xs_vec_normalize(vDirection, vDirection);
	
				static Float:vVelocity[3];
				xs_vec_mul_scalar(vDirection, NPC_Speed, vVelocity);
				set_pev(ent, pev_velocity, vVelocity);
	
				xs_vec_mul_scalar(vDirection, NPC_HitRange, vDirection);
				xs_vec_sub(vTarget, vDirection, vTarget);
				UTIL_TurnTo(ent, vTarget);
			}
		}
		else if (!UTIL_IsPlayer(enemy))
		{
			CE_Kill(ent);
			return;
		}
		else
		{
			new killer = ArrayGetCell(g_playerKiller, enemy);
			if (killer == enemy) {
				killer = 0;
			}
			
			set_pev(ent, pev_enemy, killer);
		}
	
		//The reason of server crash =(
		/*new target = -1;
		while ((target = engfunc(EngFunc_FindEntityInSphere, target, vOrigin, 96.0)) != 0)
		{
			if (!pev_valid(target)) {
				continue;
			}
	
			static szTargetClassname[32];
			pev(target, pev_classname, szTargetClassname, charsmax(szTargetClassname));
	
			if (equal(szTargetClassname, "hwn_prop_jackolantern")) {
				set_pev(target, pev_nextthink, get_gametime() + 10.0);
			}
		}*/	
	}

	set_task(g_fThinkDelay, "TaskThink", ent);
}

/*Teleport(ent)
{
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	
	for (new i = 0; i < 3; ++i) {
		new direction = random(1) ? 1 : -1;
		vOrigin[i] += random_float(256.0, 768.0) * direction;
	}
}*/