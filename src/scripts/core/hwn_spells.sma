#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Hwn] Spells"
#define AUTHOR "Hedgehog Fog"

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"
#define SPELLBALL_ENTITY_CLASSNAME_LEN 18

const SpellBallTraceLifetime = 10;
const SpellBallTraceWidth = 10;

new const g_szSndFireballCast[] = "hwn/spells/spell_fireball_cast.wav";

new g_sprSpellballTrace;

new Trie:g_spells;
new Array:g_spellName;
new Array:g_spellColor;
new Array:g_spellPluginID;
new Array:g_spellBallModelindex;
new Array:g_spellDetonateRadius;
new Array:g_spellDetonateFuncID;
new Array:g_spellBallGravity;
new g_spellCount = 0;

new Array:g_playerSpell;
new Array:g_playerSpellAmount;
new Array:g_playerNextCast;

new g_maxPlayers;

public plugin_precache()
{
	g_sprSpellballTrace = precache_model("sprites/xbeam4.spr");
	
	precache_sound(g_szSndFireballCast);
}

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	g_maxPlayers = get_maxplayers();
	
	g_playerNextCast = ArrayCreate(1, g_maxPlayers+1);
	for (new i = 0; i <= g_maxPlayers; ++i) {
		ArrayPushCell(g_playerNextCast, 0);
	}
	
	CE_RegisterHook(CEFunction_Remove, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballRemove");
}

public plugin_natives()
{
	register_library("hwn");
	register_native("Hwn_Spell_Register", "Native_Register");
	register_native("Hwn_Spell_GetName", "Native_GetName");	
	register_native("Hwn_Spell_GetCount", "Native_GetCount");
	
	register_native("Hwn_Spell_GetPlayerSpell", "Native_GetPlayerSpell");
	register_native("Hwn_Spell_SetPlayerSpell", "Native_SetPlayerSpell");
	register_native("Hwn_Spell_CastPlayerSpell", "Native_CastPlayerSpell");
}

public plugin_end()
{
	if (g_spellCount) {
		TrieDestroy(g_spells);
		ArrayDestroy(g_spellName);
		ArrayDestroy(g_spellDetonateFuncID);
		ArrayDestroy(g_spellPluginID);
		ArrayDestroy(g_spellBallModelindex);
		ArrayDestroy(g_spellColor);
		ArrayDestroy(g_spellDetonateRadius);
		ArrayDestroy(g_spellBallGravity);
	}

	if (g_playerSpell) {
		ArrayDestroy(g_playerSpell);
		ArrayDestroy(g_playerSpellAmount);
		ArrayDestroy(g_playerNextCast);
	}
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
	new szName[32];
	get_string(1, szName, charsmax(szName));
	
	new modelindex = get_param(2);
	
	new Float:detonateRadius = get_param_f(3);
	
	new color[3];
	get_array(4, color, sizeof(color));
	
	new szDetonateCallback[32];
	get_string(5, szDetonateCallback, charsmax(szDetonateCallback));
	new detonateFuncID = get_func_id(szDetonateCallback, pluginID);
	
	new bool:gravity = any:get_param(6);
		
	return Register(szName, pluginID, detonateFuncID, detonateRadius, modelindex, color, gravity);
}

public Native_CastPlayerSpell(pluginID, argc)
{
	new id = get_param(1);
	CastPlayerSpell(id);
}

public Native_GetPlayerSpell(pluginID, argc)
{
	new id = get_param(1);
	
	if (!g_playerSpell) {
		return -1;
	}
	
	new amount = ArrayGetCell(g_playerSpellAmount, id);	
	if (amount <= 0) {
		return -1;
	}
	
	if (argc > 1) {
		set_param_byref(2, amount);
	}
	
	return ArrayGetCell(g_playerSpell, id);	
}

public Native_SetPlayerSpell(pluginID, argc)
{	
	if (!g_playerSpell) {
		g_playerSpell = ArrayCreate(1, g_maxPlayers+1);
		g_playerSpellAmount = ArrayCreate(1, g_maxPlayers+1);
		g_playerNextCast = ArrayCreate(1, g_maxPlayers+1);
		
		for (new i = 0; i <= g_maxPlayers; ++i) {
			ArrayPushCell(g_playerSpell, 0);
			ArrayPushCell(g_playerSpellAmount, 0);
			ArrayPushCell(g_playerNextCast, 0);
		}
	}

	new id = get_param(1);
	new spell = get_param(2);
	new amount = get_param(3);
	
	ArraySetCell(g_playerSpell, id, spell);
	ArraySetCell(g_playerSpellAmount, id, amount);
}

