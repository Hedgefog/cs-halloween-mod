#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include <api_rounds>

#include <hwn>

#define PLUGIN "[Hwn] Player Effects"
#define AUTHOR "Hedgehog Fog"

enum PEffectData {
  Array:PEffectData_Id[32],
  Array:PEffectData_InvokeFunctionId,
  Array:PEffectData_RevokeFunctionId,
  Array:PEffectData_PluginId,
  Array:PEffectData_Players,
  Array:PEffectData_PlayerEffectEnd[MAX_PLAYERS]
};

new Trie:g_itEffectsIds = Invalid_Trie;
new g_rgPEffectData[PEffectData] = { Invalid_Array, ... };
new g_iEffectssNum = 0;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);

    g_itEffectsIds = TrieCreate();

    g_rgPEffectData[PEffectData_Id] = ArrayCreate(32);
    g_rgPEffectData[PEffectData_InvokeFunctionId] = ArrayCreate();
    g_rgPEffectData[PEffectData_RevokeFunctionId] = ArrayCreate();
    g_rgPEffectData[PEffectData_PluginId] = ArrayCreate();
    g_rgPEffectData[PEffectData_Players] = ArrayCreate();
    g_rgPEffectData[PEffectData_PlayerEffectEnd] = ArrayCreate(MAX_PLAYERS + 1);

    register_concmd("hwn_plyer_effect_set", "Command_Set", ADMIN_CVAR);
}

public plugin_end() {
    TrieDestroy(g_itEffectsIds);

    for (new PEffectData:iEffectData = PEffectData:0; iEffectData < PEffectData; ++iEffectData) {
        ArrayDestroy(Array:g_rgPEffectData[iEffectData]);
    }
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_PlayerEffect_Register", "Native_Register");
    register_native("Hwn_Player_SetEffect", "Native_SetPlayerEffect");
    register_native("Hwn_Player_GetEffect", "Native_GetPlayerEffect");
}

public Native_Register(iPluginId, iArgc) {
    new szId[32];
    get_string(1, szId, charsmax(szId));

    new szInvokeFunction[32];
    get_string(2, szInvokeFunction, charsmax(szInvokeFunction));

    new szRevokeFunction[32];
    get_string(3, szRevokeFunction, charsmax(szRevokeFunction));

    new iInvokeFunctionId = get_func_id(szInvokeFunction, iPluginId);
    new iRevokeFunctionId = get_func_id(szRevokeFunction, iPluginId);

    return Register(szId, iInvokeFunctionId, iRevokeFunctionId, iPluginId);
}

public bool:Native_SetPlayerEffect(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    new szEffectId[32];
    get_string(2, szEffectId, charsmax(szEffectId));

    new iEffectId = -1;
    if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) {
        return false;
    }

    new bool:bValue = bool:get_param(3);
    new Float:flDuration = get_param_f(4);

    return SetPlayerEffect(pPlayer, iEffectId, bValue, flDuration);
}

public bool:Native_GetPlayerEffect(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    new szEffectId[32];
    get_string(2, szEffectId, charsmax(szEffectId));

    new iEffectId = -1;
    if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) {
        return false;
    }

    return GetPlayerEffect(pPlayer, iEffectId);
}

public Command_Set(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 1)) {
        return PLUGIN_HANDLED;
    }

    new szArgs[4];
    read_args(szArgs, charsmax(szArgs));

    static szTarget[32];
    read_argv(1, szTarget, charsmax(szTarget));

    static szEffectId[32];
    read_argv(2, szEffectId, charsmax(szEffectId));

    static szValue[32];
    read_argv(3, szValue, charsmax(szValue));

    static szDuration[32];
    read_argv(4, szDuration, charsmax(szDuration));

    new pTarget = 0;
    if (szTarget[0] == '@') {
        if (equal(szTarget[1], "me")) {
            pTarget = pPlayer;
        }
    } else if (szTarget[0] == '#') {
        pTarget = find_player("k", str_to_num(szTarget[1]));
    } else {
        pTarget = find_player("b", szTarget);
    }

    if (!pTarget) {
        return PLUGIN_HANDLED;
    }

    new bool:bValue = equal(szValue, NULL_STRING) ? true : bool:str_to_num(szValue);

    new iEffectId = -1;
    if (!TrieGetCell(g_itEffectsIds, szEffectId, iEffectId)) {
        return PLUGIN_HANDLED;
    }

    new Float:flDuration = equal(szDuration, NULL_STRING) ? -1.0 : str_to_float(szDuration);

    SetPlayerEffect(pTarget, iEffectId, bValue, flDuration);

    // log_amx("[Set Effect] %d %d %d %f", pTarget, iEffectId, bValue, flDuration);

    return PLUGIN_HANDLED;
}

