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

new g_szSndWofRun[] = "hwn/wof/wof_roll.wav";

new Trie:g_itSpells;
new Array:g_irgSpellName;
new Array:g_irgSpellDictKey;
new Array:g_irgSpelliPluginId;
new Array:g_irgSpellInvokeFuncId;
new Array:g_irgSpellRevokeFuncId;
new g_iSpellsNum = 0;

new g_iSpell = -1;
new bool:g_bEffectStarted = false;
new Float:g_flEffectTime;
new Float:g_flEffectStartTime;

new g_pCvarEffectTime;

new g_fwRollStart;
new g_fwRollEnd;
new g_fwEffectStart;
new g_fwEffectEnd;
new g_fwEffectInvoke;
new g_fwEffectRevoke;
new g_fwEffectAbort;

public plugin_precache() {
    precache_sound(g_szSndWofRun);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

    g_pCvarEffectTime = register_cvar("hwn_wof_effect_time", "20.0");

    register_concmd("hwn_wof_roll", "Command_WofRoll", ADMIN_CVAR);
    register_concmd("hwn_wof_abort", "Command_WofAbort", ADMIN_CVAR);

    g_fwRollStart = CreateMultiForward("Hwn_Wof_Fw_Roll_Start", ET_IGNORE);
    g_fwRollEnd = CreateMultiForward("Hwn_Wof_Fw_Roll_End", ET_IGNORE);
    g_fwEffectStart = CreateMultiForward("Hwn_Wof_Fw_Effect_Start", ET_IGNORE, FP_CELL);
    g_fwEffectEnd = CreateMultiForward("Hwn_Wof_Fw_Effect_End", ET_IGNORE, FP_CELL);
    g_fwEffectInvoke = CreateMultiForward("Hwn_Wof_Fw_Effect_Invoke", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
    g_fwEffectRevoke = CreateMultiForward("Hwn_Wof_Fw_Effect_Revoke", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwEffectAbort = CreateMultiForward("Hwn_Wof_Fw_Abort", ET_IGNORE);
}

public plugin_end() {
    if (g_iSpellsNum) {
        TrieDestroy(g_itSpells);
        ArrayDestroy(g_irgSpellName);
        ArrayDestroy(g_irgSpellDictKey);
        ArrayDestroy(g_irgSpellInvokeFuncId);
        ArrayDestroy(g_irgSpellRevokeFuncId);
        ArrayDestroy(g_irgSpelliPluginId);
    }
}

public plugin_natives() {
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

public Native_Spell_Register(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new szCastCallback[32];
    get_string(2, szCastCallback, charsmax(szCastCallback));
    new iInvokeFunctionId = get_func_id(szCastCallback, iPluginId);

    new szStopCallback[32];
    get_string(3, szStopCallback, charsmax(szStopCallback));
    new iRevokeFunctionId = equal(szStopCallback, NULL_STRING) ? -1 : get_func_id(szStopCallback, iPluginId);

    return Register(szName, iPluginId, iInvokeFunctionId, iRevokeFunctionId);
}

public Native_Spell_GetName(iPluginId, iArgc) {
    new iSpell = get_param(1);
    new iLen = get_param(3);

    static szSpellName[32];
    ArrayGetString(g_irgSpellName, iSpell, szSpellName, charsmax(szSpellName));

    set_string(2, szSpellName, iLen);
}

public Native_Spell_GetHandler(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new iSpell = 0;
    if (!TrieGetCell(g_itSpells, szName, iSpell)) {
        return -1;
    }

    return iSpell;
}

public Native_Spell_GetDictionaryKey(iPluginId, iArgc) {
    new iSpell = get_param(1);
    new iLen = get_param(3);

    static szDictKey[48];
    ArrayGetString(g_irgSpellDictKey, iSpell, szDictKey, charsmax(szDictKey));

    set_string(2, szDictKey, iLen);
}

public Native_Spell_GetCount(iPluginId, iArgc) {
    return g_iSpellsNum;
}

public Native_Roll(iPluginId, iArgc) {
    StartRoll();
}

public Native_Abort(iPluginId, iArgc) {
    Abort();
}

public Native_Effect_GetCurrentSpell(iPluginId, iArgc) {
    if (!g_bEffectStarted) {
        return -1;
    }

    return g_iSpell;
}

public Float:Native_Effect_GetStartTime(iPluginId, iArgc) {
    return g_flEffectStartTime;
}

public Float:Native_Effect_GetDuration(iPluginId, iArgc) {
    return g_flEffectTime;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public client_disconnected(pPlayer) {
    if (g_iSpell < 0) {
        return;
    }

    if (!g_bEffectStarted) {
        return;
    }

    CallRevoke(pPlayer);
}

public Command_WofRoll(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 1)) {
        return PLUGIN_HANDLED;
    }

    StartRoll();

    return PLUGIN_HANDLED;
}

public Command_WofAbort(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 1)) {
        return PLUGIN_HANDLED;
    }

    Abort();

    return PLUGIN_HANDLED;
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    if (g_iSpell < 0) {
        return;
    }

    if (!g_bEffectStarted) {
        return;
    }

    CallInvoke(pPlayer);
}

