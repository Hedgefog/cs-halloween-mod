#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <fun>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Gamemode Collector"
#define AUTHOR "Hedgehog Fog"

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

new Array:g_playerPoints;
new Array:g_teamPoints;
new bool:g_isOvertime;

new g_hGamemode;

new g_cvarTeamPointsLimit;
new g_cvarRoundTime;
new g_cvarRoundTimeOvertime;
new g_cvarWofEnabled;
new g_cvarWofDelay;
new g_cvarNpcDropChanceSpell;

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

    g_playerPoints = ArrayCreate(1, g_maxPlayers+1);
    for (new i = 0; i <= g_maxPlayers; ++i) {
        ArrayPushCell(g_playerPoints, 0);
    }

    g_teamPoints = ArrayCreate(1, TEAM_COUNT);
    for (new i = 0; i < TEAM_COUNT; ++i) {
        ArrayPushCell(g_teamPoints, 0);
    }

    g_cvarTeamPointsLimit = register_cvar("hwn_collector_teampoints_limit", "50");
    g_cvarRoundTime = register_cvar("hwn_collector_round_time", "10.0");
    g_cvarRoundTimeOvertime = register_cvar("hwn_collector_round_time_overtime", "30");
    g_cvarWofEnabled = register_cvar("hwn_collector_wof", "1");
    g_cvarWofDelay = register_cvar("hwn_collector_wof_delay", "90.0");
    g_cvarNpcDropChanceSpell = register_cvar("hwn_collector_npc_drop_chance_spell", "10.0");

    g_fwPlayerPointsChanged = CreateMultiForward("Hwn_Collector_Fw_PlayerPoints", ET_IGNORE, FP_CELL);
    g_fwTeamPointsChanged = CreateMultiForward("Hwn_Collector_Fw_TeamPoints", ET_IGNORE, FP_CELL);
    g_fwOvertime = CreateMultiForward("Hwn_Collector_Fw_Overtime", ET_IGNORE, FP_CELL);
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Collector_GetPlayerPoints", "Native_GetPlayerPoints");
    register_native("Hwn_Collector_SetPlayerPoints", "Native_SetPlayerPoints");
    register_native("Hwn_Collector_GetTeamPoints", "Native_GetTeamPoints");
    register_native("Hwn_Collector_SetTeamPoints", "Native_SetTeamPoints");
    register_native("Hwn_Collector_IsOvertime", "Native_IsOvertime");
}

public plugin_end()
{
    ArrayDestroy(g_playerPoints);
    ArrayDestroy(g_teamPoints);
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

    new points = GetPlayerPoints(id);

    if (!points) {
        return;
    }

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    new bpEnt = CE_Create(BACKPACK_ENTITY_CLASSNAME, vOrigin);

    if (bpEnt) {
        set_pev(bpEnt, pev_iuser2, points);
        dllfunc(DLLFunc_Spawn, bpEnt);

        static Float:vVelocity[3];
        UTIL_RandomVector(256.0, 256.0, vVelocity);
        set_pev(bpEnt, pev_velocity, vVelocity);
    }

    SetPlayerPoints(id, 0);
}

public OnTargetKilled(ent)
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    static bossEnt;
    Hwn_Bosses_GetCurrent(bossEnt);

    if (ent != bossEnt && pev(ent, pev_flags) & FL_MONSTER) { // Monster kill reward
        static Float:vOrigin[3];
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

public Hwn_Gamemode_Fw_NewRound()
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }

    ResetVariables();
    ClearWofTasks();
    SetWofTask();

    g_isOvertime = false;
}

public Hwn_Gamemode_Fw_RoundStart()
{
    if (g_hGamemode != Hwn_Gamemode_GetCurrent()) {
        return;
    }
    
    new roundTime = floatround(get_pcvar_float(g_cvarRoundTime) * 60);
    Hwn_Gamemode_SetRoundTime(roundTime);
}

public Hwn_Gamemode_Fw_RoundExpired()
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
        if (overtime > 0) {
            new roundTime = Hwn_Gamemode_GetRoundTime() + overtime;
            Hwn_Gamemode_SetRoundTime(roundTime);

            g_isOvertime = true;

            ExecuteForward(g_fwOvertime, g_fwResult, overtime);
        } else {
            Hwn_Gamemode_DispatchWin(3);
        }
    } else {
        new winnerTeam = tTeamPoints > ctTeamPoints ? 1 : 2;
        Hwn_Gamemode_DispatchWin(winnerTeam);
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

/*--------------------------------[ Methods ]--------------------------------*/

GetPlayerPoints(id)
{
    return ArrayGetCell(g_playerPoints, id);
}

SetPlayerPoints(id, count, bool:silent = false)
{
    ArraySetCell(g_playerPoints, id, count);

    if (!silent) {
        ExecuteForward(g_fwPlayerPointsChanged, g_fwResult, id);
    }
}

GetTeamPoints(team)
{
    return ArrayGetCell(g_teamPoints, team);
}

SetTeamPoints(team, count, bool:silent = false)
{
    ArraySetCell(g_teamPoints, team, count);

    new teamPointsLimit = get_pcvar_num(g_cvarTeamPointsLimit);
    if (count >= teamPointsLimit) {
        Hwn_Gamemode_DispatchWin(team);
    }

    if (!silent) {
        ExecuteForward(g_fwTeamPointsChanged, g_fwResult, team);
    }
}

ResetVariables()
{
    for (new team = 0; team < TEAM_COUNT; ++team) {
        SetTeamPoints(team, 0, .silent = true);
    }

    for (new id = 1; id <= g_maxPlayers; ++id) {
        SetPlayerPoints(id, 0, .silent = true);
        Hwn_Spell_SetPlayerSpell(id, -1, 0);
    }
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

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskWofRoll()
{
    Hwn_Wof_Roll();
}
