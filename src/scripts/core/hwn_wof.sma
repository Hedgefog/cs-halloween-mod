#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#pragma semicolon 1

#define PLUGIN "[Hwn] Wheel of Fate"
#define AUTHOR "Hedgehog Fog"

#define TASKID_ROLL_END 1000
#define TASKID_EFFECT_END 2000

#define ROLL_TIME 6.8

new g_maxPlayers;
new g_szSndWofRun[] = "sound/hwn/wof/wof_roll.wav";

new Trie:g_spells;
new Array:g_spellName;
new Array:g_spellPluginID;
new Array:g_spellInvokeFuncID;
new Array:g_spellRevokeFuncID;
new g_spellCount = 0;

new g_spellIdx = -1;

new g_cvarEffectTime;

new g_fwRollStart;
new g_fwRollEnd;
new g_fwEffectStart;
new g_fwEffectEnd;
new g_fwEffectInvoke;
new g_fwEffectRevoke;

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
    
    g_fwRollStart = CreateMultiForward("Hwn_Wof_Fw_Roll_Start", ET_IGNORE);
    g_fwRollEnd = CreateMultiForward("Hwn_Wof_Fw_Roll_End", ET_IGNORE);
    g_fwEffectStart = CreateMultiForward("Hwn_Wof_Fw_Effect_Start", ET_IGNORE, FP_CELL);
    g_fwEffectEnd = CreateMultiForward("Hwn_Wof_Fw_Effect_End", ET_IGNORE, FP_CELL);
    g_fwEffectInvoke = CreateMultiForward("Hwn_Wof_Fw_Effect_Invoke", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwEffectRevoke = CreateMultiForward("Hwn_Wof_Fw_Effect_Revoke", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_end()
{
    if (g_spellCount) {
        TrieDestroy(g_spells);
        ArrayDestroy(g_spellName);
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
  register_native("Hwn_Wof_Spell_GetCount", "Native_Spell_GetCount");
  register_native("Hwn_Wof_Roll", "Native_Roll");
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
    new idx = get_param(1);
    new maxlen = get_param(3);
    
    static szSpellName[32];
    ArrayGetString(g_spellName, idx, szSpellName, charsmax(szSpellName));
    
    set_string(2, szSpellName, maxlen);
}

public Native_Spell_GetCount(pluginID, argc)
{
  return g_spellCount;
}

public Native_Roll(pluginID, argc)
{
  Roll();
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnClCmd_WofRoll(id, level, cid)
{
  if(!cmd_access(id, level, cid, 1)) {
    return PLUGIN_HANDLED;
  }

  Roll();

  return PLUGIN_HANDLED;
}

public OnPlayerSpawn(id)
{
  if (g_spellIdx < 0) {
    return;
  }

  CallInvoke(id);
}

public OnPlayerKilled(id)
{
  if (g_spellIdx < 0) {
    return;
  }

  CallRevoke(id);
}

public Hwn_Gamemode_Fw_NewRound()
{
  EndEffect();
}

/*--------------------------------[ Methods ]--------------------------------*/

public Roll()
{
  if (g_spellIdx >= 0) {
    return;
  }
  
  client_cmd(0, "spk %s", g_szSndWofRun);
  ExecuteForward(g_fwRollStart, g_fwResult);
  set_task(ROLL_TIME, "RollEnd", TASKID_ROLL_END);
}

public RollEnd()
{
  ExecuteForward(g_fwRollEnd, g_fwResult);
  StartEffect();
}

public StartEffect()
{
  if (!g_spellCount) {
    return;
  }

  if (g_spellIdx >= 0) {
    return;
  }

  g_spellIdx = random(g_spellCount);

  for (new id = 1; id <= g_maxPlayers; ++id) {
    if (!is_user_connected(id)) {
      return;
    }

    CallInvoke(id);
  }

  ExecuteForward(g_fwEffectStart, g_fwResult, g_spellIdx);
  set_task(get_pcvar_float(g_cvarEffectTime), "EndEffect", TASKID_EFFECT_END);
}

public EndEffect()
{
  if (g_spellIdx >= 0) {
    for (new id = 1; id <= g_maxPlayers; ++id) {
      if (!is_user_connected(id)) {
        return;
      }
      
      CallRevoke(id);
    }

    ExecuteForward(g_fwEffectEnd, g_fwResult, g_spellIdx);
  }

  Reset();
}

Register(const szName[], pluginID, invokeFuncID, revokeFuncID)
{
    if (!g_spellCount) {
        g_spells = TrieCreate();
        g_spellName = ArrayCreate(32);
        g_spellInvokeFuncID = ArrayCreate();
        g_spellRevokeFuncID = ArrayCreate();
        g_spellPluginID = ArrayCreate();
    }

    new effectIdx = g_spellCount;
    
    TrieSetCell(g_spells, szName, effectIdx);
    ArrayPushString(g_spellName, szName);
    ArrayPushCell(g_spellPluginID, pluginID);
    ArrayPushCell(g_spellInvokeFuncID, invokeFuncID);
    ArrayPushCell(g_spellRevokeFuncID, revokeFuncID);
    
    g_spellCount++;
    
    return effectIdx;
}

CallInvoke(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    new pluginID = ArrayGetCell(g_spellPluginID, g_spellIdx);
    new funcID = ArrayGetCell(g_spellInvokeFuncID, g_spellIdx);
    
    if (callfunc_begin_i(funcID, pluginID) == 1) {
        callfunc_push_int(id);

        if (callfunc_end() == PLUGIN_CONTINUE) {
            ExecuteForward(g_fwEffectInvoke, g_fwResult, id, g_spellIdx);
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
  remove_task(TASKID_ROLL_END);
  remove_task(TASKID_EFFECT_END);
}
