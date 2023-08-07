#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include <api_rounds>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Gamemode"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_RESPAWN_PLAYER 1000
#define TASKID_SUM_SPAWN_PROTECTION 2000

#define SPAWN_RANGE 192.0

new g_fwGamemodeActivated;

new g_fmFwSpawn;

new g_pCvarRespawnTime;
new g_pCvarSpawnProtectionTime;
new g_pCvarNewRoundDelay;

new g_iGamemode = -1;
new g_iDefaultGamemode = -1;

new Trie:g_itGamemodes;
new Array:g_irgGamemodeName;
new Array:g_irgGamemodeFlags;
new Array:g_irgGamemodeiPluginId;
new g_iGamemodesNum = 0;

new g_rgiPlayerFirstSpawnFlag = 0;
new Array:g_iTSpawnPoints;
new Array:g_iCtSpawnPoints;

static g_szEquipmentMenuTitle[32];
static g_szSpellShopMenuTitle[32];

public plugin_precache() {
    register_dictionary("hwn.txt");

    format(g_szEquipmentMenuTitle, charsmax(g_szEquipmentMenuTitle), "%L", LANG_SERVER, "HWN_EQUIPMENT_MENU_TITLE");
    format(g_szSpellShopMenuTitle, charsmax(g_szSpellShopMenuTitle), "%L", LANG_SERVER, "HWN_SPELLSHOP_MENU_TITLE");

    g_fwGamemodeActivated = CreateMultiForward("Hwn_Gamemode_Fw_Activated", ET_IGNORE, FP_CELL);

    g_fmFwSpawn = register_forward(FM_Spawn, "OnSpawn", 1);

    g_iTSpawnPoints = ArrayCreate(3);
    g_iCtSpawnPoints = ArrayCreate(3);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    if (g_iGamemode < 0 && g_iDefaultGamemode >= 0) {
        SetGamemode(g_iDefaultGamemode);
    }

    Round_HookCheckWinConditions("OnCheckWinConditions");

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "HC_Player_SpawnEquip");

    register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse");

    register_clcmd("joinclass", "Command_JoinClass");
    register_clcmd("menuselect", "Command_JoinClass");

    g_pCvarRespawnTime = register_cvar("hwn_iGamemode_respawn_time", "5.0");
    g_pCvarSpawnProtectionTime = register_cvar("hwn_iGamemode_spawn_protection_time", "3.0");
    g_pCvarNewRoundDelay = register_cvar("hwn_iGamemode_new_round_delay", "10.0");

    register_forward(FM_SetModel, "FMHook_SetModel");

    unregister_forward(FM_Spawn, g_fmFwSpawn, 1);
}

public OnSpawn(pEntity) {
    if (!pev_valid(pEntity)) {
        return;
    }

    new szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    if (equal(szClassName, "info_player_start")) {
        ArrayPushArray(g_iCtSpawnPoints, vecOrigin);
    } else if (equal(szClassName, "info_player_deathmatch")) {
        ArrayPushArray(g_iTSpawnPoints, vecOrigin);
    }
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_Gamemode_Register", "Native_Register");
    register_native("Hwn_Gamemode_Activate", "Native_Activate");
    register_native("Hwn_Gamemode_DispatchWin", "Native_DispatchWin");
    register_native("Hwn_Gamemode_GetCurrent", "Native_GetCurrent");
    register_native("Hwn_Gamemode_GetHandler", "Native_GetHandler");
    register_native("Hwn_Gamemode_IsPlayerOnSpawn", "Native_IsPlayerOnSpawn");
    register_native("Hwn_Gamemode_GetFlags", "Native_GetFlags");
}

public plugin_end() {
    if (!g_iGamemodesNum) {
        TrieDestroy(g_itGamemodes);
        ArrayDestroy(g_irgGamemodeName);
        ArrayDestroy(g_irgGamemodeFlags);
        ArrayDestroy(g_irgGamemodeiPluginId);
    }

    ArrayDestroy(g_iTSpawnPoints);
    ArrayDestroy(g_iCtSpawnPoints);
}

