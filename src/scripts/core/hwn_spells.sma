#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>
#include <command_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Spells"
#define AUTHOR "Hedgehog Fog"

const Float:SpellCooldown = 1.0;

new Trie:g_itSpells;
new Array:g_irgSpellName;
new Array:g_irgSpellDictKey;
new Array:g_irgSpelliPluginId;
new Array:g_irgSpelliCustFuncId;
new Array:g_irgSpellFlags;
new g_iSpellsNum = 0;

new g_fwCast;

new g_rgiPlayerSpell[MAX_PLAYERS + 1] = { -1, ... };
new g_rgiPlayeriSpellAmount[MAX_PLAYERS + 1];
new Float:g_rgflPlayerflNextCast[MAX_PLAYERS + 1];

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_concmd("hwn_spells_give", "Command_Give", ADMIN_CVAR);

    g_fwCast = CreateMultiForward("Hwn_Spell_Fw_Cast", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_Spell_Register", "Native_Register");
    register_native("Hwn_Spell_GetName", "Native_GetName");
    register_native("Hwn_Spell_GetHandler", "Native_GetHandler");
    register_native("Hwn_Spell_GetCount", "Native_GetCount");
    register_native("Hwn_Spell_GetFlags", "Native_GetFlags");

    register_native("Hwn_Spell_GetPlayerSpell", "Native_GetPlayerSpell");
    register_native("Hwn_Spell_SetPlayerSpell", "Native_SetPlayerSpell");
    register_native("Hwn_Spell_CastPlayerSpell", "Native_CastPlayerSpell");
    register_native("Hwn_Spell_GetDictionaryKey", "Native_GetDictionaryKey");
}

public plugin_end() {
    if (g_iSpellsNum) {
        TrieDestroy(g_itSpells);
        ArrayDestroy(g_irgSpellName);
        ArrayDestroy(g_irgSpellDictKey);
        ArrayDestroy(g_irgSpelliCustFuncId);
        ArrayDestroy(g_irgSpelliPluginId);
        ArrayDestroy(g_irgSpellFlags);
    }
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new Hwn_SpellFlags:iFlags = Hwn_SpellFlags:get_param(2);

    new szCastCallback[32];
    get_string(3, szCastCallback, charsmax(szCastCallback));
    new iCustFuncId = get_func_id(szCastCallback, iPluginId);

    return Register(szName, iFlags, iPluginId, iCustFuncId);
}

public Native_CastPlayerSpell(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    CastPlayerSpell(pPlayer);
}

public Native_GetPlayerSpell(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    new iAmount = g_rgiPlayeriSpellAmount[pPlayer];
    if (iAmount <= 0) {
        return -1;
    }

    if (iArgc > 1) {
        set_param_byref(2, iAmount);
    }

    return g_rgiPlayerSpell[pPlayer];
}

public Native_SetPlayerSpell(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSpell = get_param(2);
    new iAmount = get_param(3);

    SetPlayerSpell(pPlayer, iSpell, iAmount);
}

public Native_GetCount(iPluginId, iArgc) {
    return g_iSpellsNum;
}

public Native_GetName(iPluginId, iArgc) {
    new iSpell = get_param(1);
    new iLen = get_param(3);

    static szSpellName[32];
    ArrayGetString(g_irgSpellName, iSpell, szSpellName, charsmax(szSpellName));

    set_string(2, szSpellName, iLen);
}

public Native_GetHandler(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    static iSpell;
    if (!TrieGetCell(g_itSpells, szName, iSpell)) {
        return -1;
    }

    return iSpell;
}

public Native_GetDictionaryKey(iPluginId, iArgc) {
    new iSpell = get_param(1);
    new iLen = get_param(3);

    static szDictKey[48];
    ArrayGetString(g_irgSpellDictKey, iSpell, szDictKey, charsmax(szDictKey));

    set_string(2, szDictKey, iLen);
}

