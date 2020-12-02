#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Spells"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

const Float:SpellCooldown = 1.0;

new Trie:g_spells;
new Array:g_spellName;
new Array:g_spellDictKey;
new Array:g_spellPluginID;
new Array:g_spellCastFuncID;
new Array:g_spellFlags;
new g_spellCount = 0;

new g_fwCast;
new g_fwResult;

new g_playerSpell[MAX_PLAYERS + 1] = { -1, ... };
new g_playerSpellAmount[MAX_PLAYERS + 1] = { 0, ... };
new Float:g_playerNextCast[MAX_PLAYERS + 1] = { 0.0, ... };

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_concmd("hwn_spells_give", "OnClCmd_Give", ADMIN_CVAR);

    g_fwCast = CreateMultiForward("Hwn_Spell_Fw_Cast", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_natives()
{
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

public plugin_end()
{
    if (g_spellCount) {
        TrieDestroy(g_spells);
        ArrayDestroy(g_spellName);
        ArrayDestroy(g_spellDictKey);
        ArrayDestroy(g_spellCastFuncID);
        ArrayDestroy(g_spellPluginID);
        ArrayDestroy(g_spellFlags);
    }
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new Hwn_SpellFlags:flags = Hwn_SpellFlags:get_param(2);

    new szCastCallback[32];
    get_string(3, szCastCallback, charsmax(szCastCallback));
    new castFuncID = get_func_id(szCastCallback, pluginID);

    return Register(szName, flags, pluginID, castFuncID);
}

public Native_CastPlayerSpell(pluginID, argc)
{
    new id = get_param(1);
    CastPlayerSpell(id);
}

public Native_GetPlayerSpell(pluginID, argc)
{
    new id = get_param(1);

    new amount = g_playerSpellAmount[id];
    if (amount <= 0) {
        return -1;
    }

    if (argc > 1) {
        set_param_byref(2, amount);
    }

    return g_playerSpell[id];
}

public Native_SetPlayerSpell(pluginID, argc)
{
    new id = get_param(1);
    new spell = get_param(2);
    new amount = get_param(3);

    SetPlayerSpell(id, spell, amount);
}

public Native_GetCount(pluginID, argc)
{
    return g_spellCount;
}

public Native_GetName(pluginID, argc)
{
    new spellIdx = get_param(1);
    new maxlen = get_param(3);

    static szSpellName[32];
    ArrayGetString(g_spellName, spellIdx, szSpellName, charsmax(szSpellName));

    set_string(2, szSpellName, maxlen);
}

public Native_GetHandler(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new spellIdx;
    if (!TrieGetCell(g_spells, szName, spellIdx)) {
        return -1;
    }

    return spellIdx;
}

public Native_GetDictionaryKey(pluginID, argc)
{
    new spellIdx = get_param(1);
    new maxlen = get_param(3);

    static szDictKey[48];
    ArrayGetString(g_spellDictKey, spellIdx, szDictKey, charsmax(szDictKey));

    set_string(2, szDictKey, maxlen);
}

public Hwn_SpellFlags:Native_GetFlags()
{
    new spellIdx = get_param(1);

    return ArrayGetCell(g_spellFlags, spellIdx);
}

/*--------------------------------[ Hooks ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    SetPlayerSpell(id, -1, 0);
}

public OnClCmd_Give(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1)) {
        return PLUGIN_HANDLED;
    }
    
    new szArgs[4];
    read_args(szArgs, charsmax(szArgs));

    if (szArgs[0] == '^0') {
        return PLUGIN_HANDLED;
    }

    new spell = str_to_num(szArgs);

    if (spell < 0 || spell >= g_spellCount) {
        return PLUGIN_HANDLED;
    }

    SetPlayerSpell(id, spell, 1);

    return PLUGIN_HANDLED;
}

/*--------------------------------[ Methods ]--------------------------------*/

SetPlayerSpell(id, spell, amount)
{
    g_playerSpell[id] = spell;
    g_playerSpellAmount[id] = amount;
}

Register(const szName[], Hwn_SpellFlags:flags, pluginID, castFuncID)
{
    if (!g_spellCount) {
        g_spells = TrieCreate();
        g_spellName = ArrayCreate(32);
        g_spellDictKey = ArrayCreate(48);
        g_spellCastFuncID = ArrayCreate();
        g_spellPluginID = ArrayCreate();
        g_spellFlags = ArrayCreate();
    }

    new spellIdx = g_spellCount;

    TrieSetCell(g_spells, szName, spellIdx);
    ArrayPushString(g_spellName, szName);
    ArrayPushCell(g_spellPluginID, pluginID);
    ArrayPushCell(g_spellCastFuncID, castFuncID);
    ArrayPushCell(g_spellFlags, flags);

    new szDictKey[48];
    UTIL_CreateDictKey(szName, "HWN_SPELL_", szDictKey, charsmax(szDictKey));

    if (UTIL_IsLocalizationExists(szDictKey)) {
        ArrayPushString(g_spellDictKey, szDictKey);
    } else {
        ArrayPushString(g_spellDictKey, "");
    }

    g_spellCount++;

    return spellIdx;
}

CastPlayerSpell(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    if (pev(id, pev_flags) & FL_FROZEN) {
        return;
    }

    new spellAmount = g_playerSpellAmount[id];
    if (spellAmount <= 0) {
        return;
    }

    new Float:gametime = get_gametime();
    new Float:nextCast = g_playerNextCast[id];

    if (gametime < nextCast) {
        return;
    }

    new spellIdx = g_playerSpell[id];
    new pluginID = ArrayGetCell(g_spellPluginID, spellIdx);
    new funcID = ArrayGetCell(g_spellCastFuncID, spellIdx);

    if (callfunc_begin_i(funcID, pluginID) == 1) {
        callfunc_push_int(id);

        if (callfunc_end() == PLUGIN_CONTINUE) {
            g_playerSpellAmount[id] = --spellAmount;
            g_playerNextCast[id] = gametime + SpellCooldown;

            ExecuteForward(g_fwCast, g_fwResult, id, spellIdx);
        }
    }
}