public Native_GetCount(pluginID, argc)
{
	return g_spellCount;
}

public Native_GetName(pluginID, argc)
{
	new idx = get_param(1);
	new maxlen = get_param(3);
	
	static szSpellName[32];
	ArrayGetString(g_spellName, idx, szSpellName, charsmax(szSpellName));
	
	set_string(2, szSpellName, maxlen);
	
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpellballRemove(ent)
{	
	new spellIdx = pev(ent, pev_iuser1);
	
	new pluginID = ArrayGetCell(g_spellPluginID, spellIdx);
	new funcID = ArrayGetCell(g_spellDetonateFuncID, spellIdx);
	
	if (callfunc_begin_i(funcID, pluginID) == 1) {
		callfunc_push_int(ent);
		callfunc_end();
	}
	
	static Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	
	static color[3];
	ArrayGetArray(g_spellColor, spellIdx, color);
	
	new Float:detonateRadius = ArrayGetCell(g_spellDetonateRadius, spellIdx);
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]+detonateRadius);
	write_short(g_sprSpellballTrace);
	write_byte(0);
	write_byte(0);
	write_byte(5);
	write_byte(floatround(detonateRadius/2));
	write_byte(0);
	write_byte(color[0]);
	write_byte(color[1]);
	write_byte(color[2]);
	write_byte(255);
	write_byte(0);
	message_end();
}

/*--------------------------------[ Methods ]--------------------------------*/

Register(const szName[], pluginID, detonateFuncID, Float:detonateRadius, modelindex, color[3], bool:gravity)
{
	if (!g_spellCount) {
		g_spells = TrieCreate();
		g_spellName = ArrayCreate(32);
		g_spellDetonateFuncID = ArrayCreate();
		g_spellPluginID = ArrayCreate();
		g_spellBallModelindex = ArrayCreate();	
		g_spellColor = ArrayCreate(3);
		g_spellDetonateRadius = ArrayCreate();
		g_spellBallGravity = ArrayCreate();
	}

	new spellIdx = g_spellCount;
	
	TrieSetCell(g_spells, szName, spellIdx);
	
	ArrayPushString(g_spellName, szName);
	ArrayPushCell(g_spellPluginID, pluginID);
	ArrayPushCell(g_spellDetonateFuncID, detonateFuncID);
	ArrayPushCell(g_spellBallModelindex, modelindex);
	ArrayPushCell(g_spellDetonateRadius, detonateRadius);
	ArrayPushArray(g_spellColor, color);
	ArrayPushCell(g_spellBallGravity, gravity);
	
	g_spellCount++;
	
	return spellIdx;
}

CastPlayerSpell(id)
{
	if (g_playerSpell == Invalid_Array) {
		return;
	}
	
	if (!is_user_alive(id)) {
		return;
	}

	new spellAmount = ArrayGetCell(g_playerSpellAmount, id);	
	if (spellAmount <= 0) {
		return;
	}
	
	new Float:gametime = get_gametime();
	new Float:nextCast = ArrayGetCell(g_playerNextCast, id);
	
	if (gametime < nextCast) {
		return;
	}
	
	new spellIdx = ArrayGetCell(g_playerSpell, id);	
	new spellballModelindex = ArrayGetCell(g_spellBallModelindex, spellIdx);
	
	static Float:vOrigin[3];
	pev(id, pev_origin, vOrigin);
	
	new ent = CE_Create(SPELLBALL_ENTITY_CLASSNAME, vOrigin);

	if (!ent) {
		return;
	}

	static Float:vVelocity[3];
	velocity_by_aim(id, 512, vVelocity);
	
	static color[3];
	ArrayGetArray(g_spellColor, spellIdx, color);
	
	set_pev(ent, pev_iuser1, spellIdx);
	set_pev(ent, pev_owner, id);
	set_pev(ent, pev_velocity, vVelocity);	
	set_pev(ent, pev_modelindex, spellballModelindex);
	set_pev(ent, pev_scale, 0.25);
	set_pev(ent, pev_rendercolor, color);
	
	dllfunc(DLLFunc_Spawn, ent);
	
	new bool:gravity = ArrayGetCell(g_spellBallGravity, spellIdx);
	if (!gravity) {
		set_pev(ent, pev_movetype, MOVETYPE_FLYMISSILE);	
	}
	
	ArraySetCell(g_playerSpellAmount, id, --spellAmount);
	ArraySetCell(g_playerNextCast, id, gametime + 1.0);
	
	emit_sound(ent, CHAN_BODY, g_szSndFireballCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}