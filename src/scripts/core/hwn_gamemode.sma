#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_rounds>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Gamemode"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_RESPAWN_PLAYER 1000
#define TASKID_SUM_SPAWN_PROTECTION 2000

#define SPAWN_RANGE 192.0

new g_fwResult;
new g_fwGamemodeActivated;

new g_fmFwSpawn;

new g_cvarRespawnTime;
new g_cvarSpawnProtectionTime;
new g_cvarNewRoundDelay;

new g_gamemode = -1;
new g_defaultGamemode = -1;

new Trie:g_gamemodeIndex;
new Array:g_gamemodeName;
new Array:g_gamemodeFlags;
new Array:g_gamemodePluginID;
new g_gamemodeCount = 0;

new g_playerFirstSpawnFlag = 0;
new Array:g_tSpawnPoints;
new Array:g_ctSpawnPoints;

new g_maxPlayers;

static g_szEquipmentMenuTitle[32];

public plugin_precache()
{
    register_dictionary("hwn.txt");
    format(g_szEquipmentMenuTitle, charsmax(g_szEquipmentMenuTitle), "%L", LANG_SERVER, "HWN_EQUIPMENT_MENU_TITLE");

    g_fwGamemodeActivated = CreateMultiForward("Hwn_Gamemode_Fw_Activated", ET_IGNORE, FP_CELL);

    g_fmFwSpawn = register_forward(FM_Spawn, "OnSpawn", 1);

    g_tSpawnPoints = ArrayCreate(3);
    g_ctSpawnPoints = ArrayCreate(3);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    if (g_gamemode < 0 && g_defaultGamemode >= 0) {
        SetGamemode(g_defaultGamemode);
    }

    Round_HookCheckWinConditions("OnCheckWinConditions");

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);

    register_message(get_user_msgid("ClCorpse"), "OnMessage_ClCorpse");

    register_clcmd("joinclass", "OnClCmd_JoinClass");
    register_clcmd("menuselect", "OnClCmd_JoinClass");

    g_maxPlayers = get_maxplayers();

    g_cvarRespawnTime = register_cvar("hwn_gamemode_respawn_time", "5.0");
    g_cvarSpawnProtectionTime = register_cvar("hwn_gamemode_spawn_protection_time", "3.0");
    g_cvarNewRoundDelay = register_cvar("hwn_gamemode_new_round_delay", "10.0");

    register_forward(FM_SetModel, "OnSetModel");

    unregister_forward(FM_Spawn, g_fmFwSpawn, 1);
}

public OnSpawn(ent)
{
    if (!pev_valid(ent)) {
        return;
    }

    new szClassname[32];
    pev(ent, pev_classname, szClassname, charsmax(szClassname));

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    if (equal(szClassname, "info_player_start")) {
        ArrayPushArray(g_ctSpawnPoints, vOrigin);
    } else if(equal(szClassname, "info_player_deathmatch")) {
        ArrayPushArray(g_tSpawnPoints, vOrigin);
    }
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Gamemode_Register", "Native_Register");
    register_native("Hwn_Gamemode_Activate", "Native_Activate");
    register_native("Hwn_Gamemode_DispatchWin", "Native_DispatchWin");
    register_native("Hwn_Gamemode_GetCurrent", "Native_GetCurrent");
    register_native("Hwn_Gamemode_GetHandler", "Native_GetHandler");
    register_native("Hwn_Gamemode_IsPlayerOnSpawn", "Native_IsPlayerOnSpawn");
    register_native("Hwn_Gamemode_GetFlags", "Native_GetFlags");
}

public plugin_end()
{
    if (!g_gamemodeCount) {
        TrieDestroy(g_gamemodeIndex);
        ArrayDestroy(g_gamemodeName);
        ArrayDestroy(g_gamemodeFlags);
        ArrayDestroy(g_gamemodePluginID);
    }

    ArrayDestroy(g_tSpawnPoints);
    ArrayDestroy(g_ctSpawnPoints);
}

public client_connect(id)
{
    g_playerFirstSpawnFlag |= (1 << (id & 31));
}

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    remove_task(id + TASKID_SUM_RESPAWN_PLAYER);
    remove_task(id + TASKID_SUM_SPAWN_PROTECTION);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new Hwn_GamemodeFlags:flags = Hwn_GamemodeFlags:get_param(2);

    if (!g_gamemodeCount) {
        g_gamemodeIndex = TrieCreate();
        g_gamemodeName = ArrayCreate(32);
        g_gamemodeFlags = ArrayCreate();
        g_gamemodePluginID = ArrayCreate();
    }

    new index = g_gamemodeCount;
    TrieSetCell(g_gamemodeIndex, szName, index);
    ArrayPushString(g_gamemodeName, szName);
    ArrayPushCell(g_gamemodeFlags, flags);
    ArrayPushCell(g_gamemodePluginID, pluginID);

    if ((flags & Hwn_GamemodeFlag_Default) && g_defaultGamemode < 0) {
        g_defaultGamemode = index;
    }

    g_gamemodeCount++;

    return index;
}

