#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <fun>

#include <api_rounds>
#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Gamemode Collector"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#define BUCKET_ENTITY_CLASSNAME "hwn_bucket"
#define LOOT_ENTITY_CLASSNAME "hwn_item_pumpkin"
#define SPELLBOOK_ENTITY_CLASSNAME "hwn_item_spellbook"
#define BACKPACK_ENTITY_CLASSNAME "hwn_item_pumpkin_big"

#define TASKID_WOF_ROLL 1000

#define TEAM_COUNT 4

new g_fwResult;
new g_fwPlayerPointsChanged;
new g_fwTeamPointsChanged;
new g_fwOvertime;
new g_fwWinnerTeam;

new g_playerPoints[MAX_PLAYERS + 1] = { 0, ... };
new g_teamPoints[TEAM_COUNT];
new g_teamPointsToSpawnBoss;
new bool:g_isOvertime;

new g_hGamemode;

new g_cvarTeamPointsLimit;
new g_cvarRoundTime;
new g_cvarRoundTimeOvertime;
new g_cvarWofEnabled;
new g_cvarWofDelay;
new g_cvarNpcDropChanceSpell;
new g_cvarTeamPointsToBossSpawn;

new g_maxPlayers;

public plugin_precache()
{
    CE_RegisterHook(CEFunction_Spawn, BUCKET_ENTITY_CLASSNAME, "OnBucketSpawn");
    CE_RegisterHook(CEFunction_Picked, LOOT_ENTITY_CLASSNAME, "OnLootPickup");
    CE_RegisterHook(CEFunction_Picked, BACKPACK_ENTITY_CLASSNAME, "OnBackpackPickup");

    g_hGamemode = Hwn_Gamemode_Register(
        .szName = "Collector",
        .flags = (
            Hwn_GamemodeFlag_RespawnPlayers | Hwn_GamemodeFlag_SpecialEquip
        )
    );
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
    RegisterHam(Ham_Killed, CE_BASE_CLASSNAME, "OnTargetKilled", .Post = 1);

    register_message(get_user_msgid("StatusIcon"), "OnMessageStatusIcon");

    g_maxPlayers = get_maxplayers();

    g_cvarTeamPointsLimit = register_cvar("hwn_collector_teampoints_limit", "50");
    g_cvarRoundTime = register_cvar("hwn_collector_roundtime", "10.0");
    g_cvarRoundTimeOvertime = register_cvar("hwn_collector_roundtime_overtime", "30");
    g_cvarWofEnabled = register_cvar("hwn_collector_wof", "1");
    g_cvarWofDelay = register_cvar("hwn_collector_wof_delay", "90.0");
    g_cvarNpcDropChanceSpell = register_cvar("hwn_collector_npc_drop_chance_spell", "7.5");
    g_cvarTeamPointsToBossSpawn = register_cvar("hwn_collector_teampoints_to_boss_spawn", "20");

    g_fwPlayerPointsChanged = CreateMultiForward("Hwn_Collector_Fw_PlayerPoints", ET_IGNORE, FP_CELL);
    g_fwTeamPointsChanged = CreateMultiForward("Hwn_Collector_Fw_TeamPoints", ET_IGNORE, FP_CELL);
    g_fwOvertime = CreateMultiForward("Hwn_Collector_Fw_Overtime", ET_IGNORE, FP_CELL);
    g_fwWinnerTeam = CreateMultiForward("Hwn_Collector_Fw_WinnerTeam", ET_IGNORE, FP_CELL);
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Collector_GetPlayerPoints", "Native_GetPlayerPoints");
    register_native("Hwn_Collector_SetPlayerPoints", "Native_SetPlayerPoints");
    register_native("Hwn_Collector_GetTeamPoints", "Native_GetTeamPoints");
    register_native("Hwn_Collector_SetTeamPoints", "Native_SetTeamPoints");
    register_native("Hwn_Collector_IsOvertime", "Native_IsOvertime");
    register_native("Hwn_Collector_ObjectiveBlocked", "Native_ObjectiveBlocked");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_GetPlayerPoints(pluginID, argc)
{
    new id = get_param(1);

    return GetPlayerPoints(id);
}

public Native_SetPlayerPoints(pluginID, argc)
{
    new id = get_param(1);
    new count = get_param(2);

    SetPlayerPoints(id, count);
}

public Native_GetTeamPoints(pluginID, argc)
{
    new team = get_param(1);

    return GetTeamPoints(team);
}

public Native_SetTeamPoints(pluginID, argc)
{
    new team = get_param(1);
    new count = get_param(2);

    SetTeamPoints(team, count);
}

public bool:Native_IsOvertime(pluginID, argc)
{
    return g_isOvertime;
}

public bool:Native_ObjectiveBlocked(pluginID, argc)
{
    return Hwn_Bosses_GetCurrent() != -1;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnBucketSpawn(ent)
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        Hwn_Gamemode_Activate();
    }
}

public OnLootPickup(ent, id)
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    new points = GetPlayerPoints(id) + 1;
    SetPlayerPoints(id, points);
}

public OnBackpackPickup(ent, id)
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    new points = GetPlayerPoints(id) + pev(ent, pev_iuser2);
    SetPlayerPoints(id, points);
}

public OnMessageStatusIcon(msg, dest, id)
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return PLUGIN_CONTINUE;
    }

    new szIcon[8];
    get_msg_arg_string(2, szIcon, 7);

    if (equal(szIcon, "buyzone") && get_msg_arg_int(1)) {
        set_pdata_int(id, m_fClientMapZone, get_pdata_int(id, m_fClientMapZone) & ~(1<<0));
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public OnPlayerKilled(id)
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    ExtractPlayerPoints(id);
}

