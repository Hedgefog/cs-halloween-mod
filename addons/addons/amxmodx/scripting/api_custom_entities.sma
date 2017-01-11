#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>

#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <cellarray>
#include <celltrie>

#include <xs>

#define PLUGIN	"[API] Custom Entities"
#define VERSION	"1.0.1"
#define AUTHOR	"Hedgehog Fog"

#define CE_BASE_CLASSNAME "info_target"
#define LOG_PREFIX "[CE]"

#define TASKID_SUM_DISAPPEAR 1000

/*--------------------------------[ Constants ]--------------------------------*/

enum CEPreset
{
	CEPreset_None = 0,
	CEPreset_Item,
	CEPreset_NPC,
	CEPreset_Prop
};

enum CEFunction
{
	CEFunction_Spawn,
	CEFunction_Remove,
	CEFunction_Picked,
	CEFunction_Pickup,
	CEFunction_KVD
};

enum CEHookData
{
	CEHookData_PluginID,
	CEHookData_FuncID
}

enum _:RegisterArgs
{
	RegisterArg_Name = 1,
	RegisterArg_ModelIndex,
	RegisterArg_Mins,
	RegisterArg_Maxs,
	RegisterArg_LifeTime,
	RegisterArg_Preset
};

/*--------------------------------[ Variables ]--------------------------------*/

new g_ptrBaseClassname;

new Trie:g_entityHandlers;
new Array:g_entityName;
new Array:g_entityPluginID;
new Array:g_entityModelIndex;
new Array:g_entityMins;
new Array:g_entityMaxs;
new Array:g_entityLifeTime;
new Array:g_entityPreset;
new Array:g_entityHooks;

new g_entityCount = 0;

new Array:g_tmpEntities;

new g_lastCEIdx = 0;
new g_lastCEEnt = 0;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	if (g_lastCEEnt) {
		dllfunc(DLLFunc_Spawn, g_lastCEEnt);
	}
	
	RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);	
	register_event("HLTV", "OnNewRound", "a", "1=0", "2=0");
}

public plugin_end()
{
	for (new i = 0; i < g_entityCount; ++i) {
		DestroyFunctions(i);
	}

	if (g_entityCount) {
		TrieDestroy(g_entityHandlers);
		ArrayDestroy(g_entityName);
		ArrayDestroy(g_entityPluginID);
		ArrayDestroy(g_entityModelIndex);
		ArrayDestroy(g_entityMins);
		ArrayDestroy(g_entityMaxs);
		ArrayDestroy(g_entityLifeTime);
		ArrayDestroy(g_entityPreset);
		ArrayDestroy(g_entityHooks);
	}

	if (g_tmpEntities) {
		ArrayDestroy(g_tmpEntities);
	}
}

public plugin_precache()
{
	g_ptrBaseClassname = engfunc(EngFunc_AllocString, CE_BASE_CLASSNAME);
	
	register_forward(FM_KeyValue, "OnKeyValue", 1);	
	RegisterHam(Ham_Spawn, CE_BASE_CLASSNAME, "OnSpawn", .Post = 1);
}

public plugin_natives()
{
	register_library("api_custom_entities");
	
	register_native("CE_Register", "Native_Register");	
	register_native("CE_Create", "Native_Create");
	register_native("CE_Remove", "Native_Remove");
	
	register_native("CE_GetSize", "Native_GetSize");
	register_native("CE_GetModelIndex", "Native_GetModelIndex");
	
	register_native("CE_CheckAssociation", "Native_CheckAssociation");
	
	register_native("CE_RegisterHook", "Native_RegisterHook");

	register_native("CE_GetHandler", "Native_GetHandler");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
	static szClassName[32];
	get_string(RegisterArg_Name, szClassName, charsmax(szClassName));
	
	new modelIndex = get_param(RegisterArg_ModelIndex);
	new Float:fLifeTime = get_param_f(RegisterArg_LifeTime);	
	new CEPreset:preset = CEPreset:get_param(RegisterArg_Preset);	
	
	new Float:vMins[3];
	get_array_f(RegisterArg_Mins, vMins, 3);
	
	new Float:vMaxs[3];
	get_array_f(RegisterArg_Maxs, vMaxs, 3);
	
	Register(szClassName, pluginID, modelIndex, vMins, vMaxs, fLifeTime, preset);
}

public Native_Create(pluginID, argc)
{
	new szClassName[32];
	get_string(1, szClassName, charsmax(szClassName));
	
	new Float:vOrigin[3];
	get_array_f(2, vOrigin, 3);
	
	new bool:temp = !!get_param(3);
	
	return Create(szClassName, vOrigin, temp);
}

