#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#include <api_particles>
#include <api_custom_entities>

#define PLUGIN "[Custom Entity] Hwn Item Spellbook"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_spellbook"

new g_sprSparkle;

new g_particlesEnabled;

new const g_szSndSpawn[] = "hwn/items/spellbook/spellbook_spawn.wav";
new const g_szSndPickup[] = "hwn/spells/spell_pickup.wav";

new bool:g_isPrecaching;

new g_ceHandler;

public plugin_init()
{
	g_isPrecaching = false;

	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

	g_particlesEnabled = get_cvar_num("hwn_enable_particles");
}

public plugin_precache()
{
	g_isPrecaching = true;

	g_sprSparkle = precache_model("sprites/muz7.spr");

	precache_sound(g_szSndSpawn);
	precache_sound(g_szSndPickup);

	g_ceHandler = CE_Register(
		.szName = ENTITY_NAME,
		.modelIndex = precache_model("models/hwn/items/spellbook.mdl"),
		.vMins = Float:{-16.0, -12.0, 0.0},
		.vMaxs = Float:{16.0, 12.0, 24.0},
		.fLifeTime = 30.0,
		.preset = CEPreset_Item
	);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
	CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
	CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");
	CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "OnPickup");
}

public OnSpawn(ent)
{
	set_pev(ent, pev_framerate, 1.0);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);	
	vOrigin[2] += 32.0;
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
	write_byte(TE_SPRITETRAIL);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2] + 8.0);
	write_short(g_sprSparkle);
	write_byte(8); //Count
	write_byte(1); //Lifetime
	write_byte(1); //Scale
	write_byte(16); //Speed Noise
	write_byte(32); //Speed
	message_end();
	
	emit_sound(ent, CHAN_BODY, g_szSndSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);	
	
	TaskThink(ent);
}

public OnRemove(ent)
{
	remove_task(ent);
	
	RemoveParticles(ent);
}

public OnKilled(ent)
{
	RemoveParticles(ent);
}

public OnPickup(ent, id)
{
	if (Hwn_Spell_GetPlayerSpell(id) != -1) {
		return PLUGIN_CONTINUE;
	}

	new count = Hwn_Spell_GetCount();
	if (count) {
		new idx = random(count);
		Hwn_Spell_SetPlayerSpell(id, idx, random(2)+1);
	}
	
	emit_sound(ent, CHAN_BODY, g_szSndPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	return PLUGIN_HANDLED;
}

public TaskThink(ent)
{
	if (!pev_valid(ent)) {
		return;
	}

	if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
		return;
	}
	
	if (pev(ent, pev_deadflag) != DEAD_NO) {
		return;
	}
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	vOrigin[2] += 32.0;
	
	if (g_particlesEnabled)
	{
		new particlesEnt = pev(ent, pev_iuser1);	
	
		if (particlesEnt)
		{
			if (pev_valid(particlesEnt)) {
				engfunc(EngFunc_SetOrigin, particlesEnt, vOrigin);	
			} else {
				set_pev(ent, pev_iuser1, 0);
			}
		}
		else if (!g_isPrecaching)
		{
			particlesEnt = Particles_Spawn("magic_glow", vOrigin, 0.0);
			set_pev(ent, pev_iuser1, particlesEnt);
		}
	}
	
	set_task(1.0, "TaskThink", ent);
}

RemoveParticles(ent)
{
	if (!pev(ent, pev_iuser1)) {
		return;
	}
	
	Particles_Remove(pev(ent, pev_iuser1));
	set_pev(ent, pev_iuser1, 0);
}