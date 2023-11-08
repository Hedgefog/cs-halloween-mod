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

#define SPAWN_RANGE 192.0

new g_szEquipmentMenuTitle[32];
new g_szSpellShopMenuTitle[32];

new g_pCvarRespawnTime;
new g_pCvarSpawnProtectionTime;

new g_fwGamemodeActivated;

new g_iFmFwSpawn;

new Array:g_iTeam1SpawnPoints;
new Array:g_iTeam2SpawnPoints;

new g_iGamemode = -1;
new g_iDefaultGamemode = -1;

new Trie:g_itGamemodes;
new Array:g_irgGamemodeName;
new Array:g_irgGamemodeFlags;
new Array:g_irgGamemodeiPluginId;
new g_iGamemodesNum = 0;

new g_rgiPlayerFirstSpawnFlag = 0;

public plugin_precache() {
    register_dictionary("hwn.txt");

    format(g_szEquipmentMenuTitle, charsmax(g_szEquipmentMenuTitle), "%L", LANG_SERVER, "HWN_EQUIPMENT_MENU_TITLE");
    format(g_szSpellShopMenuTitle, charsmax(g_szSpellShopMenuTitle), "%L", LANG_SERVER, "HWN_SPELLSHOP_MENU_TITLE");

    g_fwGamemodeActivated = CreateMultiForward("Hwn_Gamemode_Fw_Activated", ET_IGNORE, FP_CELL);

    g_iFmFwSpawn = register_forward(FM_Spawn, "FMHook_Spawn", 1);

    g_iTeam1SpawnPoints = ArrayCreate(3);
    g_iTeam2SpawnPoints = ArrayCreate(3);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    if (g_iGamemode < 0 && g_iDefaultGamemode >= 0) SetGamemode(g_iDefaultGamemode);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "HC_Player_SpawnEquip", .post = 0);
    RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "HC_GameRules_DeadPlayerWeapons", .post = 0);
    RegisterHookChain(RG_HandleMenu_ChooseTeam, "HC_HandleMenu_ChooseTeam_Post", .post = 1);
    RegisterHookChain(RG_CBasePlayer_GetIntoGame, "HC_Player_GetIntoGame_Post", .post = 1);

    register_message(get_user_msgid("ClCorpse"), "Message_ClCorpse");

    g_pCvarRespawnTime = register_cvar("hwn_gamemode_respawn_time", "5.0");
    g_pCvarSpawnProtectionTime = register_cvar("hwn_gamemode_spawn_protection_time", "3.0");

    unregister_forward(FM_Spawn, g_iFmFwSpawn, 1);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_Gamemode_Register", "Native_Register");
    register_native("Hwn_Gamemode_Activate", "Native_Activate");
    register_native("Hwn_Gamemode_DispatchWin", "Native_DispatchWin");
    register_native("Hwn_Gamemode_GetCurrent", "Native_GetCurrent");
    register_native("Hwn_Gamemode_GetHandler", "Native_GetHandler");
    register_native("Hwn_Gamemode_IsPlayerOnSpawn", "Native_IsPlayerOnSpawn");
    register_native("Hwn_Gamemode_GetSpawnAreaTeam", "Native_GetSpawnAreaTeam");
    register_native("Hwn_Gamemode_GetFlags", "Native_GetFlags");
}

public plugin_end() {
    if (!g_iGamemodesNum) {
        TrieDestroy(g_itGamemodes);
        ArrayDestroy(g_irgGamemodeName);
        ArrayDestroy(g_irgGamemodeFlags);
        ArrayDestroy(g_irgGamemodeiPluginId);
    }

    ArrayDestroy(g_iTeam1SpawnPoints);
    ArrayDestroy(g_iTeam2SpawnPoints);
}

public client_connect(pPlayer) {
    g_rgiPlayerFirstSpawnFlag |= BIT(pPlayer & 31);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
    new szName[32]; get_string(1, szName, charsmax(szName));

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
    new iGamemode = get_param(1);
    SetGamemode(iGamemode);

    return true;
}

