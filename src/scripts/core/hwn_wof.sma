#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <api_rounds>

#include <hwn>
#include <hwn_utils>

#pragma semicolon 1

#define PLUGIN "[Hwn] Wheel of Fate"
#define AUTHOR "Hedgehog Fog"

#define TASKID_ROLL_END 1000
#define TASKID_EFFECT_END 2000

#define ROLL_TIME 6.8

new g_maxPlayers;
new g_szSndWofRun[] = "hwn/wof/wof_roll.wav";

new Trie:g_spells;
new Array:g_spellName;
new Array:g_spellDictKey;
new Array:g_spellPluginID;
new Array:g_spellInvokeFuncID;
new Array:g_spellRevokeFuncID;
new g_spellCount = 0;

new g_spellIdx = -1;
new bool:g_effectStarted = false;
new Float:g_fEffectTime;
new Float:g_fEffectStartTime;

new g_cvarEffectTime;

new g_fwRollStart;
new g_fwRollEnd;
new g_fwEffectStart;
new g_fwEffectEnd;
new g_fwEffectInvoke;
new g_fwEffectRevoke;
new g_fwEffectAbort;

new g_fwResult;

public plugin_precache()
{
    precache_sound(g_szSndWofRun);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    g_maxPlayers = get_maxplayers();

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);

    g_cvarEffectTime = register_cvar("hwn_wof_effect_time", "20.0");

    register_concmd("hwn_wof_roll", "OnClCmd_WofRoll", ADMIN_CVAR);
    register_concmd("hwn_wof_abort", "OnClCmd_WofAbort", ADMIN_CVAR);

    g_fwRollStart = CreateMultiForward("Hwn_Wof_Fw_Roll_Start", ET_IGNORE);
    g_fwRollEnd = CreateMultiForward("Hwn_Wof_Fw_Roll_End", ET_IGNORE);
    g_fwEffectStart = CreateMultiForward("Hwn_Wof_Fw_Effect_Start", ET_IGNORE, FP_CELL);
    g_fwEffectEnd = CreateMultiForward("Hwn_Wof_Fw_Effect_End", ET_IGNORE, FP_CELL);
    g_fwEffectInvoke = CreateMultiForward("Hwn_Wof_Fw_Effect_Invoke", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
    g_fwEffectRevoke = CreateMultiForward("Hwn_Wof_Fw_Effect_Revoke", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwEffectAbort = CreateMultiForward("Hwn_Wof_Fw_Abort", ET_IGNORE);
}

public plugin_end()
{
    if (g_spellCount) {
        TrieDestroy(g_spells);
        ArrayDestroy(g_spellName);
        ArrayDestroy(g_spellDictKey);
        ArrayDestroy(g_spellInvokeFuncID);
        ArrayDestroy(g_spellRevokeFuncID);
        ArrayDestroy(g_spellPluginID);
    }
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Wof_Spell_Register", "Native_Spell_Register");
    register_native("Hwn_Wof_Spell_GetName", "Native_Spell_GetName");
    register_native("Hwn_Wof_Spell_GetDictionaryKey", "Native_Spell_GetDictionaryKey");
    register_native("Hwn_Wof_Spell_GetHandler", "Native_Spell_GetHandler");
    register_native("Hwn_Wof_Spell_GetCount", "Native_Spell_GetCount");
    register_native("Hwn_Wof_Effect_GetCurrentSpell", "Native_Effect_GetCurrentSpell");
    register_native("Hwn_Wof_Roll", "Native_Roll");
    register_native("Hwn_Wof_Abort", "Native_Abort");
    register_native("Hwn_Wof_Effect_GetStartTime", "Native_Effect_GetStartTime");
    register_native("Hwn_Wof_Effect_GetDuration", "Native_Effect_GetDuration");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Spell_Register(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new szCastCallback[32];
    get_string(2, szCastCallback, charsmax(szCastCallback));
    new invokeFuncID = get_func_id(szCastCallback, pluginID);

    new szStopCallback[32];
    get_string(3, szStopCallback, charsmax(szStopCallback));
    new revokeFuncID = szStopCallback[0] == '^0' ? -1 : get_func_id(szStopCallback, pluginID);

    return Register(szName, pluginID, invokeFuncID, revokeFuncID);
}

public Native_Spell_GetName(pluginID, argc)
{
    new spellIdx = get_param(1);
    new maxlen = get_param(3);

    static szSpellName[32];
    ArrayGetString(g_spellName, spellIdx, szSpellName, charsmax(szSpellName));

    set_string(2, szSpellName, maxlen);
}

public Native_Spell_GetHandler(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new spellIdx;
    if (!TrieGetCell(g_spells, szName, spellIdx)) {
        return -1;
    }

    return spellIdx;
}

public Native_Spell_GetDictionaryKey(pluginID, argc)
{
    new spellIdx = get_param(1);
    new maxlen = get_param(3);

    static szDictKey[48];
    ArrayGetString(g_spellDictKey, spellIdx, szDictKey, charsmax(szDictKey));

    set_string(2, szDictKey, maxlen);
}

public Native_Spell_GetCount(pluginID, argc)
{
    return g_spellCount;
}

public Native_Roll(pluginID, argc)
{
    StartRoll();
}

public Native_Abort(pluginID, argc)
{
    Abort();
}

public Native_Effect_GetCurrentSpell(pluginID, argc)
{
    if (!g_effectStarted) {
        return -1;
    }

    return g_spellIdx;
}

public Float:Native_Effect_GetStartTime(pluginID, argc) {
    return g_fEffectStartTime;
}

public Float:Native_Effect_GetDuration(pluginID, argc) {
    return g_fEffectTime;
}

/*--------------------------------[ Hooks ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    if (g_spellIdx < 0) {
        return;
    }

    if (!g_effectStarted) {
        return;
    }

    CallRevoke(id);
}

public OnClCmd_WofRoll(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1)) {
        return PLUGIN_HANDLED;
    }

    StartRoll();

    return PLUGIN_HANDLED;
}

public OnClCmd_WofAbort(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1)) {
        return PLUGIN_HANDLED;
    }

    Abort();

    return PLUGIN_HANDLED;
}

public OnPlayerSpawn(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    if (g_spellIdx < 0) {
        return;
    }

    if (!g_effectStarted) {
        return;
    }

    CallInvoke(id);
}

public OnPlayerKilled(id)
{
    if (g_spellIdx < 0) {
        return;
    }

    if (!g_effectStarted) {
        return;
    }

    CallRevoke(id);
}

public Round_Fw_NewRound()
{
    Abort();
}

/*--------------------------------[ Methods ]--------------------------------*/

StartRoll()
{
    if (g_spellIdx >= 0) {
        return;
    }

    if (!g_spellCount) {
        return;
    }

    g_spellIdx = random(g_spellCount);

    client_cmd(0, "spk %s", g_szSndWofRun);
    set_task(ROLL_TIME, "TaskEndRoll", TASKID_ROLL_END);
    ExecuteForward(g_fwRollStart, g_fwResult);
}

EndRoll()
{
    ExecuteForward(g_fwRollEnd, g_fwResult);
    StartEffect();
}

StartEffect()
{
    g_fEffectStartTime = get_gametime();
    g_fEffectTime = get_pcvar_float(g_cvarEffectTime);
    g_effectStarted = true;

    for (new id = 1; id <= g_maxPlayers; ++id) {
        if (!is_user_connected(id)) {
            continue;
        }

        new team = UTIL_GetPlayerTeam(id);
        if (team != 1 && team != 2) {
            continue;
        }

        CallInvoke(id);
    }

    set_task(g_fEffectTime, "TaskEndEffect", TASKID_EFFECT_END);
    ExecuteForward(g_fwEffectStart, g_fwResult, g_spellIdx);
}

EndEffect()
{
    if (g_spellIdx >= 0) {
        for (new id = 1; id <= g_maxPlayers; ++id) {
            if (!is_user_connected(id)) {
                continue;
            }

            CallRevoke(id);
        }

        ExecuteForward(g_fwEffectEnd, g_fwResult, g_spellIdx);
    }

    Reset();
}

Abort()
{
    EndEffect();
    ExecuteForward(g_fwEffectAbort, g_fwResult);
}

Register(const szName[], pluginID, invokeFuncID, revokeFuncID)
{
    if (!g_spellCount) {
        g_spells = TrieCreate();
        g_spellName = ArrayCreate(32);
        g_spellDictKey = ArrayCreate(48);
        g_spellInvokeFuncID = ArrayCreate();
        g_spellRevokeFuncID = ArrayCreate();
        g_spellPluginID = ArrayCreate();
    }

    new spellIdx = g_spellCount;

    TrieSetCell(g_spells, szName, spellIdx);
    ArrayPushString(g_spellName, szName);
    ArrayPushCell(g_spellPluginID, pluginID);
    ArrayPushCell(g_spellInvokeFuncID, invokeFuncID);
    ArrayPushCell(g_spellRevokeFuncID, revokeFuncID);

    new szDictKey[48];
    UTIL_CreateDictKey(szName, "HWN_WOF_SPELL_", szDictKey, charsmax(szDictKey));

    if (UTIL_IsLocalizationExists(szDictKey)) {
        ArrayPushString(g_spellDictKey, szDictKey);
    } else {
        ArrayPushString(g_spellDictKey, "");
    }

    g_spellCount++;

    return spellIdx;
}

CallInvoke(id)
{
    new pluginID = ArrayGetCell(g_spellPluginID, g_spellIdx);
    new funcID = ArrayGetCell(g_spellInvokeFuncID, g_spellIdx);

    if (funcID < 0) {
        return;
    }

    if (callfunc_begin_i(funcID, pluginID) == 1) {
        callfunc_push_int(id);
        callfunc_push_float(g_fEffectTime);

        if (callfunc_end() == PLUGIN_CONTINUE) {
            ExecuteForward(g_fwEffectInvoke, g_fwResult, id, g_spellIdx, g_fEffectTime);
        }
    }
}

CallRevoke(id)
{
    new pluginID = ArrayGetCell(g_spellPluginID, g_spellIdx);
    new funcID = ArrayGetCell(g_spellRevokeFuncID, g_spellIdx);

    if (funcID < 0) {
        return;
    }

    if (callfunc_begin_i(funcID, pluginID) == 1) {
        callfunc_push_int(id);

        if (callfunc_end() == PLUGIN_CONTINUE) {
            ExecuteForward(g_fwEffectRevoke, g_fwResult, id, g_spellIdx);
        }
    }
}

Reset()
{
    g_spellIdx = -1;
    g_effectStarted = false;
    g_fEffectStartTime = 0.0;
    remove_task(TASKID_ROLL_END);
    remove_task(TASKID_EFFECT_END);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskEndRoll()
{
    EndRoll();
}

public TaskEndEffect()
{
    EndEffect();
}