public client_connect(pPlayer) {
    g_rgiPlayerFirstSpawnFlag |= BIT(pPlayer & 31);
}

public client_disconnected(pPlayer) {
    remove_task(pPlayer + TASKID_SUM_RESPAWN_PLAYER);
    remove_task(pPlayer + TASKID_SUM_SPAWN_PROTECTION);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new Hwn_GamemodeFlags:iFlags = Hwn_GamemodeFlags:get_param(2);

    if (!g_iGamemodesNum) {
        g_itGamemodes = TrieCreate();
        g_irgGamemodeName = ArrayCreate(32);
        g_irgGamemodeFlags = ArrayCreate();
        g_irgGamemodeiPluginId = ArrayCreate();
    }

    new iGamemode = g_iGamemodesNum;
    TrieSetCell(g_itGamemodes, szName, iGamemode);
    ArrayPushString(g_irgGamemodeName, szName);
    ArrayPushCell(g_irgGamemodeFlags, iFlags);
    ArrayPushCell(g_irgGamemodeiPluginId, iPluginId);

    if ((iFlags & Hwn_GamemodeFlag_Default) && g_iDefaultGamemode < 0) {
        g_iDefaultGamemode = iGamemode;
    }

    g_iGamemodesNum++;

    return iGamemode;
}

public bool:Native_Activate(iPluginId, iArgc) {
    new iGamemode = GetGamemodeByiPluginId(iPluginId);
    if (iGamemode < 0) {
        return false;
    }

    SetGamemode(iGamemode);

    return true;
}

public Native_DispatchWin(iPluginId, iArgc) {
    if (!g_iGamemodesNum) {
        return;
    }

    if (iPluginId != ArrayGetCell(g_irgGamemodeiPluginId, g_iGamemode)) {
        return;
    }

    new iTeam = get_param(1);
    DispatchWin(iTeam);
}

public Native_GetCurrent(iPluginId, iArgc) {
    return g_iGamemode;
}

public Native_GetHandler(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    static iGamemode;
    if (!TrieGetCell(g_itGamemodes, szName, iGamemode)) {
        return -1;
    }

    return iGamemode;
}

public Native_IsPlayerOnSpawn(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new bool:bIgnoreTeam = bool:get_param(2);

    return IsPlayerOnSpawn(pPlayer, bIgnoreTeam);
}

public Hwn_GamemodeFlags:Native_GetFlags(iPluginId, iArgc) {
    if (!g_iGamemodesNum) {
        return Hwn_GamemodeFlag_None;
    }

    return ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Hwn_PEquipment_Event_Changed(pPlayer) {
    if (!g_iGamemodesNum) {
        return;
    }

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (~iFlags & Hwn_GamemodeFlag_SpecialEquip) {
        return;
    }

    if (IsPlayerOnSpawn(pPlayer)) {
        Hwn_PEquipment_Equip(pPlayer);
    }
}

public Command_JoinClass(pPlayer) {
    if (!g_iGamemodesNum) {
        return PLUGIN_CONTINUE;
    }

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (~iFlags & Hwn_GamemodeFlag_RespawnPlayers) {
        return PLUGIN_CONTINUE;
    }

    new iMenu = get_member(pPlayer, m_iMenu);
    new iJoinState = get_member(pPlayer, m_iJoiningState);

    if (iMenu != MENU_CHOOSEAPPEARANCE) {
        return PLUGIN_CONTINUE;
    }

    new iTeam = get_member(pPlayer, m_iTeam);
    new bool:inPlayableTeam = iTeam == 1 || iTeam == 2;

    if (iJoinState != JOIN_CHOOSEAPPEARANCE && (iJoinState || !inPlayableTeam)) {
        return PLUGIN_CONTINUE;
    }

    //ConnorMcLeod
    new szCommand[11], szArg1[32];
    read_argv(0, szCommand, charsmax(szCommand));
    read_argv(1, szArg1, charsmax(szArg1));
    engclient_cmd(pPlayer, szCommand, szArg1);

    ExecuteHam(Ham_Player_PreThink, pPlayer);

    if (!is_user_alive(pPlayer)) {
        SetRespawnTask(pPlayer);
    }

    return PLUGIN_HANDLED;
}

public Message_ClCorpse() {
    if (!g_iGamemodesNum) {
        return PLUGIN_CONTINUE;
    }

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (iFlags & Hwn_GamemodeFlag_RespawnPlayers) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    if (!g_iGamemodesNum) {
        return;
    }

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);

    if ((iFlags & Hwn_GamemodeFlag_SpecialEquip)) {
        if (g_rgiPlayerFirstSpawnFlag & BIT(pPlayer & 31)) {
            Hwn_PEquipment_ShowMenu(pPlayer);
            g_rgiPlayerFirstSpawnFlag &= ~BIT(pPlayer & 31);
        }
    }

    if (iFlags & Hwn_GamemodeFlag_RespawnPlayers) {
        set_pev(pPlayer, pev_takedamage, DAMAGE_NO);
        remove_task(pPlayer + TASKID_SUM_SPAWN_PROTECTION);
        set_task(get_pcvar_float(g_pCvarSpawnProtectionTime), "Task_DisableSpawnProtection", pPlayer + TASKID_SUM_SPAWN_PROTECTION);
        UTIL_SetPlayerTeamChange(pPlayer, true);
    }
}