public Native_DispatchWin(iPluginId, iArgc) {
    if (!g_iGamemodesNum) return;

    if (iPluginId != ArrayGetCell(g_irgGamemodeiPluginId, g_iGamemode)) return;

    new iTeam = get_param(1);
    DispatchWin(iTeam);
}

public Native_GetCurrent(iPluginId, iArgc) {
    return g_iGamemode;
}

public Native_GetHandler(iPluginId, iArgc) {
    static szName[32]; get_string(1, szName, charsmax(szName));

    static iGamemode;
    if (!TrieGetCell(g_itGamemodes, szName, iGamemode)) return -1;

    return iGamemode;
}

public Native_IsPlayerOnSpawn(iPluginId, iArgc) {
    static pPlayer; pPlayer = get_param(1);
    static bool:bIgnoreTeam; bIgnoreTeam = bool:get_param(2);

    return @Player_IsOnSpawn(pPlayer, bIgnoreTeam);
}

public Native_GetSpawnAreaTeam(iPluginId, iArgc) {
    static Float:vecOrigin[3]; get_array_f(1, vecOrigin, sizeof(vecOrigin));

    return GetSpawnAreaTeam(vecOrigin);
}

public Hwn_GamemodeFlags:Native_GetFlags(iPluginId, iArgc) {
    if (!g_iGamemodesNum) return Hwn_GamemodeFlag_None;

    return ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Round_Fw_CheckWinConditions() {
    if (!g_iGamemodesNum) return PLUGIN_CONTINUE;
    if (g_iGamemode < 0) return PLUGIN_CONTINUE;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if ((iFlags & Hwn_GamemodeFlag_RespawnPlayers) && IsTeamExtermination()) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public Hwn_SpellShop_Fw_Open(pPlayer) {
    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);

    if (~iFlags & Hwn_GamemodeFlag_SpellShop) return PLUGIN_HANDLED;

    if (!@Player_IsOnSpawn(pPlayer, false)) {
        client_print(pPlayer, print_center, "%L", pPlayer, "HWN_SPELLSHOP_NOT_AT_SPAWN");
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public Hwn_SpellShop_Fw_BuySpell(pPlayer, iSpell) {
    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    
    if (~iFlags & Hwn_GamemodeFlag_SpellShop) return PLUGIN_HANDLED;
    if (!@Player_IsOnSpawn(pPlayer, false)) return PLUGIN_HANDLED;

    return PLUGIN_CONTINUE;
}

public Hwn_PEquipment_Event_Changed(pPlayer) {
    if (!g_iGamemodesNum) return;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (~iFlags & Hwn_GamemodeFlag_SpecialEquip) return;

    if (@Player_IsOnSpawn(pPlayer, false)) Hwn_PEquipment_Equip(pPlayer);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Message_ClCorpse() {
    if (!g_iGamemodesNum) return PLUGIN_CONTINUE;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (iFlags & Hwn_GamemodeFlag_RespawnPlayers) return PLUGIN_HANDLED;

    return PLUGIN_CONTINUE;
}

public FMHook_Spawn(pEntity) {
    if (!pev_valid(pEntity)) return;

    static szClassName[32]; pev(pEntity, pev_classname, szClassName, charsmax(szClassName));
    static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);

    if (equal(szClassName, "info_player_start")) {
        ArrayPushArray(g_iTeam2SpawnPoints, vecOrigin);
    } else if (equal(szClassName, "info_player_deathmatch")) {
        ArrayPushArray(g_iTeam1SpawnPoints, vecOrigin);
    }
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) return;
    if (!g_iGamemodesNum) return;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);

    if ((iFlags & Hwn_GamemodeFlag_SpecialEquip)) {
        if (g_rgiPlayerFirstSpawnFlag & BIT(pPlayer & 31)) {
            Hwn_PEquipment_ShowMenu(pPlayer);
            g_rgiPlayerFirstSpawnFlag &= ~BIT(pPlayer & 31);
        }
    }

    if (iFlags & Hwn_GamemodeFlag_RespawnPlayers) {
        set_member(pPlayer, m_flSpawnProtectionEndTime, get_gametime() + get_pcvar_float(g_pCvarSpawnProtectionTime));
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
    if (!g_iGamemodesNum) return;
    if (g_iGamemode < 0) return;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if ((iFlags & Hwn_GamemodeFlag_RespawnPlayers) && !Round_IsRoundEnd()) {
        SetRespawnTask(pPlayer);
    }
}

public HC_Player_SpawnEquip(pPlayer) {
    if (!g_iGamemodesNum) return HC_CONTINUE;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if ((iFlags & Hwn_GamemodeFlag_SpecialEquip)) {
        Hwn_PEquipment_Equip(pPlayer);
        return HC_SUPERCEDE;
    }

    return HC_CONTINUE;
}

public HC_GameRules_DeadPlayerWeapons(pPlayer) {
    if (!g_iGamemodesNum) return HC_CONTINUE;
    
    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (iFlags & Hwn_GamemodeFlag_SpecialEquip) {
        SetHookChainReturn(ATYPE_INTEGER, GR_PLR_DROP_GUN_NO);
        return HC_SUPERCEDE;
    }

    return HC_CONTINUE;
}

public HC_HandleMenu_ChooseTeam_Post(pPlayer) {
    if (!g_iGamemodesNum) return HC_CONTINUE;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (iFlags & Hwn_GamemodeFlag_RespawnPlayers) {
        set_member(pPlayer, m_bTeamChanged, false);
    }

    return HC_CONTINUE;
}

public HC_Player_GetIntoGame_Post(pPlayer) {
    if (!g_iGamemodesNum) return HC_CONTINUE;

    new Hwn_GamemodeFlags:iFlags = ArrayGetCell(g_irgGamemodeFlags, g_iGamemode);
    if (iFlags & Hwn_GamemodeFlag_RespawnPlayers) {
        SetRespawnTask(pPlayer);
    }

    return HC_CONTINUE;
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:@Player_IsOnSpawn(this, bool:bIgnoreTeam) {
    new iTeam = 0;

    if (!bIgnoreTeam) {
        iTeam = get_member(this, m_iTeam);
        if (iTeam < 1 || iTeam > 2) return false;
    }

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    return IsTeamSpawn(vecOrigin, iTeam);
}

/*--------------------------------[ Functions ]--------------------------------*/

SetGamemode(iGamemode) {
    if (g_iGamemode == iGamemode) return;

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

GetSpawnAreaTeam(const Float:vecOrigin[3]) {
    for (new iTeam = 1; iTeam <= 2; ++iTeam) {
        if (IsTeamSpawn(vecOrigin, iTeam)) {
            return iTeam;
        }
    }

    return 0;
}

bool:IsTeamSpawn(const Float:vecOrigin[3], iTeam) {
    if (!iTeam) {
        return IsTeamSpawn(vecOrigin, 1) || IsTeamSpawn(vecOrigin, 2);
    }

    new Array:spawnPoints = iTeam == 1 ? g_iTeam1SpawnPoints : g_iTeam2SpawnPoints;
    new iSpawnPointsNum = ArraySize(spawnPoints);

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
    Round_DispatchWin(iTeam);
}

bool:IsTeamExtermination() {
    static iAliveT; iAliveT = 0;
    static iAliveCT; iAliveCT = 0;
    rg_initialize_player_counts(iAliveT, iAliveCT);

    return !iAliveT || !iAliveCT; 
}

SetRespawnTask(pPlayer) {
    set_member(pPlayer, m_flRespawnPending, get_gametime() + get_pcvar_float(g_pCvarRespawnTime));
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuItem_ChangeEquipment(pPlayer) {
    Hwn_PEquipment_ShowMenu(pPlayer);
}

public MenuItem_SpellShop(pPlayer) {
    Hwn_SpellShop_Open(pPlayer);
}