public bool:Native_Remove(pluginID, argc)
{
	new ent = get_param(1);
	return Remove(ent);
}

public Native_GetSize(pluginID, argc)
{
	new szClassName[32];
	get_string(1, szClassName, charsmax(szClassName));
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassName, ceIdx)) {
		return false;
	}
	
	new Float:vMins[3];
	ArrayGetArray(g_entityMins, ceIdx, vMins);

	new Float:vMaxs[3];
	ArrayGetArray(g_entityMaxs, ceIdx, vMaxs);
	
	set_array_f(2, vMins, 3);
	set_array_f(3, vMaxs, 3);

	return true;
}

public Native_GetModelIndex(pluginID, argc)
{
	new szClassName[32];
	get_string(1, szClassName, charsmax(szClassName));
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassName, ceIdx)) {
		return false;
	}
	
	return ArrayGetCell(g_entityModelIndex, ceIdx);
}

public Native_GetHandler(pluginID, argc)
{
	new szClassName[32];
	get_string(1, szClassName, charsmax(szClassName));

	new ceIdx;
	TrieGetCell(g_entityHandlers, szClassName, ceIdx);

	return ceIdx;
}

public bool:Native_CheckAssociation(pluginID, argc)
{
	new ent = get_param(1);
	return CheckAssociation(pluginID, ent);
}

public Native_RegisterHook(pluginID, argc)
{
	new CEFunction:function = CEFunction:get_param(1);
	
	new szClassname[32];
	get_string(2, szClassname, charsmax(szClassname));
	
	new szCallback[32];
	get_string(3, szCallback, charsmax(szCallback));

	RegisterHook(function, szClassname, szCallback, pluginID);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnKeyValue(ent, kvd)
{
	static szKey[32];
	get_kvd(kvd, KV_KeyName, szKey, charsmax(szKey));
	
	static szValue[32];
	get_kvd(kvd, KV_Value, szValue, charsmax(szValue));
	
	if (equal(szKey, "classname"))
	{
		if (g_lastCEEnt) {
			dllfunc(DLLFunc_Spawn, g_lastCEEnt);
			g_lastCEEnt = 0;
		}
	
		if (!TrieGetCell(g_entityHandlers, szValue, g_lastCEIdx)) {
			return;
		}
		
		g_lastCEEnt = Create(szValue, .temp = false);
		
		return;
	}
	
	if (!g_lastCEEnt) {
		return;
	}
	
	DispatchKeyValue(g_lastCEEnt, szKey, szValue);
	ExecuteFunction(CEFunction_KVD, g_lastCEIdx, g_lastCEEnt, szKey, szValue);
}

public OnSpawn(ent)
{	
	static szClassname[32];
	pev(ent, pev_classname, szClassname, charsmax(szClassname));
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		return;
	}
	
	InitEntity(ent, ceIdx);
	
	ExecuteFunction(CEFunction_Spawn, ceIdx, ent);
}

public OnTouch(ent, id)
{
	if (pev(ent, pev_flags) & ~FL_ONGROUND) {
		return;
	}

	if (!is_user_connected(id)) {
		return;
	}
	
	if (!is_user_alive(id)) {
		return;
	}

	static szClassname[32];
	pev(ent, pev_classname, szClassname, charsmax(szClassname));	
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		return;
	}
	
	new CEPreset:preset = ArrayGetCell(g_entityPreset, ceIdx);
	if (preset != CEPreset_Item) {
		return;
	}
	
	if (ExecuteFunction(CEFunction_Pickup, ceIdx, ent, id) > 0) {
		ExecuteFunction(CEFunction_Picked, ceIdx, ent, id);
		Remove(ent, .picked = true);
	}
}

public OnNewRound()
{
	Cleanup();
}

/*--------------------------------[ Methods ]--------------------------------*/

Register(const szClassname[], pluginID, modelIndex, const Float:vMins[3], const Float:vMaxs[3], Float:fLifeTime, CEPreset:preset)
{
	if (!g_entityCount) {
		g_entityHandlers = TrieCreate();
		g_entityName = ArrayCreate(32);
		g_entityPluginID = ArrayCreate(1);
		g_entityModelIndex = ArrayCreate(1);
		g_entityMaxs = ArrayCreate(3);
		g_entityMins = ArrayCreate(3);
		g_entityLifeTime = ArrayCreate(1);
		g_entityPreset = ArrayCreate(1);
		g_entityHooks = ArrayCreate();
	}

	new index = g_entityCount;

	TrieSetCell(g_entityHandlers, szClassname, index);
	
	ArrayPushString(g_entityName, szClassname);
	ArrayPushCell(g_entityPluginID, pluginID);
	ArrayPushCell(g_entityModelIndex, modelIndex);
	ArrayPushArray(g_entityMins, vMins);
	ArrayPushArray(g_entityMaxs, vMaxs);
	ArrayPushCell(g_entityLifeTime, fLifeTime);
	ArrayPushCell(g_entityPreset, preset);
	ArrayPushCell(g_entityHooks, 0);
	
	g_entityCount++;
	
	log_amx("%s Entity %s successfully registred.", LOG_PREFIX, szClassname);
}

