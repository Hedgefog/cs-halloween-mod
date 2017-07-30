#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_player_burn>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Spells Default"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_INVISIBILITY	1000

const Float:FireballRadius = 128.0;
const Float:FireballDamage = 30.0;
const Float:BlinkRadius = 64.0;
const Float:OverhealRadius = 128.0;
const Float:InvisibilityRadius = 128.0;
const Float:InvisibilityTime = 10.0;

new const g_szSndOverhealDetonate[] = "hwn/spells/spell_overheal.wav";
new const g_szSndBlinkDetonate[] = "hwn/spells/spell_teleport.wav";
new const g_szSndInvisibilityDetonate[] = "hwn/spells/spell_stealth.wav";
new const g_szSndFireballDetonate[] = "hwn/spells/spell_fireball_impact.wav";

new g_sprFireball;
new g_sprBlinkBall;
new g_sprOverhealBall;
new g_sprInvisibilityBall;

new g_maxPlayers;

public plugin_precache()
{
	g_sprFireball = precache_model("sprites/rjet1.spr");
	g_sprBlinkBall = precache_model("sprites/xspark1.spr");
	g_sprOverhealBall = precache_model("sprites/cnt1.spr");
	g_sprInvisibilityBall = precache_model("sprites/flare1.spr");

	precache_sound(g_szSndOverhealDetonate);
	precache_sound(g_szSndBlinkDetonate);
	precache_sound(g_szSndInvisibilityDetonate);
	precache_sound(g_szSndFireballDetonate);
}

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
	
	g_maxPlayers = get_maxplayers();
	
	Hwn_Spell_Register(
		.szName = "Fireball",
		.modelindex = g_sprFireball,
		.color = {255, 127, 47},
		.fDetonateRadius = FireballRadius,
		.gravity = false,
		.szDetonateCallback = "OnFireballDetonate"
	);
	
	Hwn_Spell_Register(
		.szName = "Blink", 
		.modelindex = g_sprBlinkBall, 
		.color = {0, 0, 255}, 
		.fDetonateRadius = BlinkRadius,
		.szDetonateCallback = "OnBlinkDetonate"
	);
	
	Hwn_Spell_Register(
		.szName = "Overheal", 
		.modelindex = g_sprOverhealBall,
		.color = {255, 0, 0},
		.fDetonateRadius = OverhealRadius,
		.szDetonateCallback = "OnOverhealDetonate"
	);
	
	Hwn_Spell_Register(
		.szName = "Invisibility", 
		.modelindex = g_sprInvisibilityBall, 
		.color = {255, 255, 255},
		.fDetonateRadius = InvisibilityRadius,
		.szDetonateCallback = "OnInvisibilityDetonate"
	);
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public OnPlayerKilled(id)
{
	SetInvisible(id, false);
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public OnInvisibilityDetonate(ent)
{
	new owner = pev(ent, pev_owner);
	new team = get_pdata_int(owner, m_iTeam);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);		
	
	new Array:users = UTIL_FindUsersNearby(vOrigin, InvisibilityRadius, .team = team, .maxPlayers = g_maxPlayers);
	new userCount = ArraySize(users);
	
	for (new i = 0; i < userCount; ++i) {
		new id = ArrayGetCell(users, i);
		
		if (team != get_pdata_int(id, m_iTeam)) {
			continue;
		}		
		
		SetInvisible(id, true);
		UTIL_ScreenFade(id, {128, 128, 128}, InvisibilityTime+2.0, 0.0, 128, FFADE_IN);
		
		if (task_exists(id+TASKID_SUM_INVISIBILITY)) {
			remove_task(id+TASKID_SUM_INVISIBILITY);
		}
		
		set_task(10.0, "TaskRemoveInvisibility", id+TASKID_SUM_INVISIBILITY);
	}
	
	ArrayDestroy(users);
	
	emit_sound(ent, CHAN_BODY, g_szSndInvisibilityDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public OnOverhealDetonate(ent)
{
	new owner = pev(ent, pev_owner);
	new team = get_pdata_int(owner, m_iTeam);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);		
	
	new Array:users = UTIL_FindUsersNearby(vOrigin, OverhealRadius, .team = team, .maxPlayers = g_maxPlayers);
	new userCount = ArraySize(users);
	
	for (new i = 0; i < userCount; ++i) {
		new id = ArrayGetCell(users, i);
		
		if (team != get_pdata_int(id, m_iTeam)) {
			continue;
		}
		
		set_pev(id, pev_health, 150.0);
		UTIL_ScreenFade(id, {255, 0, 0}, 1.0, 0.0, 128, FFADE_IN);
	}
	
	ArrayDestroy(users);
	
	emit_sound(ent, CHAN_BODY, g_szSndOverhealDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public OnFireballDetonate(ent)
{
	new owner = pev(ent, pev_owner);
	new team = get_pdata_int(owner, m_iTeam);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);		
	
	new target = -1;
	while ((target = engfunc(EngFunc_FindEntityInSphere, target, vOrigin, FireballRadius)) != 0)
	{
		if (pev(target, pev_takedamage) == DAMAGE_NO) {
			continue;
		}
		
		if (target == owner) {
			continue;
		}
		
		static Float:vTargetOrigin[3];
		pev(target, pev_origin, vTargetOrigin);		
		
		new Float:fDamage = UTIL_CalculateRadiusDamage(vOrigin, vTargetOrigin, FireballRadius, FireballDamage);		
		
		if (UTIL_IsPlayer(target)) {
			if (team == get_pdata_int(target, m_iTeam)) {
				continue;
			}
		
			static Float:vDirection[3];
			xs_vec_sub(vOrigin, vTargetOrigin, vDirection);
			xs_vec_normalize(vDirection, vDirection);
			xs_vec_mul_scalar(vDirection, -512.0, vDirection);
			
			static Float:vTargetVelocity[3];
			pev(target, pev_velocity, vTargetVelocity);
			xs_vec_add(vTargetVelocity, vDirection, vTargetVelocity);
			set_pev(target, pev_velocity, vTargetVelocity);

			UTIL_CS_DamagePlayer(target, fDamage, DMG_BURN, owner, 0);
			burn_player(target, owner, 15);
		} else {
			ExecuteHamB(Ham_TakeDamage, target, 0, owner, fDamage, DMG_BURN);
		}
	}
	
	emit_sound(ent, CHAN_BODY, g_szSndFireballDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public OnBlinkDetonate(ent)
{
	new owner = pev(ent, pev_owner);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
		
	static Float:vVelocity[3];
	pev(ent, pev_velocity, vVelocity);

	static Float:vMins[3];
	pev(owner, pev_mins, vMins);		
	
	static Float:vAngles[3];
	vector_to_angle(vVelocity, vAngles);
	
	static Float:vAngleForward[3];			
	angle_vector(vAngles, ANGLEVECTOR_FORWARD, vAngleForward);
	xs_vec_mul_scalar(vAngleForward, vMins[1]-16.0, vAngleForward);
	xs_vec_add(vAngleForward, vOrigin, vOrigin);
	
	static Float:vAngleUp[3];
	angle_vector(vAngles, ANGLEVECTOR_UP, vAngleUp);
	xs_vec_mul_scalar(vAngleUp, -(vMins[2]-16.0), vAngleUp);
	xs_vec_add(vAngleUp, vOrigin, vOrigin);
	
	{
		new hull = (pev(owner, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;			
	
		new trace = 0;
		engfunc(EngFunc_TraceHull, vOrigin, vOrigin, 0, hull, 0, trace);
		
		if (get_tr2(trace, TR_InOpen)) {
			engfunc(EngFunc_SetOrigin, owner, vOrigin);
			UTIL_ScreenFade(owner, {0, 0, 255}, 1.0, 0.0, 128, FFADE_IN);
		}
		
		free_tr2(trace);
	}
	
	emit_sound(ent, CHAN_BODY, g_szSndBlinkDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Methods ]--------------------------------*/

SetInvisible(id, bool:value = true)
{
	if (value) {
		set_pev(id, pev_rendermode, kRenderTransTexture);
		set_pev(id, pev_renderamt, 15.0);
	} else {
		set_pev(id, pev_rendermode, kRenderNormal);
		set_pev(id, pev_renderamt, 0.0);
	}
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskRemoveInvisibility(taskID)
{
	new id = taskID - TASKID_SUM_INVISIBILITY;
	
	SetInvisible(id, false);
}