#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <engine>

#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>
#include <api_player_cosmetic>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Bosses"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#define TASKID_SPAWN_BOSS 0
#define TASKID_REMOVE_BOSS 1

#define BOSS_TARGET_ENTITY_CLASSNAME "hwn_boss_target"
#define BOSS_SPAWN_DAMAGE 1000.0

new const g_szSndBossSpawn[] = "hwn/misc/halloween_boss_summoned.wav";
new const g_szSndBossDefeat[] = "hwn/misc/halloween_boss_defeated.wav";
new const g_szSndBossEscape[] = "hwn/misc/halloween_boss_escape.wav";
new const g_szSndCongratulations[] = "hwn/misc/congratulations.wav";

new g_cvarBossSpawnDelay;
new g_cvarBossLifeTime;
new g_cvarBossMinDamageToWin;
new g_cvarBossPve;

new g_fwResult;
new g_fwBossSpawn;
new g_fwBossKill;
new g_fwBossEscape;
new g_fwBossTeleport;
new g_fwWinner;

new Array:g_bosses;
new Array:g_bossesNames;
new Array:g_bossesDictKeys;
new Array:g_bossSpawnPoints;

new g_playerTotalDamage[MAX_PLAYERS + 1] = { 0, ... };

new g_bossEnt = -1;
new g_bossIdx = -1;
new g_bossSpawnPoint;

