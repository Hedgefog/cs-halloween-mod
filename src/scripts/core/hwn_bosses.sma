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

#define TASKID_SPAWN_BOSS 0
#define TASKID_REMOVE_BOSS 1

#define BOSS_SPAWN_DAMAGE 1000.0

new const g_szSndBossSpawn[] = "hwn/misc/halloween_boss_summoned.wav";
new const g_szSndBossDefeat[] = "hwn/misc/halloween_boss_defeated.wav";
new const g_szSndBossEscape[] = "hwn/misc/halloween_boss_escape.wav";
new const g_szSndCongratulations[] = "hwn/misc/congratulations.wav";

new g_pCvarBossSpawnDelay;
new g_pCvarBossLifeTime;
new g_pCvarBossMinDamageToWin;
new g_pCvarBossPve;

new g_fwResult;
new g_fwBossSpawn;
new g_fwBossKill;
new g_fwBossEscape;
new g_fwBossRemove;
new g_fwBossTeleport;
new g_fwWinner;

new Array:g_irgpBosses;
new Array:g_irgszBossesNames;
new Array:g_irgszBossesDictKeys;
new Array:g_irgBossSpawnPoints;

new g_rgiPlayerTotalDamage[MAX_PLAYERS + 1];

new g_pBoss = -1;
new g_iBossIdx = -1;
new g_iBossSpawnPoint;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);
    RegisterHam(Ham_Touch, "trigger_hurt", "HamHook_Hurt_Touch", .Post = 0);
    RegisterHamPlayer(Ham_TakeDamage, "HamHook_Player_TakeDamage", .Post = 0);

    g_pCvarBossSpawnDelay = register_cvar("hwn_boss_spawn_delay", "300.0");
    g_pCvarBossLifeTime = register_cvar("hwn_boss_life_time", "120.0");
    g_pCvarBossMinDamageToWin = register_cvar("hwn_boss_min_damage_to_win", "300");
    g_pCvarBossPve = register_cvar("hwn_boss_pve", "0");

    g_fwBossSpawn = CreateMultiForward("Hwn_Bosses_Fw_BossSpawn", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwBossKill = CreateMultiForward("Hwn_Bosses_Fw_BossKill", ET_IGNORE, FP_CELL);
    g_fwBossEscape = CreateMultiForward("Hwn_Bosses_Fw_BossEscape", ET_IGNORE, FP_CELL);
    g_fwBossRemove = CreateMultiForward("Hwn_Bosses_Fw_BossRemove", ET_IGNORE, FP_CELL);
    g_fwBossTeleport = CreateMultiForward("Hwn_Bosses_Fw_BossTeleport", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwWinner = CreateMultiForward("Hwn_Bosses_Fw_Winner", ET_IGNORE, FP_CELL, FP_CELL);

    register_concmd("hwn_boss_spawn", "Command_SpawnBoss", ADMIN_CVAR);
    register_concmd("hwn_boss_abort", "Command_AbortBoss", ADMIN_CVAR);

    CreateBossSpawnTask();
}

public plugin_end() {
    if (g_irgpBosses != Invalid_Array) {
        ArrayDestroy(g_irgpBosses);
        ArrayDestroy(g_irgszBossesNames);
        ArrayDestroy(g_irgszBossesDictKeys);
    }

    if (g_irgBossSpawnPoints != Invalid_Array) {
        ArrayDestroy(g_irgBossSpawnPoints);
    }
}

public plugin_precache() {
    precache_sound(g_szSndBossSpawn);
    precache_sound(g_szSndBossDefeat);
    precache_sound(g_szSndBossEscape);
    precache_sound(g_szSndCongratulations);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_Bosses_Register", "Native_Register");
    register_native("Hwn_Bosses_Spawn", "Native_Spawn");
    register_native("Hwn_Bosses_GetCurrent", "Native_GetCurrent");
    register_native("Hwn_Bosses_GetName", "Native_GetName");
    register_native("Hwn_Bosses_GetDictionaryKey", "Native_GetDictionaryKey");
    register_native("Hwn_Bosses_AddTarget", "Native_AddTarget");
    register_native("Hwn_Bosses_GetTarget", "Native_GetTarget");
    register_native("Hwn_Bosses_GetTargetCount", "Native_GetTargetCount");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
    new szClassName[32];
    get_string(1, szClassName, charsmax(szClassName));

    new szName[32];
    get_string(2, szName, charsmax(szName));

    if (!g_irgpBosses) {
        g_irgpBosses = ArrayCreate(32, 8);
        g_irgszBossesNames = ArrayCreate(32, 8);
        g_irgszBossesDictKeys = ArrayCreate(48, 8);
    }

    new idx = ArraySize(g_irgpBosses);
    ArrayPushString(g_irgpBosses, szClassName);
    ArrayPushString(g_irgszBossesNames, szName);

    new szDictKey[48];
    UTIL_CreateDictKey(szName, "HWN_BOSS_", szDictKey, charsmax(szDictKey));

    if (UTIL_IsLocalizationExists(szDictKey)) {
        ArrayPushString(g_irgszBossesDictKeys, szDictKey);
    } else {
        ArrayPushString(g_irgszBossesDictKeys, "");
    }

    CE_RegisterHook(CEFunction_Remove, szClassName, "OnBossRemove");

    return idx;
}

public Native_GetCurrent(iPluginId, iArgc) {
    set_param_byref(1, g_pBoss);
    return g_iBossIdx;
}

public Native_Spawn(iPluginId, iArgc) {
    SpawnBoss();
}

public Native_GetName(iPluginId, iArgc) {
    new iBossIdx = get_param(1);
    new iLen = get_param(3);

    new szName[32];
    ArrayGetString(g_irgszBossesNames, iBossIdx, szName, charsmax(szName));

    set_string(2, szName, iLen);
}

public Native_GetDictionaryKey(iPluginId, iArgc) {
    new iBossIdx = get_param(1);
    new iLen = get_param(3);

    static szDictKey[48];
    ArrayGetString(g_irgszBossesDictKeys, iBossIdx, szDictKey, charsmax(szDictKey));

    set_string(2, szDictKey, iLen);
}

public Native_AddTarget(iPluginId, iArgc) {
    new Float:vecOrigin[3];
    get_array_f(1, vecOrigin, sizeof(vecOrigin));

    if (!g_irgBossSpawnPoints) {
        g_irgBossSpawnPoints = ArrayCreate(3);
    }
    
    return ArrayPushArray(g_irgBossSpawnPoints, vecOrigin);
}

public Native_GetTarget(iPluginId, iArgc) {
    return g_irgBossSpawnPoints == Invalid_Array ? 0 : ArraySize(g_irgBossSpawnPoints);
}

public Native_GetTargetCount(iPluginId, iArgc) {
    new iTarget = get_param(1);

    new Float:vecOrigin[3];
    ArrayGetArray(g_irgBossSpawnPoints, iTarget, vecOrigin);

    set_array_f(2, vecOrigin, sizeof(vecOrigin));
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver(pPlayer) {
    g_rgiPlayerTotalDamage[pPlayer] = 0;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Command_SpawnBoss(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 1)) {
        return PLUGIN_HANDLED;
    }

    SpawnBoss();

    return PLUGIN_HANDLED;
}

public Command_AbortBoss(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 1)) {
        return PLUGIN_HANDLED;
    }

    if (g_pBoss != -1) {
        CE_Remove(g_pBoss);
    }

    return PLUGIN_HANDLED;
}

