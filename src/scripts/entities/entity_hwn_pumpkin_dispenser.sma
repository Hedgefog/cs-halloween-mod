#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_custom_entities>

#define PLUGIN "[Custom Entity] Hwn Pumpkin Dispanser"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_DROP 0

#define ENTITY_NAME "hwn_pumpkin_dispenser"
#define LOOT_ENTITY_CLASSNAME "hwn_item_pumpkin"

#define DROP_ACCURACY 0.128

new Array:g_dispensers;
new Array:g_dispenserDelay;
new Array:g_dispenserImpulse;

new g_lastEnt;
new Float:g_fLastDelay;
new Float:g_fLastImpulse;

new g_dispenserCount = 0;

public plugin_precache()
{
	CE_Register(
		.szName = ENTITY_NAME
	);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
	CE_RegisterHook(CEFunction_KVD, ENTITY_NAME, "OnKeyValue");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_logevent("OnRoundStart", 2, "1=Round_Start");
}

public plugin_end()
{
	if (!g_dispenserCount) {
		return;
	}

	ArrayDestroy(g_dispensers);
	ArrayDestroy(g_dispenserDelay);
	ArrayDestroy(g_dispenserImpulse);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
	if (pev(ent, pev_iuser1)) {
		return;
	}

	if (!g_dispenserCount) {
		g_dispensers = ArrayCreate(1);
		g_dispenserDelay = ArrayCreate(1);
		g_dispenserImpulse = ArrayCreate(1);
	}
	
	new index = g_dispenserCount;
	ArrayPushCell(g_dispensers, ent);	
	if (g_lastEnt == ent) {
		ArrayPushCell(g_dispenserDelay, g_fLastDelay);
		ArrayPushCell(g_dispenserImpulse, g_fLastImpulse);
	} else {
		ArrayPushCell(g_dispenserDelay, 0);	
		ArrayPushCell(g_dispenserImpulse, 0);	
	}
	
	set_pev(ent, pev_iuser1, index);
	
	g_dispenserCount++;
}

public OnRoundStart()
{
	if (!g_dispenserCount) {
		return;
	}
	
	for (new i = 0; i < g_dispenserCount; ++i) {
		new ent = ArrayGetCell(g_dispensers, i);
		new idx = pev(ent, pev_iuser1);
		new Float:fDelay = ArrayGetCell(g_dispenserDelay, idx);
		
		remove_task(ent+TASKID_SUM_DROP);
		
		if (fDelay > 0.0) {
			set_task(fDelay, "TaskDrop", ent+TASKID_SUM_DROP, _, _, "b");
		}
	}
}

public OnKeyValue(ent, const szKey[], const szValue[])
{
	//Reset props
	if (ent != g_lastEnt) {
		g_lastEnt = ent;
		g_fLastDelay = 0.0;
		g_fLastImpulse = 0.0;
	}

	if (equal(szKey, "impulse")) {
		g_fLastImpulse = str_to_float(szValue);
	} else if (equal(szKey, "delay")) {
		g_fLastDelay = str_to_float(szValue);
	}
}

/*--------------------------------[ Methods ]--------------------------------*/

Drop(ent)
{
	new idx = pev(ent, pev_iuser1);
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);

	new spawnedEnt = CE_Create(LOOT_ENTITY_CLASSNAME, vOrigin);
	if (!spawnedEnt) {
		return;
	}

	new Float:fImpulse = ArrayGetCell(g_dispenserImpulse, idx);
	if (fImpulse > 0.0) {
		static Float:vVelocity[3];

		if (pev(ent, pev_spawnflags) & (1<<0)) {
			vVelocity[0] = random_float(-1.0, 1.0);
			vVelocity[1] = random_float(-1.0, 1.0);

			xs_vec_normalize(vVelocity, vVelocity);
			xs_vec_mul_scalar(vVelocity, fImpulse, vVelocity);
		} else {
			pev(ent, pev_angles, vVelocity);
			angle_vector(vVelocity, ANGLEVECTOR_FORWARD, vVelocity);
			xs_vec_mul_scalar(vVelocity, fImpulse, vVelocity);
		}
		
		new Float:fAbsErr = fImpulse * DROP_ACCURACY;
		for (new i = 0; i < 2; ++i) {
			vVelocity[i] += random_float(-fAbsErr, fAbsErr);
		}
		
		set_pev(spawnedEnt, pev_velocity, vVelocity);
	}

	dllfunc(DLLFunc_Spawn, spawnedEnt);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskDrop(taskID)
{
	new ent = taskID - TASKID_SUM_DROP;
	Drop(ent);
}