public client_disconnected(pPlayer) {
    RevokePlayerEffects(pPlayer);
}

bool:GetPlayerEffect(pPlayer, iEffectId) {
    new iPlayers = ArrayGetCell(g_rgPEffectData[PEffectData_Players], iEffectId);

    return !!(iPlayers & BIT(pPlayer & 31));
}

bool:SetPlayerEffect(pPlayer, iEffectId, bool:bValue, Float:flDuration = -1.0) {
    if (bValue && !is_user_alive(pPlayer)) {
        return false;
    }

    new iPlayers = ArrayGetCell(g_rgPEffectData[PEffectData_Players], iEffectId);
    new bool:bCurrentValue = !!(iPlayers & BIT(pPlayer & 31));

    if (bValue == bCurrentValue) {
        return false;
    }

    new bool:bResult = (
        bValue
            ? CallInvokeFunction(pPlayer, iEffectId, flDuration)
            : CallRevokeFunction(pPlayer, iEffectId)
    );

    if (!bResult) {
        return false;
    }

    if (bValue) {
        ArraySetCell(g_rgPEffectData[PEffectData_Players], iEffectId, iPlayers | BIT(pPlayer & 31));

        new Float:flEndTime = flDuration < 0.0 ? 0.0 : get_gametime() + flDuration;
        ArraySetCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], iEffectId, flEndTime, pPlayer);
    } else {
        ArraySetCell(g_rgPEffectData[PEffectData_Players], iEffectId, iPlayers & ~BIT(pPlayer & 31));
    }


    return true;
}

Register(const szId[], iInvokeFunctionId, iRevokeFunctionId, iPluginId) {
    new iEffectId = g_iEffectssNum;

    ArrayPushString(g_rgPEffectData[PEffectData_Id], szId);
    ArrayPushCell(g_rgPEffectData[PEffectData_InvokeFunctionId], iInvokeFunctionId);
    ArrayPushCell(g_rgPEffectData[PEffectData_RevokeFunctionId], iRevokeFunctionId);
    ArrayPushCell(g_rgPEffectData[PEffectData_PluginId], iPluginId);
    ArrayPushCell(g_rgPEffectData[PEffectData_Players], 0);
    ArrayPushCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], 0);

    TrieSetCell(g_itEffectsIds, szId, iEffectId);

    g_iEffectssNum++;

    return iEffectId;
}

RevokePlayerEffects(pPlayer)  {
    for (new iEffectId = 0; iEffectId < g_iEffectssNum; ++iEffectId) {
        SetPlayerEffect(pPlayer, iEffectId, false);
    }
}

public Round_Fw_NewRound() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        RevokePlayerEffects(pPlayer);
    }
}

bool:CallInvokeFunction(pPlayer, iEffectId, Float:flDuration) {
    new iPluginId = ArrayGetCell(g_rgPEffectData[PEffectData_PluginId], iEffectId);
    new iFunctionId = ArrayGetCell(g_rgPEffectData[PEffectData_InvokeFunctionId], iEffectId);

    callfunc_begin_i(iFunctionId, iPluginId);
    callfunc_push_int(pPlayer);
    callfunc_push_float(flDuration);
    new iResult = callfunc_end();

    if (iResult >= PLUGIN_HANDLED) {
        return false;
    }

    return true;
}

bool:CallRevokeFunction(pPlayer, iEffectId) {
    new iPluginId = ArrayGetCell(g_rgPEffectData[PEffectData_PluginId], iEffectId);
    new iFunctionId = ArrayGetCell(g_rgPEffectData[PEffectData_RevokeFunctionId], iEffectId);

    callfunc_begin_i(iFunctionId, iPluginId);
    callfunc_push_int(pPlayer);
    new iResult = callfunc_end();

    if (iResult >= PLUGIN_HANDLED) {
        return false;
    }

    return true;
}

public HamHook_Player_Killed(pPlayer) {
    RevokePlayerEffects(pPlayer);
}

public HamHook_Player_PostThink_Post(pPlayer) {
    new Float:flGameTime = get_gametime();

    for (new iEffectId = 0; iEffectId < g_iEffectssNum; ++iEffectId) {
        static iPlayers; iPlayers = ArrayGetCell(g_rgPEffectData[PEffectData_Players], iEffectId);
        if (~iPlayers & BIT(pPlayer & 31)) {
            continue;
        }

        static Float:flEndTime; flEndTime = ArrayGetCell(g_rgPEffectData[PEffectData_PlayerEffectEnd], iEffectId, pPlayer);
        if (!flEndTime || flEndTime > flGameTime) {
            continue;
        }

        SetPlayerEffect(pPlayer, iEffectId, false);
    }
}