public OnBossRemove(pEntity) {
    if (g_pBoss != pEntity) {
        return;
    }

    if (pev(pEntity, pev_deadflag) != DEAD_NO) {
        client_cmd(0, "spk %s", g_szSndBossDefeat);
        ExecuteForward(g_fwBossKill, g_fwResult, g_pBoss);
        SelectWinners();
    } else {
        client_cmd(0, "spk %s", g_szSndBossEscape);
        ExecuteForward(g_fwBossEscape, g_fwResult, g_pBoss);
    }

    ExecuteForward(g_fwBossRemove, _, g_pBoss);

    g_pBoss = -1;
    g_iBossIdx = -1;

    remove_task(TASKID_REMOVE_BOSS);

    CreateBossSpawnTask();
}

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage) {
    if (pEntity != g_pBoss) {
        return HAM_IGNORED;
    }

    if (!IS_PLAYER(pAttacker)) {
        return HAM_IGNORED;
    }

    g_rgiPlayerTotalDamage[pAttacker] += floatround(flDamage);

    return HAM_HANDLED;
}

public HamHook_Player_TakeDamage(pPlayer, pInflictor, pAttacker, Float:flDamage) {
    if (g_iBossIdx == -1) {
        return HAM_IGNORED;
    }

    if (!IS_PLAYER(pPlayer)) {
        return HAM_IGNORED;
    }

    if (!IS_PLAYER(pAttacker)) {
        return HAM_IGNORED;
    }

    if (get_pcvar_num(g_pCvarBossPve) > 0) {
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

public HamHook_Hurt_Touch(pEntity, pToucher) {
    if (pToucher != g_pBoss) {
        return HAM_IGNORED;
    }

    new Float:vecOrigin[3];
    ArrayGetArray(g_irgBossSpawnPoints, g_iBossSpawnPoint, vecOrigin);
    engfunc(EngFunc_SetOrigin, g_pBoss, vecOrigin);

    ExecuteForward(g_fwBossTeleport, g_fwResult, g_pBoss, g_iBossIdx);

    return HAM_SUPERCEDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

SpawnBoss() {
    if (g_pBoss != -1) {
        return;
    }

    if (g_irgpBosses == Invalid_Array) {
        return;
    }

    if (g_irgBossSpawnPoints == Invalid_Array) {
        return;
    }

    ResetPlayerTotalDamage();

    new iBossesNum = ArraySize(g_irgpBosses);
    new iBossIdx = random(iBossesNum);

    static szClassName[32];
    ArrayGetString(g_irgpBosses, iBossIdx, szClassName, charsmax(szClassName));

    new iPointsNum = ArraySize(g_irgBossSpawnPoints);
    new iPointIdx = random(iPointsNum);

    new Float:vecOrigin[3];
    ArrayGetArray(g_irgBossSpawnPoints, iPointIdx, vecOrigin);

    g_pBoss = CE_Create(szClassName, vecOrigin);

    if (g_pBoss == -1) {
        return;
    }

    g_iBossIdx = iBossIdx;
    g_iBossSpawnPoint = iPointIdx;

    dllfunc(DLLFunc_Spawn, g_pBoss);
    client_cmd(0, "spk %s", g_szSndBossSpawn);
    IntersectKill();

    new Float:flLifeTime = get_pcvar_float(g_pCvarBossLifeTime);

    remove_task(TASKID_SPAWN_BOSS);
    set_task(flLifeTime, "TaskRemoveBoss", TASKID_REMOVE_BOSS);
    ExecuteForward(g_fwBossSpawn, g_fwResult, g_pBoss, flLifeTime);
}

IntersectKill() {
    if (g_pBoss == -1) {
        return;
    }

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_connected(pPlayer)) {
            continue;
        }

        if (!is_user_alive(pPlayer)) {
            continue;
        }

        if (UTIL_EntityIntersects(pPlayer, g_pBoss)) {
            ExecuteHamB(Ham_TakeDamage, pPlayer, g_pBoss, g_pBoss, BOSS_SPAWN_DAMAGE, DMG_ALWAYSGIB);
        }
    }
}

CreateBossSpawnTask() {
    remove_task(TASKID_SPAWN_BOSS);
    set_task(get_pcvar_float(g_pCvarBossSpawnDelay), "TaskSpawnBoss", TASKID_SPAWN_BOSS);
}

ResetPlayerTotalDamage() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        g_rgiPlayerTotalDamage[pPlayer] = 0;
    }
}

SelectWinners() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer)
    {
        if (!is_user_connected(pPlayer)) {
            continue;
        }

        new iTotalDamage = g_rgiPlayerTotalDamage[pPlayer];
        if (iTotalDamage >= get_pcvar_num(g_pCvarBossMinDamageToWin)) {
            ExecuteForward(g_fwWinner, g_fwResult, pPlayer, iTotalDamage);

            static pCvarGiftCosmeticMaxTime;
            if (!pCvarGiftCosmeticMaxTime) {
                pCvarGiftCosmeticMaxTime = get_cvar_pointer("hwn_gifts_cosmetic_max_time");
            }

            new iNum = Hwn_Cosmetic_GetCount();
            new iCosmetic = Hwn_Cosmetic_GetCosmetic(random(iNum));

            PCosmetic_Give(pPlayer, iCosmetic, PCosmetic_Type_Unusual, get_pcvar_num(pCvarGiftCosmeticMaxTime));

            client_cmd(pPlayer, "spk %s", g_szSndCongratulations);
        }
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskSpawnBoss() {
    SpawnBoss();
}

public TaskRemoveBoss() {
    CE_Remove(g_pBoss);
}