new g_maxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTargetTakeDamage", .Post = 1);
    RegisterHam(Ham_Touch, "trigger_hurt", "OnHurtTouch", .Post = 0);
    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage", .Post = 0);

    g_cvarBossSpawnDelay = register_cvar("hwn_boss_spawn_delay", "300.0");
    g_cvarBossLifeTime = register_cvar("hwn_boss_life_time", "120.0");
    g_cvarBossMinDamageToWin = register_cvar("hwn_boss_min_damage_to_win", "300");
    g_cvarBossPve = register_cvar("hwn_boss_pve", "0");

    g_fwBossSpawn = CreateMultiForward("Hwn_Bosses_Fw_BossSpawn", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwBossKill = CreateMultiForward("Hwn_Bosses_Fw_BossKill", ET_IGNORE, FP_CELL);
    g_fwBossEscape = CreateMultiForward("Hwn_Bosses_Fw_BossEscape", ET_IGNORE, FP_CELL);
    g_fwBossTeleport = CreateMultiForward("Hwn_Bosses_Fw_BossTeleport", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwWinner = CreateMultiForward("Hwn_Bosses_Fw_Winner", ET_IGNORE, FP_CELL, FP_CELL);

    register_concmd("hwn_boss_spawn", "OnClCmd_SpawnBoss", ADMIN_CVAR);

    g_maxPlayers = get_maxplayers();

    CreateBossSpawnTask();
}

public plugin_end()
{
    if (g_bosses != Invalid_Array) {
        ArrayDestroy(g_bosses);
        ArrayDestroy(g_bossesNames);
        ArrayDestroy(g_bossesDictKeys);
    }

    if (g_bossSpawnPoints != Invalid_Array) {
        ArrayDestroy(g_bossSpawnPoints);
    }
}

public plugin_precache()
{
    CE_RegisterHook(CEFunction_Spawn, BOSS_TARGET_ENTITY_CLASSNAME, "OnBossTargetSpawn");

    precache_sound(g_szSndBossSpawn);
    precache_sound(g_szSndBossDefeat);
    precache_sound(g_szSndBossEscape);
    precache_sound(g_szSndCongratulations);
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Bosses_Register", "Native_Register");
    register_native("Hwn_Bosses_Spawn", "Native_Spawn");
    register_native("Hwn_Bosses_GetCurrent", "Native_GetCurrent");
    register_native("Hwn_Bosses_GetName", "Native_GetName");
    register_native("Hwn_Bosses_GetDictionaryKey", "Native_GetDictionaryKey");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
    new szClassname[32];
    get_string(1, szClassname, charsmax(szClassname));

    new szName[32];
    get_string(2, szName, charsmax(szName));

    if (!g_bosses) {
        g_bosses = ArrayCreate(32, 8);
        g_bossesNames = ArrayCreate(32, 8);
        g_bossesDictKeys = ArrayCreate(48, 8);
    }

    new idx = ArraySize(g_bosses);
    ArrayPushString(g_bosses, szClassname);
    ArrayPushString(g_bossesNames, szName);

    new szDictKey[48];
    UTIL_CreateDictKey(szName, "HWN_BOSS_", szDictKey, charsmax(szDictKey));

    if (UTIL_IsLocalizationExists(szDictKey)) {
        ArrayPushString(g_bossesDictKeys, szDictKey);
    } else {
        ArrayPushString(g_bossesDictKeys, "");
    }

    CE_RegisterHook(CEFunction_Remove, szClassname, "OnBossRemove");

    return idx;
}

public Native_GetCurrent(pluginID, argc)
{
    set_param_byref(1, g_bossEnt);
    return g_bossIdx;
}

public Native_Spawn(pluginID, argc)
{
    SpawnBoss();
}

public Native_GetName(pluginID, argc)
{
    new bossIdx = get_param(1);
    new maxlen = get_param(3);

    new szName[32];
    ArrayGetString(g_bossesNames, bossIdx, szName, charsmax(szName));

    set_string(2, szName, maxlen);
}

public Native_GetDictionaryKey(pluginID, argc)
{
    new bossIdx = get_param(1);
    new maxlen = get_param(3);

    static szDictKey[48];
    ArrayGetString(g_bossesDictKeys, bossIdx, szDictKey, charsmax(szDictKey));

    set_string(2, szDictKey, maxlen);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver(id)
{
    g_playerTotalDamage[id] = 0;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnClCmd_SpawnBoss(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1)) {
        return PLUGIN_HANDLED;
    }

    SpawnBoss();

    return PLUGIN_HANDLED;
}

public OnBossTargetSpawn(ent)
{
    if (!g_bossSpawnPoints) {
        g_bossSpawnPoints = ArrayCreate(3);
    }

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    ArrayPushArray(g_bossSpawnPoints, vOrigin);

    CE_Remove(ent);
}

public OnBossRemove(ent)
{
    if (g_bossEnt != ent) {
        return;
    }

    if (pev(ent, pev_deadflag) != DEAD_NO) {
        client_cmd(0, "spk %s", g_szSndBossDefeat);
        ExecuteForward(g_fwBossKill, g_fwResult, g_bossEnt);
        SelectWinners();
    } else {
        client_cmd(0, "spk %s", g_szSndBossEscape);
        ExecuteForward(g_fwBossEscape, g_fwResult, g_bossEnt);
    }

    g_bossEnt = -1;
    g_bossIdx = -1;

    remove_task(TASKID_REMOVE_BOSS);

    CreateBossSpawnTask();
}

public OnTargetTakeDamage(ent, inflictor, attacker, Float:fDamage)
{
    if (ent != g_bossEnt) {
        return HAM_IGNORED;
    }

    if (!UTIL_IsPlayer(attacker)) {
        return HAM_IGNORED;
    }

    g_playerTotalDamage[attacker] += floatround(fDamage);

    return HAM_HANDLED;
}

public OnPlayerTakeDamage(id, inflictor, attacker, Float:fDamage)
{
    if (g_bossIdx == -1) {
        return HAM_IGNORED;
    }

    if (!UTIL_IsPlayer(id)) {
        return HAM_IGNORED;
    }

    if (!UTIL_IsPlayer(attacker)) {
        return HAM_IGNORED;
    }

    if (get_pcvar_num(g_cvarBossPve) > 0) {
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

public OnHurtTouch(ent, toucher)
{
    if (toucher != g_bossEnt) {
        return HAM_IGNORED;
    }

    new Float:vOrigin[3];
    ArrayGetArray(g_bossSpawnPoints, g_bossSpawnPoint, vOrigin);
    engfunc(EngFunc_SetOrigin, g_bossEnt, vOrigin);

    ExecuteForward(g_fwBossTeleport, g_fwResult, g_bossEnt, g_bossIdx);

    return HAM_SUPERCEDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

SpawnBoss()
{
    if (g_bossEnt != -1) {
        return;
    }

    if (g_bosses == Invalid_Array) {
        return;
    }

    if (g_bossSpawnPoints == Invalid_Array) {
        return;
    }

    ResetPlayerTotalDamage();

    new bossCount = ArraySize(g_bosses);
    new bossIdx = random(bossCount);

    static szClassname[32];
    ArrayGetString(g_bosses, bossIdx, szClassname, charsmax(szClassname));

    new targetCount = ArraySize(g_bossSpawnPoints);
    new targetIdx = random(targetCount);

    new Float:vOrigin[3];
    ArrayGetArray(g_bossSpawnPoints, targetIdx, vOrigin);

    g_bossEnt = CE_Create(szClassname, vOrigin);

    if (g_bossEnt == -1) {
        return;
    }

    g_bossIdx = bossIdx;
    g_bossSpawnPoint = targetIdx;

    dllfunc(DLLFunc_Spawn, g_bossEnt);
    client_cmd(0, "spk %s", g_szSndBossSpawn);
    IntersectKill();

    new Float:fLifeTime = get_pcvar_float(g_cvarBossLifeTime);

    remove_task(TASKID_SPAWN_BOSS);
    set_task(fLifeTime, "TaskRemoveBoss", TASKID_REMOVE_BOSS);
    ExecuteForward(g_fwBossSpawn, g_fwResult, g_bossEnt, fLifeTime);
}

IntersectKill()
{
    if (g_bossEnt == -1) {
        return;
    }

    for (new id = 1; id <= g_maxPlayers; ++id) {
        if (!is_user_connected(id)) {
            continue;
        }

        if (!is_user_alive(id)) {
            continue;
        }

        if (UTIL_EntityIntersects(id, g_bossEnt)) {
            ExecuteHamB(Ham_TakeDamage, id, g_bossEnt, g_bossEnt, BOSS_SPAWN_DAMAGE, DMG_ALWAYSGIB);
        }
    }
}

CreateBossSpawnTask()
{
    remove_task(TASKID_SPAWN_BOSS);
    set_task(get_pcvar_float(g_cvarBossSpawnDelay), "TaskSpawnBoss", TASKID_SPAWN_BOSS);
}

ResetPlayerTotalDamage()
{
    for (new i = 1; i <= g_maxPlayers; ++i) {
        g_playerTotalDamage[i] = 0;
    }
}

SelectWinners()
{
    for (new id = 1; id <= g_maxPlayers; ++id)
    {
        if (!is_user_connected(id)) {
            continue;
        }

        new damage = g_playerTotalDamage[id];
        if (damage >= get_pcvar_num(g_cvarBossMinDamageToWin))
        {
            ExecuteForward(g_fwWinner, g_fwResult, id, damage);

            static cvarGiftCosmeticMaxTime;
            if (!cvarGiftCosmeticMaxTime) {
                cvarGiftCosmeticMaxTime = get_cvar_pointer("hwn_gifts_cosmetic_max_time");
            }

            new count = Hwn_Cosmetic_GetCount();
            new cosmetic = Hwn_Cosmetic_GetCosmetic(random(count));

            PCosmetic_Give(id, cosmetic, PCosmetic_Type_Unusual, get_pcvar_num(cvarGiftCosmeticMaxTime));

            client_cmd(id, "spk %s", g_szSndCongratulations);
        }
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskSpawnBoss()
{
    SpawnBoss();
}

public TaskRemoveBoss()
{
    CE_Remove(g_bossEnt);
}