public HamHook_Player_Killed(pPlayer, pKiller) {
    new pOwner = pev(pKiller, pev_owner);
    if (IS_PLAYER(pOwner) && is_user_alive(pOwner)) {
        SetHamParamEntity2(2, pOwner);
    }

    return HAM_HANDLED;
}

public HamHook_Player_Killed_Post(pPlayer) {
    if (!g_iGamemodesNum) {
        return;
    }

    if (g_iGamemode < 0) {
        return;
    }

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if ((iFlags & Hwn_GamemodeFlag_RespawnPlayers) && !Round_IsRoundEnd()) {
        SetRespawnTask(pPlayer);
    }
}

public HC_Player_SpawnEquip(pPlayer) {
    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if ((iFlags & Hwn_GamemodeFlag_SpecialEquip)) {
        Hwn_PEquipment_Equip(pPlayer);
        return HC_SUPERCEDE;
    }


    return HC_CONTINUE;
}

public FMHook_SetModel(pEntity) {
    if (!g_iGamemodesNum) {
        return;
    }

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (~iFlags & Hwn_GamemodeFlag_SpecialEquip) {
        return;
    }

    static szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    if (equal(szClassName, "weaponbox")) {
        dllfunc(DLLFunc_Think, pEntity);
    }
}

public MenuItem_ChangeEquipment(pPlayer) {
    Hwn_PEquipment_ShowMenu(pPlayer);
}

public MenuItem_SpellShop(pPlayer) {
    Hwn_SpellShop_Open(pPlayer);
}