Create(const szClassname[], const Float:vOrigin[3] = {0.0, 0.0, 0.0}, bool:temp = true)
{
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		log_error(0, "%s Entity %s is not registered as custom entity.", LOG_PREFIX, szClassname);
		return 0;
	}
		
	new ent = engfunc(EngFunc_CreateNamedEntity, g_ptrBaseClassname);
	set_pev(ent, pev_classname, szClassname, strlen(szClassname));
	
	engfunc(EngFunc_SetOrigin, ent, vOrigin);
	
	new tmpIdx = -1;
	if (temp) {
		if (!g_tmpEntities) {
			g_tmpEntities = ArrayCreate();
		}	
	
		tmpIdx = ArraySize(g_tmpEntities);
		ArrayPushCell(g_tmpEntities, ent);
	}
	
	set_pev(ent, pev_iStepLeft, tmpIdx);
	set_pev(ent, pev_impulse, 'c'+'e'+ceIdx);
	
	return ent;
}

bool:Remove(ent, bool:picked = false)
{
	new szClassname[32];
	pev(ent, pev_classname, szClassname, charsmax(szClassname));
	
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		log_error(0, "%s Entity %s is not registered.", LOG_PREFIX, szClassname);
		return false;
	}
	
	new index = pev(ent, pev_iStepLeft);
	if (index >= 0) {
		ArraySetCell(g_tmpEntities, index, 0);
	}
	
	remove_task(ent+TASKID_SUM_DISAPPEAR);
	ExecuteFunction(CEFunction_Remove, ceIdx, ent, picked);
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
	
	return true;
}

bool:CheckAssociation(pluginID, ent)
{
	if (!pev_valid(ent)) {
		return false;
	}
	
	new ceIdx = GetCEIndexByPluginID(pluginID);	
	
	if (pev(ent, pev_impulse) != 'c'+'e'+ceIdx) {
		return false;
	}
	
	static szClassname[32];
	pev(ent, pev_classname, szClassname, charsmax(szClassname));
	
	static szAssociatedClassname[32];
	ArrayGetString(g_entityName, ceIdx, szAssociatedClassname, charsmax(szAssociatedClassname));
	
	return bool:equal(szClassname, szAssociatedClassname);
}

GetCEIndexByPluginID(pluginID)
{
	for (new i = 0; i < g_entityCount; ++i) {
		if (ArrayGetCell(g_entityPluginID, i) == pluginID) {
			return i;
		}
	}
	
	return -1;
}

Cleanup()
{
	if (!g_tmpEntities) {
		return;
	}

	new size = ArraySize(g_tmpEntities);
	for (new i = 0; i < size; ++i) {
		new ent = ArrayGetCell(g_tmpEntities, i);
		if (ent && pev_valid(ent)) {			
			Remove(ent);
		}
	}
	
	ArrayClear(g_tmpEntities);
}

bool:InitEntity(ent, ceIdx)
{
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);	
	
	static Float:vMins[3];
	ArrayGetArray(g_entityMins, ceIdx, vMins);
	
	static Float:vMaxs[3];
	ArrayGetArray(g_entityMaxs, ceIdx, vMaxs);
	
	engfunc(EngFunc_SetSize, ent, vMins, vMaxs);
	engfunc(EngFunc_SetOrigin, ent, vOrigin);
	
	new preset = ArrayGetCell(g_entityPreset, ceIdx);
	switch (preset)
	{
		case CEPreset_Item:
		{
			set_pev(ent, pev_solid, SOLID_TRIGGER);
			set_pev(ent, pev_movetype, MOVETYPE_TOSS);
		}
		case CEPreset_NPC:
		{
			set_pev(ent, pev_solid, SOLID_BBOX);
			set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP);
				
			set_pev(ent, pev_takedamage, DAMAGE_AIM);
			
			set_pev(ent, pev_controller_0, 125);
			set_pev(ent, pev_controller_1, 125);
			set_pev(ent, pev_controller_2, 125);
			set_pev(ent, pev_controller_3, 125);
			
			set_pev(ent, pev_gamestate, 1);
			set_pev(ent, pev_gravity, 1.0);
			set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_MONSTER);
			set_pev(ent, pev_fixangle, 1);
			set_pev(ent, pev_friction, 0.25);
		}
		case CEPreset_Prop:
		{
			set_pev(ent, pev_solid, SOLID_BBOX);
			set_pev(ent, pev_movetype, MOVETYPE_TOSS);
		}
	}
	
	new modelIndex = ArrayGetCell(g_entityModelIndex, ceIdx);
	if (modelIndex > 0) {
		set_pev(ent, pev_modelindex, modelIndex);
	}
	
	new Float:lifeTime = ArrayGetCell(g_entityLifeTime, ceIdx);
	if (lifeTime > 0.0) {
		set_task(lifeTime, "TaskDisappear", ent+TASKID_SUM_DISAPPEAR);
	}
	
	return true;
}