public bool:Native_Activate(pluginID, argc)
{
    new gamemode = GetGamemodeByPluginID(pluginID);
    if (gamemode < 0) {
        return false;
    }

    SetGamemode(gamemode);

    return true;
}

public Native_DispatchWin(pluginID, argc)
{
    if (!g_gamemodeCount) {
        return;
    }

    if (pluginID != ArrayGetCell(g_gamemodePluginID, g_gamemode)) {
        return;
    }

    new team = get_param(1);
    DispatchWin(team);
}

public Native_GetCurrent(pluginID, argc)
{
    return g_gamemode;
}

public Native_GetHandler(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new gamemode;
    if (TrieGetCell(g_gamemodeIndex, szName, gamemode)) {
        return gamemode;
    }

    return -1;
}

public Native_IsPlayerOnSpawn(pluginID, argc)
{
    new id = get_param(1);
    new bool:ignoreTeam = bool:get_param(2);

    return IsPlayerOnSpawn(id, ignoreTeam);
}

public Hwn_GamemodeFlags:Native_GetFlags(pluginID, argc)
{
    if (!g_gamemodeCount) {
        return Hwn_GamemodeFlag_None;
    }

    return ArrayGetCell(g_gamemodeFlags, g_gamemode);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Hwn_PEquipment_Event_Changed(id)
{
    if (!g_gamemodeCount) {
        return;
    }

    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if (~flags & Hwn_GamemodeFlag_SpecialEquip) {
        return;
    }

    if (IsPlayerOnSpawn(id)) {
        Hwn_PEquipment_Equip(id);
    }
}

public OnClCmd_JoinClass(id)
{
    if (!g_gamemodeCount) {
        return PLUGIN_CONTINUE;
    }

    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if (~flags & Hwn_GamemodeFlag_RespawnPlayers) {
        return PLUGIN_CONTINUE;
    }

    #if defined _reapi_included
        new menu = get_member(id, m_iMenu);
        new joinState = get_member(id, m_iJoiningState);
    #else
        new menu = get_pdata_int(id, m_iMenu);
        new joinState = get_pdata_int(id, m_iJoiningState);
    #endif

    if (menu != MENU_CHOOSEAPPEARANCE) {
        return PLUGIN_CONTINUE;
    }

    new team = UTIL_GetPlayerTeam(id);
    new bool:inPlayableTeam = team == 1 || team == 2;

    if (joinState != JOIN_CHOOSEAPPEARANCE && (joinState || !inPlayableTeam)) {
        return PLUGIN_CONTINUE;
    }

    //ConnorMcLeod
    new command[11], arg1[32];
    read_argv(0, command, charsmax(command));
    read_argv(1, arg1, charsmax(arg1));
    engclient_cmd(id, command, arg1);

    ExecuteHam(Ham_Player_PreThink, id);

    if (!is_user_alive(id)) {
        SetRespawnTask(id);
    }

    return PLUGIN_HANDLED;
}

public OnMessage_ClCorpse()
{
    if (!g_gamemodeCount) {
        return PLUGIN_CONTINUE;
    }

    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if (flags & Hwn_GamemodeFlag_RespawnPlayers) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public OnPlayerSpawn(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    if (!g_gamemodeCount) {
        return;
    }

    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if ((flags & Hwn_GamemodeFlag_SpecialEquip)) {
        Hwn_PEquipment_Equip(id);

        if (g_playerFirstSpawnFlag & (1 << (id & 31))) {
            Hwn_PEquipment_ShowMenu(id);
            g_playerFirstSpawnFlag &= ~(1 << (id & 31));
        }
    }

    if (flags & Hwn_GamemodeFlag_RespawnPlayers) {
        set_pev(id, pev_takedamage, DAMAGE_NO);
        remove_task(id + TASKID_SUM_SPAWN_PROTECTION);
        set_task(get_pcvar_float(g_cvarSpawnProtectionTime), "TaskDisableSpawnProtection", id + TASKID_SUM_SPAWN_PROTECTION);
    }
}

public OnPlayerKilled(id)
{
    if (!g_gamemodeCount) {
        return;
    }

    if (g_gamemode < 0) {
        return;
    }

    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if ((flags & Hwn_GamemodeFlag_RespawnPlayers) && !Round_IsRoundEnd()) {
        SetRespawnTask(id);
    }
}

public OnSetModel(ent)
{
    if (!g_gamemodeCount) {
        return;
    }

    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if (~flags & Hwn_GamemodeFlag_SpecialEquip) {
        return;
    }

    static szClassname[32];
    pev(ent, pev_classname, szClassname, charsmax(szClassname));

    if (szClassname[9] == '^0' && szClassname[0] == 'w' && szClassname[6] == 'b') {
        dllfunc(DLLFunc_Think, ent);
    }
}

public MenuItem_ChangeEquipment(id)
{
    Hwn_PEquipment_ShowMenu(id);
}

public OnCheckWinConditions()
{
    if (!g_gamemodeCount) {
        return PLUGIN_CONTINUE;
    }

    if (g_gamemode < 0) {
        return PLUGIN_CONTINUE;
    }

    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if ((flags & Hwn_GamemodeFlag_RespawnPlayers) && IsTeamExtermination()) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

/*--------------------------------[ Methods ]--------------------------------*/

SetGamemode(gamemode)
{
    g_gamemode = gamemode;
    new Hwn_GamemodeFlags:flags = ArrayGetCell(g_gamemodeFlags, g_gamemode);
    if (flags & Hwn_GamemodeFlag_SpecialEquip) {
        Hwn_Menu_AddItem(g_szEquipmentMenuTitle, "MenuItem_ChangeEquipment");
    }

    new szGamemodeName[32];
    ArrayGetString(g_gamemodeName, gamemode, szGamemodeName, charsmax(szGamemodeName));
    log_amx("[Hwn] Gamemode '%s' activated", szGamemodeName);

    ExecuteForward(g_fwGamemodeActivated, g_fwResult, gamemode);
}

GetGamemodeByPluginID(pluginID)
{
    for (new gamemode = 0; gamemode < g_gamemodeCount; ++gamemode) {
        new gamemodePluginID = ArrayGetCell(g_gamemodePluginID, gamemode);

        if (pluginID == gamemodePluginID) {
            return gamemode;
        }
    }

    return -1;
}

RespawnPlayer(id)
{
    if (!is_user_connected(id)) {
        return;
    }

    if (is_user_alive(id)) {
        return;
    }

    new team = UTIL_GetPlayerTeam(id);

    if (team != 1 && team != 2) {
        return;
    }

    ExecuteHamB(Ham_CS_RoundRespawn, id);
}

bool:IsPlayerOnSpawn(id, bool:ignoreTeam = false)
{
    new team = UTIL_GetPlayerTeam(id);
    if (team < 1 || team > 2) {
        return false;
    }

    return ignoreTeam
        ? IsPlayerOnTeamSpawn(id, 1) || IsPlayerOnTeamSpawn(id, 2)
        : IsPlayerOnTeamSpawn(id, team);
}

bool:IsPlayerOnTeamSpawn(id, team)
{
    new Array:spawnPoints = team == 1 ? g_tSpawnPoints : g_ctSpawnPoints;
    new spawnPointsSize = ArraySize(spawnPoints);

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    static Float:vSpawnOrigin[3];
    for (new i = 0; i < spawnPointsSize; ++i) {
        ArrayGetArray(spawnPoints, i, vSpawnOrigin);
        if (get_distance_f(vOrigin, vSpawnOrigin) <= SPAWN_RANGE) {
            return true;
        }
    }

    return false;
}

DispatchWin(team)
{
    new Float:fDelay = get_pcvar_float(g_cvarNewRoundDelay);
    Round_DispatchWin(team, fDelay);
}

bool:IsTeamExtermination()
{
    new bool:aliveT = false;
    new bool:aliveCT = false;

    for (new id = 1; id <= g_maxPlayers; ++id) {
        if (is_user_connected(id) && is_user_alive(id)) {
            new team = UTIL_GetPlayerTeam(id);

            if (team == 1) {
                aliveT = true;

                if (aliveCT) {
                    return false;
                }
            } else if (team == 2) {
                aliveCT = true;

                if (aliveT) {
                    return false;
                }
            }
        }
    }

    return true;
}

SetRespawnTask(id)
{
    set_task(get_pcvar_float(g_cvarRespawnTime), "TaskRespawnPlayer", id + TASKID_SUM_RESPAWN_PLAYER);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskRespawnPlayer(taskID)
{
    new id = taskID - TASKID_SUM_RESPAWN_PLAYER;

    RespawnPlayer(id);
}

public TaskDisableSpawnProtection(taskID)
{
    new id = taskID - TASKID_SUM_SPAWN_PROTECTION;

    set_pev(id, pev_takedamage, DAMAGE_AIM);
}