public OnCheckWinConditions() {
    if (!g_iGamemodesNum) {
        return PLUGIN_CONTINUE;
    }

    if (g_iGamemode < 0) {
        return PLUGIN_CONTINUE;
    }

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if ((iFlags & Hwn_GamemodeFlag_RespawnPlayers) && IsTeamExtermination()) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public Hwn_SpellShop_Fw_Open(pPlayer) {
    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (~iFlags & Hwn_GamemodeFlag_SpellShop) {
        return PLUGIN_HANDLED;
    }

    if (!IsPlayerOnSpawn(pPlayer)) {
        client_print(pPlayer, print_center, "%L", pPlayer, "HWN_SPELLSHOP_NOT_AT_SPAWN");
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public Hwn_SpellShop_Fw_BuySpell(pPlayer, iSpell) {
    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (~iFlags & Hwn_GamemodeFlag_SpellShop) {
        return PLUGIN_HANDLED;
    }

    if (!IsPlayerOnSpawn(pPlayer)) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

/*--------------------------------[ Methods ]--------------------------------*/

SetGamemode(iGamemode) {
    g_iGamemode = iGamemode;
    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (iFlags & Hwn_GamemodeFlag_SpecialEquip) {
        Hwn_Menu_AddItem(g_szEquipmentMenuTitle, "MenuItem_ChangeEquipment");
    }

    if (iFlags & Hwn_GamemodeFlag_SpellShop) {
        Hwn_Menu_AddItem(g_szSpellShopMenuTitle, "MenuItem_SpellShop");
    }

    new szGamemodeName[32];
    ArrayGetString(g_irgGamemodeName, iGamemode, szGamemodeName, charsmax(szGamemodeName));
    log_amx("[Hwn] Gamemode '%s' activated", szGamemodeName);

    ExecuteForward(g_fwGamemodeActivated, _, iGamemode);
}

GetGamemodeByiPluginId(iPluginId) {
    for (new iGamemode = 0; iGamemode < g_iGamemodesNum; ++iGamemode) {
        new iGamemodeiPluginId = ArrayGetCell(g_irgGamemodeiPluginId, iGamemode);

        if (iPluginId == iGamemodeiPluginId) {
            return iGamemode;
        }
    }

    return -1;
}

RespawnPlayer(pPlayer) {
    if (!is_user_connected(pPlayer)) {
        return;
    }

    if (is_user_alive(pPlayer)) {
        return;
    }

    new iTeam = get_member(pPlayer, m_iTeam);

    if (iTeam != 1 && iTeam != 2) {
        return;
    }

    ExecuteHamB(Ham_CS_RoundRespawn, pPlayer);
}

bool:IsPlayerOnSpawn(pPlayer, bool:bIgnoreTeam = false) {
    new iTeam = get_member(pPlayer, m_iTeam);
    if (iTeam < 1 || iTeam > 2) {
        return false;
    }

    return bIgnoreTeam
        ? IsPlayerOnTeamSpawn(pPlayer, 1) || IsPlayerOnTeamSpawn(pPlayer, 2)
        : IsPlayerOnTeamSpawn(pPlayer, iTeam);
}

bool:IsPlayerOnTeamSpawn(pPlayer, iTeam) {
    new Array:spawnPoints = iTeam == 1 ? g_iTSpawnPoints : g_iCtSpawnPoints;
    new iSpawnPointsNum = ArraySize(spawnPoints);

    static Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    static Float:vecSpawnOrigin[3];
    for (new i = 0; i < iSpawnPointsNum; ++i) {
        ArrayGetArray(spawnPoints, i, vecSpawnOrigin);
        if (get_distance_f(vecOrigin, vecSpawnOrigin) <= SPAWN_RANGE) {
            return true;
        }
    }

    return false;
}

DispatchWin(iTeam) {
    new Float:flDelay = get_pcvar_float(g_pCvarNewRoundDelay);
    Round_DispatchWin(iTeam, flDelay);
}

bool:IsTeamExtermination() {
    new bool:bAliveT = false;
    new bool:bAliveCT = false;

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (is_user_connected(pPlayer) && is_user_alive(pPlayer)) {
            new iTeam = get_member(pPlayer, m_iTeam);

            if (iTeam == 1) {
                bAliveT = true;

                if (bAliveCT) {
                    return false;
                }
            } else if (iTeam == 2) {
                bAliveCT = true;

                if (bAliveT) {
                    return false;
                }
            }
        }
    }

    return true;
}

SetRespawnTask(pPlayer) {
    set_task(get_pcvar_float(g_pCvarRespawnTime), "Task_RespawnPlayer", pPlayer + TASKID_SUM_RESPAWN_PLAYER);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_RespawnPlayer(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_RESPAWN_PLAYER;

    RespawnPlayer(pPlayer);
}

public Task_DisableSpawnProtection(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_SPAWN_PROTECTION;

    set_pev(pPlayer, pev_takedamage, DAMAGE_AIM);
}