RegisterHook(CEFunction:function, const szClassname[], const szCallback[], pluginID = -1)
{
	new ceIdx;
	if (!TrieGetCell(g_entityHandlers, szClassname, ceIdx)) {
		log_error(0, "%s Entity %s is not registered.", LOG_PREFIX, szClassname);
		return -1;
	}
	
	new funcID = get_func_id(szCallback, pluginID);
	if (funcID < 0) {
		new szFilename[32];
		get_plugin(pluginID, szFilename, charsmax(szFilename));
		log_error(0, "Function %s not found in plugin %s.", szCallback, szFilename);
		return -1;
	}
	
	new Array:functions = ArrayGetCell(g_entityHooks, ceIdx);
	if (!functions) {
		functions = InitializeFunctions(ceIdx);
	}
	
	new Array:functionHooks = ArrayGetCell(functions, _:function);	

	new Array:hookData = CreateHookData(pluginID, funcID);
	return ArrayPushCell(functionHooks, hookData);
}

Array:InitializeFunctions(ceIdx)
{
	new Array:functions = ArrayCreate(1, _:CEFunction);
	
	for (new i = 0; i < _:CEFunction; ++i) {
		new Array:functionHooks = ArrayCreate();
		ArrayPushCell(functions, functionHooks);
	}
	
	ArraySetCell(g_entityHooks, ceIdx, functions);
	
	return functions;
}

DestroyFunctions(ceIdx)
{
	new Array:functions = ArrayGetCell(g_entityHooks, ceIdx);
	
	if (!functions) {
		return;
	}
	
	for (new i = 0; i < _:CEFunction; ++i) {
		new Array:functionHooks = ArrayGetCell(functions, i);
		ArrayDestroy(functionHooks);
	}
	
	ArrayDestroy(functions);
	ArraySetCell(g_entityHooks, ceIdx, 0);
}

Array:CreateHookData(pluginID, funcID)
{
	new Array:hookData = ArrayCreate(1, _:CEHookData);
	ArrayPushCell(hookData, pluginID);
	ArrayPushCell(hookData, funcID);
	
	return hookData;
}

ExecuteFunction(CEFunction:function, ceIdx, any:...)
{
	new result = 0;
	new ent = getarg(2);
	
	new Array:functions = ArrayGetCell(g_entityHooks, ceIdx);

	if (functions == Invalid_Array) {
		return 0;
	}

	new Array:functionHooks = ArrayGetCell(functions, _:function);
	
	new count = ArraySize(functionHooks);
	for (new i = 0; i < count; ++i)
	{
		new Array:hookData = ArrayGetCell(functionHooks, i);
		new pluginID = ArrayGetCell(hookData, _:CEHookData_PluginID);
		new funcID = ArrayGetCell(hookData, _:CEHookData_FuncID);

		if (funcID < 0) {
			continue;
		}
		
		if (callfunc_begin_i(funcID, pluginID) == 1) 
		{
			callfunc_push_int(ent);

			switch (function)
			{
				case CEFunction_Remove: {
					new bool:picked = bool:getarg(3);
					callfunc_push_int(picked);
				}
				case CEFunction_Pickup, CEFunction_Picked: {
					new id = getarg(3);
					callfunc_push_int(id);
				}
				case CEFunction_KVD: {
					static szKey[32];
					for (new i = 0; i < charsmax(szKey); ++i) {
						szKey[i] = getarg(3, i);						
						
						if (szKey[i]  == '^0') {
							break;
						}
					}
					
					static szValue[32];
					for (new i = 0; i < charsmax(szValue); ++i) {
						szValue[i] = getarg(4, i);						
						
						if (szValue[i]  == '^0') {
							break;
						}
					}
					
					callfunc_push_str(szKey);
					callfunc_push_str(szValue);
				}
			}

			result += callfunc_end();		
		}
	}
	
	return result;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskDisappear(taskID)
{
	new ent = taskID - TASKID_SUM_DISAPPEAR;
	
	Remove(ent, .picked = true);
}