public OnTargetKilled(ent)
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    static bossEnt;
    Hwn_Bosses_GetCurrent(bossEnt);

    if (ent != bossEnt && pev(ent, pev_flags) & FL_MONSTER && !pev(ent, pev_team)) { // Monster kill reward
        new Float:vOrigin[3];
        pev(ent, pev_origin, vOrigin);

        new Float:fSpellChance = get_pcvar_float(g_cvarNpcDropChanceSpell);

        new ent = CE_Create(
            (
                fSpellChance && fSpellChance >= random_float(0.0, 100.0)
                    ? SPELLBOOK_ENTITY_CLASSNAME
                    : LOOT_ENTITY_CLASSNAME
            ),
            vOrigin
        );

        if (ent) {
            dllfunc(DLLFunc_Spawn, ent);
        }
    }
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded()
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    SetWofTask();
}

public Round_Fw_NewRound()
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    ResetVariables();
    ClearWofTasks();
    SetWofTask();

    g_isOvertime = false;
}

public Round_Fw_RoundStart()
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }
    
    new roundTime = floatround(get_pcvar_float(g_cvarRoundTime) * 60);
    Round_SetTime(roundTime);
}

public Round_Fw_RoundExpired()
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    if (get_pcvar_float(g_cvarRoundTime) <= 0.0) {
        return;
    }

    new tTeamPoints = GetTeamPoints(1);
    new ctTeamPoints = GetTeamPoints(2);

    if (tTeamPoints == ctTeamPoints) {
        new overtime = get_pcvar_num(g_cvarRoundTimeOvertime);
        if (tTeamPoints > 0 && overtime > 0) {
            new roundTime = Round_GetTime() + overtime;
            Round_SetTime(roundTime);

            g_isOvertime = true;

            ExecuteForward(g_fwOvertime, g_fwResult, overtime);
        } else {
            DispatchWin(3);
        }
    } else {
        DispatchWin(tTeamPoints > ctTeamPoints ? 1 : 2);
    }
}

public Hwn_Wof_Fw_Effect_End()
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    SetWofTask();
}

public Hwn_Wof_Fw_Roll_Start()
{
    ClearWofTasks();
}

public Hwn_Bosses_Fw_BossSpawn(ent, Float:fLifeTime)
{
    new roundTime = Round_GetTime() + floatround(fLifeTime);
    Round_SetTime(roundTime);
    g_teamPointsToSpawnBoss = 0;
}

/*--------------------------------[ Methods ]--------------------------------*/

GetPlayerPoints(id)
{
    return g_playerPoints[id];
}

SetPlayerPoints(id, count)
{
    g_playerPoints[id] = count;
    ExecuteForward(g_fwPlayerPointsChanged, g_fwResult, id);
}

bool:ExtractPlayerPoints(id)
{
    new points = GetPlayerPoints(id);

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    if (!Hwn_Gamemode_IsPlayerOnSpawn(id) && !points) {
        return false;
    }

    new bool:isBackpack = points > 1;
    new bpEnt = CE_Create(isBackpack ? BACKPACK_ENTITY_CLASSNAME : LOOT_ENTITY_CLASSNAME, vOrigin);
    if (!bpEnt) {
        return false;
    }

    if (isBackpack) {
        set_pev(bpEnt, pev_iuser2, points);
    }

    set_pev(bpEnt, pev_iuser1, Hwn_PumpkinType_Default);
    dllfunc(DLLFunc_Spawn, bpEnt);

    static Float:vVelocity[3];
    UTIL_RandomVector(256.0, 256.0, vVelocity);
    set_pev(bpEnt, pev_velocity, vVelocity);

    SetPlayerPoints(id, 0);

    return true;
}

GetTeamPoints(team)
{
    return g_teamPoints[team];
}

SetTeamPoints(team, count)
{
    new teamPointsToBossSpawn = get_pcvar_num(g_cvarTeamPointsToBossSpawn);
    if (teamPointsToBossSpawn > 0) {
        new countDiff = count - g_teamPoints[team];
        if (countDiff > 0) {
            g_teamPointsToSpawnBoss += countDiff;

            if (g_teamPointsToSpawnBoss >= teamPointsToBossSpawn) {
                g_teamPointsToSpawnBoss = 0;
                Hwn_Bosses_Spawn();
            }
        }
    }

    g_teamPoints[team] = count;

    new teamPointsLimit = get_pcvar_num(g_cvarTeamPointsLimit);
    if (count >= teamPointsLimit) {
        DispatchWin(team);
    }

    ExecuteForward(g_fwTeamPointsChanged, g_fwResult, team);
}

ResetVariables()
{
    for (new team = 0; team < TEAM_COUNT; ++team) {
        g_teamPoints[team] = 0;
    }

    for (new id = 1; id <= g_maxPlayers; ++id) {
        g_playerPoints[id] = 0;
        Hwn_Spell_SetPlayerSpell(id, -1, 0);
    }

    g_teamPointsToSpawnBoss = 0;
}

SetWofTask()
{
    if (get_pcvar_num(g_cvarWofEnabled) <= 0) {
        return;
    }

    remove_task(TASKID_WOF_ROLL);
    set_task(get_pcvar_float(g_cvarWofDelay), "TaskWofRoll", TASKID_WOF_ROLL);
}

ClearWofTasks()
{
    remove_task(TASKID_WOF_ROLL);
}

DispatchWin(team)
{
    Hwn_Gamemode_DispatchWin(team);
    ExecuteForward(g_fwWinnerTeam, g_fwResult, team);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskWofRoll()
{
    Hwn_Wof_Roll();
}