public Hwn_SpellFlags:Native_GetFlags() {
    new iSpell = get_param(1);

    return ArrayGetCell(g_irgSpellFlags, iSpell);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public client_disconnected(pPlayer) {
    SetPlayerSpell(pPlayer, -1, 0);
}

public Command_Give(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 1)) {
        return PLUGIN_HANDLED;
    }
    
    static szTarget[32];
    read_argv(1, szTarget, charsmax(szTarget));

    static szSpellId[32];
    read_argv(2, szSpellId, charsmax(szSpellId));

    static szAmount[32];
    read_argv(3, szAmount, charsmax(szAmount));

    new iSpell = -1;
    if (!TrieGetCell(g_itSpells, szSpellId, iSpell)) {
        return PLUGIN_HANDLED;
    }

    new iAmount = equal(szAmount, NULL_STRING) ? 1 : str_to_num(szAmount);

    new iTarget = CMD_RESOLVE_TARGET(pPlayer, szTarget);

    for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
        if (!CMD_SHOULD_TARGET_PLAYER(pTarget, iTarget)) {
            continue;
        }

        SetPlayerSpell(pPlayer, iSpell, iAmount);
    }

    return PLUGIN_HANDLED;
}

/*--------------------------------[ Methods ]--------------------------------*/

SetPlayerSpell(pPlayer, iSpell, iAmount) {
    g_rgiPlayerSpell[pPlayer] = iSpell;
    g_rgiPlayeriSpellAmount[pPlayer] = iAmount;
}

Register(const szName[], Hwn_SpellFlags:iFlags, iPluginId, iCustFuncId) {
    if (!g_iSpellsNum) {
        g_itSpells = TrieCreate();
        g_irgSpellName = ArrayCreate(32);
        g_irgSpellDictKey = ArrayCreate(48);
        g_irgSpelliCustFuncId = ArrayCreate();
        g_irgSpelliPluginId = ArrayCreate();
        g_irgSpellFlags = ArrayCreate();
    }

    new iSpell = g_iSpellsNum;

    TrieSetCell(g_itSpells, szName, iSpell);
    ArrayPushString(g_irgSpellName, szName);
    ArrayPushCell(g_irgSpelliPluginId, iPluginId);
    ArrayPushCell(g_irgSpelliCustFuncId, iCustFuncId);
    ArrayPushCell(g_irgSpellFlags, iFlags);

    new szDictKey[48];
    UTIL_CreateDictKey(szName, "HWN_SPELL_", szDictKey, charsmax(szDictKey));

    if (UTIL_IsLocalizationExists(szDictKey)) {
        ArrayPushString(g_irgSpellDictKey, szDictKey);
    } else {
        ArrayPushString(g_irgSpellDictKey, "");
    }

    g_iSpellsNum++;

    return iSpell;
}

CastPlayerSpell(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    if (pev(pPlayer, pev_flags) & FL_FROZEN) {
        return;
    }

    new iSpellAmount = g_rgiPlayeriSpellAmount[pPlayer];
    if (iSpellAmount <= 0) {
        return;
    }

    new Float:flGameTime = get_gametime();
    new Float:flNextCast = g_rgflPlayerflNextCast[pPlayer];

    if (flGameTime < flNextCast) {
        return;
    }

    new iSpell = g_rgiPlayerSpell[pPlayer];
    new iPluginId = ArrayGetCell(g_irgSpelliPluginId, iSpell);
    new iFunctionId = ArrayGetCell(g_irgSpelliCustFuncId, iSpell);

    if (callfunc_begin_i(iFunctionId, iPluginId) == 1) {
        callfunc_push_int(pPlayer);

        if (callfunc_end() == PLUGIN_CONTINUE) {
            g_rgiPlayeriSpellAmount[pPlayer] = --iSpellAmount;
            g_rgflPlayerflNextCast[pPlayer] = flGameTime + SpellCooldown;

            ExecuteForward(g_fwCast, _, pPlayer, iSpell);
        }
    }

    @Player_PlayCastAnimation(pPlayer);
    set_member(pPlayer, m_flNextAttack, 0.5);
}

@Player_PlayCastAnimation(this) {
    static szAnimExtention[32];
    get_member(this, m_szAnimExtention, szAnimExtention, charsmax(szAnimExtention));

    set_member(this, m_szAnimExtention, "grenade");
    rg_set_animation(this, PLAYER_ATTACK1);

    set_member(this, m_szAnimExtention, szAnimExtention);
}