public HamHook_Player_Killed_Post(pPlayer) {
    if (g_iSpell < 0) {
        return;
    }

    if (!g_bEffectStarted) {
        return;
    }

    CallRevoke(pPlayer);
}

public Round_Fw_NewRound() {
    Abort();
}

/*--------------------------------[ Methods ]--------------------------------*/

StartRoll() {
    if (g_iSpell >= 0) {
        return;
    }

    if (!g_iSpellsNum) {
        return;
    }

    g_iSpell = random(g_iSpellsNum);

    client_cmd(0, "spk %s", g_szSndWofRun);
    set_task(ROLL_TIME, "Task_EndRoll", TASKID_ROLL_END);
    ExecuteForward(g_fwRollStart, _);
}

EndRoll() {
    ExecuteForward(g_fwRollEnd, _);
    StartEffect();
}

StartEffect() {
    g_flEffectStartTime = get_gametime();
    g_flEffectTime = get_pcvar_float(g_pCvarEffectTime);
    g_bEffectStarted = true;

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_connected(pPlayer)) {
            continue;
        }

        new iTeam = get_member(pPlayer, m_iTeam);
        if (iTeam != 1 && iTeam != 2) {
            continue;
        }

        CallInvoke(pPlayer);
    }

    set_task(g_flEffectTime, "Task_EndEffect", TASKID_EFFECT_END);
    ExecuteForward(g_fwEffectStart, _, g_iSpell);
}

EndEffect() {
    if (g_iSpell >= 0) {
        for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
            if (!is_user_connected(pPlayer)) {
                continue;
            }

            CallRevoke(pPlayer);
        }

        ExecuteForward(g_fwEffectEnd, _, g_iSpell);
    }

    Reset();
}

Abort() {
    EndEffect();
    ExecuteForward(g_fwEffectAbort);
}

Register(const szName[], iPluginId, iInvokeFunctionId, iRevokeFunctionId) {
    if (!g_iSpellsNum) {
        g_itSpells = TrieCreate();
        g_irgSpellName = ArrayCreate(32);
        g_irgSpellDictKey = ArrayCreate(48);
        g_irgSpellInvokeFuncId = ArrayCreate();
        g_irgSpellRevokeFuncId = ArrayCreate();
        g_irgSpelliPluginId = ArrayCreate();
    }

    new iSpell = g_iSpellsNum;

    TrieSetCell(g_itSpells, szName, iSpell);
    ArrayPushString(g_irgSpellName, szName);
    ArrayPushCell(g_irgSpelliPluginId, iPluginId);
    ArrayPushCell(g_irgSpellInvokeFuncId, iInvokeFunctionId);
    ArrayPushCell(g_irgSpellRevokeFuncId, iRevokeFunctionId);

    new szDictKey[48];
    UTIL_CreateDictKey(szName, "HWN_WOF_SPELL_", szDictKey, charsmax(szDictKey));

    if (UTIL_IsLocalizationExists(szDictKey)) {
        ArrayPushString(g_irgSpellDictKey, szDictKey);
    } else {
        ArrayPushString(g_irgSpellDictKey, "");
    }

    g_iSpellsNum++;

    return iSpell;
}

CallInvoke(pPlayer) {
    new iPluginId = ArrayGetCell(g_irgSpelliPluginId, g_iSpell);
    new iFunctionId = ArrayGetCell(g_irgSpellInvokeFuncId, g_iSpell);

    if (iFunctionId < 0) {
        return;
    }

    if (callfunc_begin_i(iFunctionId, iPluginId) == 1) {
        callfunc_push_int(pPlayer);
        callfunc_push_float(g_flEffectTime);

        if (callfunc_end() == PLUGIN_CONTINUE) {
            ExecuteForward(g_fwEffectInvoke, _, pPlayer, g_iSpell, g_flEffectTime);
        }
    }
}

CallRevoke(pPlayer) {
    new iPluginId = ArrayGetCell(g_irgSpelliPluginId, g_iSpell);
    new iFunctionId = ArrayGetCell(g_irgSpellRevokeFuncId, g_iSpell);

    if (iFunctionId < 0) {
        return;
    }

    if (callfunc_begin_i(iFunctionId, iPluginId) == 1) {
        callfunc_push_int(pPlayer);

        if (callfunc_end() == PLUGIN_CONTINUE) {
            ExecuteForward(g_fwEffectRevoke, _, pPlayer, g_iSpell);
        }
    }
}

Reset() {
    g_iSpell = -1;
    g_bEffectStarted = false;
    g_flEffectStartTime = 0.0;
    remove_task(TASKID_ROLL_END);
    remove_task(TASKID_EFFECT_END);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_EndRoll() {
    EndRoll();
}

public Task_EndEffect() {
    EndEffect();
}
