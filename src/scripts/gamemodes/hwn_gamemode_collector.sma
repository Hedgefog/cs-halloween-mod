#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#include <api_rounds>
#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Gamemode Collector"
#define AUTHOR "Hedgehog Fog"

#define GAMEMODE_NAME "Collector"
#define GAMEMODE_FLAGS (Hwn_GamemodeFlag_RespawnPlayers | Hwn_GamemodeFlag_SpecialEquip | Hwn_GamemodeFlag_SpellShop)

#define BIT(%0) (1<<(%0))

#define BUCKET_ENTITY_CLASSNAME "hwn_bucket"
#define LOOT_ENTITY_CLASSNAME "hwn_item_pumpkin"
#define SPELLBOOK_ENTITY_CLASSNAME "hwn_item_spellbook"
#define BACKPACK_ENTITY_CLASSNAME "hwn_item_pumpkin_big"

#define TEAM_COUNT 4

new const g_szSndPointCollected[] = "hwn/misc/collected.wav";

new g_pCvarTeamPointsLimit;
new g_pCvarRoundTime;
new g_pCvarRoundTimeOvertime;
new g_pCvarNpcDropChanceSpell;
new g_pCvarTeamPointsToBossSpawn;
new g_pCvarTeamPointsReward;
new g_pCvarMaxMoney;

new g_fwPlayerPointsChanged;
new g_fwTeamPointsChanged;
new g_fwTeamPointsScored;
new g_fwOvertime;
new g_fwWinnerTeam;
new g_fwObjectiveBlocked;

new Array:g_irgpBuckets;
new g_rgiPlayerPoints[MAX_PLAYERS + 1];
new g_rgiTeamPoints[TEAM_COUNT];
new g_iTeamPointsToSpawnBoss;
new bool:g_bOvertime;

new g_iGamemode;

public plugin_precache() {
    precache_sound(g_szSndPointCollected);

    CE_RegisterHook(BUCKET_ENTITY_CLASSNAME, CEFunction_Init, "@Bucket_Init");
    CE_RegisterHook(BUCKET_ENTITY_CLASSNAME, CEFunction_Remove, "@Bucket_Remove");
    CE_RegisterHook(LOOT_ENTITY_CLASSNAME, CEFunction_Picked, "@Loot_Pickup");
    CE_RegisterHook(BACKPACK_ENTITY_CLASSNAME, CEFunction_Picked, "@Backpack_Pickup");

    g_iGamemode = Hwn_Gamemode_Register(GAMEMODE_NAME, GAMEMODE_FLAGS);

    g_irgpBuckets = ArrayCreate(1, 2);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

    RegisterHam(Ham_Killed, CE_BASE_CLASSNAME, "HamHook_Base_Killed_Post", .Post = 1);

    g_pCvarTeamPointsLimit = register_cvar("hwn_collector_teampoints_limit", "50");
    g_pCvarRoundTime = register_cvar("hwn_collector_roundtime", "10.0");
    g_pCvarRoundTimeOvertime = register_cvar("hwn_collector_roundtime_overtime", "30");
    g_pCvarNpcDropChanceSpell = register_cvar("hwn_collector_npc_drop_chance_spell", "7.5");
    g_pCvarTeamPointsToBossSpawn = register_cvar("hwn_collector_teampoints_to_boss_spawn", "20");
    g_pCvarTeamPointsReward = register_cvar("hwn_collector_teampoints_reward", "150");
    g_pCvarMaxMoney = get_cvar_pointer("mp_maxmoney");

    g_fwPlayerPointsChanged = CreateMultiForward("Hwn_Collector_Fw_PlayerPoints", ET_IGNORE, FP_CELL);
    g_fwTeamPointsChanged = CreateMultiForward("Hwn_Collector_Fw_TeamPoints", ET_IGNORE, FP_CELL);
    g_fwTeamPointsScored = CreateMultiForward("Hwn_Collector_Fw_TeamPointsScored", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
    g_fwOvertime = CreateMultiForward("Hwn_Collector_Fw_Overtime", ET_IGNORE, FP_CELL);
    g_fwWinnerTeam = CreateMultiForward("Hwn_Collector_Fw_WinnerTeam", ET_IGNORE, FP_CELL);
    g_fwObjectiveBlocked = CreateMultiForward("Hwn_Collector_Fw_ObjectiveBlocked", ET_IGNORE, FP_CELL);
}

public plugin_end() {
    ArrayDestroy(g_irgpBuckets);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_Collector_GetPlayerPoints", "Native_GetPlayerPoints");
    register_native("Hwn_Collector_SetPlayerPoints", "Native_SetPlayerPoints");
    register_native("Hwn_Collector_GetTeamPoints", "Native_GetTeamPoints");
    register_native("Hwn_Collector_SetTeamPoints", "Native_SetTeamPoints");
    register_native("Hwn_Collector_IsOvertime", "Native_IsOvertime");
    register_native("Hwn_Collector_ObjectiveBlocked", "Native_ObjectiveBlocked");
    register_native("Hwn_Collector_ScorePlayerPointsToTeam", "Native_ScorePlayerPointsToTeam");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_GetPlayerPoints(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    return GetPlayerPoints(pPlayer);
}

public Native_SetPlayerPoints(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);

    SetPlayerPoints(pPlayer, iAmount);
}

public Native_GetTeamPoints(iPluginId, iArgc) {
    new iTeam = get_param(1);

    return GetTeamPoints(iTeam);
}

public Native_SetTeamPoints(iPluginId, iArgc) {
    new iTeam = get_param(1);
    new iAmount = get_param(2);

    SetTeamPoints(iTeam, iAmount);
}

public bool:Native_IsOvertime(iPluginId, iArgc) {
    return g_bOvertime;
}

public bool:Native_ObjectiveBlocked(iPluginId, iArgc) {
    return IsObjectiveBlocked();
}

public bool:Native_ScorePlayerPointsToTeam(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);

    return ScorePlayerPointsToTeam(pPlayer, iAmount);
}

/*--------------------------------[ Methods ]--------------------------------*/

public @Bucket_Init(this) {
    Hwn_Gamemode_Activate(g_iGamemode);

    ArrayPushCell(g_irgpBuckets, this);
}

public @Bucket_Remove(this) {
    Hwn_Gamemode_Activate(g_iGamemode);

    new iGlobalId = ArrayFindValue(g_irgpBuckets, this);
    if (iGlobalId != -1) {
        ArrayDeleteItem(g_irgpBuckets, iGlobalId);
    }
}

public @Loot_Pickup(this, pPlayer) {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    new iPoints = GetPlayerPoints(pPlayer) + 1;
    SetPlayerPoints(pPlayer, iPoints);
}

public @Backpack_Pickup(this, pPlayer) {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    new iPoints = GetPlayerPoints(pPlayer) + CE_GetMember(this, "iSize");
    SetPlayerPoints(pPlayer, iPoints);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed_Post(pPlayer, pKiller) {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    new iPoints = GetPlayerPoints(pPlayer);
    if (iPoints || (pKiller != pPlayer && !Hwn_Gamemode_IsPlayerOnSpawn(pPlayer))) {
        ExtractPlayerPoints(pPlayer);
    }
}

public HamHook_Base_Killed_Post(pEntity) {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    static pBoss; Hwn_Bosses_GetCurrent(pBoss);

    if (pEntity != pBoss && UTIL_IsMonster(pEntity) && !pev(pEntity, pev_team)) { // Monster kill reward
        static Float:vecOrigin[3]; pev(pEntity, pev_origin, vecOrigin);
        new Float:flSpellChance = get_pcvar_float(g_pCvarNpcDropChanceSpell);
        new bool:bSpawnSpell = flSpellChance && flSpellChance >= random_float(0.0, 100.0);

        new pEntity = CE_Create(
            bSpawnSpell ? SPELLBOOK_ENTITY_CLASSNAME : LOOT_ENTITY_CLASSNAME,
            vecOrigin
        );

        if (pEntity) dllfunc(DLLFunc_Spawn, pEntity);
    }
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Gamemode_Fw_Activated() {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    set_member_game(m_bCTCantBuy, 1);
    set_member_game(m_bTCantBuy, 1);
}

public Round_Fw_NewRound() {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    ResetVariables();

    g_bOvertime = false;
}

public Round_Fw_RoundStart() {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;
    
    new iRoundTime = floatround(get_pcvar_float(g_pCvarRoundTime) * 60);
    Round_SetTime(iRoundTime);
}

public Round_Fw_RoundExpired() {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    if (get_pcvar_float(g_pCvarRoundTime) <= 0.0) return;

    new iTeam1Points = GetTeamPoints(1);
    new iTeam2Points = GetTeamPoints(2);

    if (iTeam1Points == iTeam2Points) {
        new iOvertime = get_pcvar_num(g_pCvarRoundTimeOvertime);
        if (iTeam1Points > 0 && iOvertime > 0) {
            new iRoundTime = Round_GetTime() + iOvertime;
            Round_SetTime(iRoundTime);

            g_bOvertime = true;

            ExecuteForward(g_fwOvertime, _, iOvertime);
        } else {
            DispatchWin(3);
        }
    } else {
        DispatchWin(iTeam1Points > iTeam2Points ? 1 : 2);
    }
}

public Hwn_Bosses_Fw_BossSpawn(pEntity, Float:flLifeTime) {
    if (!Round_IsRoundStarted()) return;

    new iRoundTime = Round_GetTime() + floatround(flLifeTime);
    Round_SetTime(iRoundTime);

    g_iTeamPointsToSpawnBoss = 0;
}

/*--------------------------------[ Functions ]--------------------------------*/

GetPlayerPoints(pPlayer) {
    return g_rgiPlayerPoints[pPlayer];
}

SetPlayerPoints(pPlayer, iAmount) {
    g_rgiPlayerPoints[pPlayer] = iAmount;
    ExecuteForward(g_fwPlayerPointsChanged, _, pPlayer);
}

bool:ExtractPlayerPoints(pPlayer) {
    static iPoints; iPoints = GetPlayerPoints(pPlayer);
    static bool:bIsBackpack; bIsBackpack = iPoints > 1;
    static Float:vecOrigin[3]; pev(pPlayer, pev_origin, vecOrigin);

    new pBackpack = CE_Create(bIsBackpack ? BACKPACK_ENTITY_CLASSNAME : LOOT_ENTITY_CLASSNAME, vecOrigin);
    if (!pBackpack) return false;

    if (bIsBackpack) CE_SetMember(pBackpack, "iSize", iPoints);

    CE_SetMember(pBackpack, "iType", Hwn_PumpkinType_Default);
    dllfunc(DLLFunc_Spawn, pBackpack);

    static Float:vecVelocity[3];
    UTIL_RandomVector(256.0, 256.0, vecVelocity);
    set_pev(pBackpack, pev_velocity, vecVelocity);

    SetPlayerPoints(pPlayer, 0);

    return true;
}

GetTeamPoints(iTeam) {
    return g_rgiTeamPoints[iTeam];
}

SetTeamPoints(iTeam, iAmount) {
    new iTeamPointsToBossSpawn = get_pcvar_num(g_pCvarTeamPointsToBossSpawn);
    if (iTeamPointsToBossSpawn > 0) {
        new iDiff = iAmount - g_rgiTeamPoints[iTeam];
        if (iDiff > 0) {
            g_iTeamPointsToSpawnBoss += iDiff;

            if (g_iTeamPointsToSpawnBoss >= iTeamPointsToBossSpawn) {
                g_iTeamPointsToSpawnBoss = 0;
                Hwn_Bosses_Spawn();
            }
        }
    }

    g_rgiTeamPoints[iTeam] = iAmount;

    new iTeamPointsLimit = get_pcvar_num(g_pCvarTeamPointsLimit);
    if (iAmount >= iTeamPointsLimit) DispatchWin(iTeam);

    ExecuteForward(g_fwTeamPointsChanged, _, iTeam);
}

bool:ScorePlayerPointsToTeam(pPlayer, iAmount) {
    new iPlayerPoints = GetPlayerPoints(pPlayer);
    if (iPlayerPoints < iAmount) return false;

    if (IsObjectiveBlocked()) {
        ExecuteForward(g_fwObjectiveBlocked, _, pPlayer);
        return false;
    }

    new iTeam = get_ent_data(pPlayer, "CBasePlayer", "m_iTeam");
    new iTeamPoints = GetTeamPoints(iTeam);

    SetPlayerPoints(pPlayer, iPlayerPoints - iAmount);
    SetTeamPoints(iTeam, iTeamPoints + iAmount);
    ExecuteHamB(Ham_AddPoints, pPlayer, 1, false);

    new iReward = get_pcvar_num(g_pCvarTeamPointsReward);
    new iMaxMoney = get_pcvar_num(g_pCvarMaxMoney);
    new iMoney = cs_get_user_money(pPlayer);

    cs_set_user_money(pPlayer, clamp(iMoney + iReward, 0, iMaxMoney));

    client_cmd(pPlayer, "spk %s", g_szSndPointCollected);
    ExecuteForward(g_fwTeamPointsScored, _, iTeam, iAmount, pPlayer);

    return true;
}

bool:IsObjectiveBlocked() {
    if (!Round_IsRoundStarted()) return true;
    if (Round_IsRoundEnd()) return true;
    if (Hwn_Bosses_GetCurrent() != -1) return true;

    return false;
}

ResetVariables() {
    for (new iTeam = 0; iTeam < TEAM_COUNT; ++iTeam) {
        g_rgiTeamPoints[iTeam] = 0;
    }

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        g_rgiPlayerPoints[pPlayer] = 0;
        Hwn_Spell_SetPlayerSpell(pPlayer, -1, 0);
    }

    g_iTeamPointsToSpawnBoss = 0;
}

DispatchWin(iTeam) {
    ReleaseTeamBucketsBoiling(iTeam);
    Hwn_Gamemode_DispatchWin(iTeam);
    ExecuteForward(g_fwWinnerTeam, _, iTeam);
}

ReleaseTeamBucketsBoiling(iTeam) {
    new iBucketsNum = ArraySize(g_irgpBuckets);

    for (new iBucket = 0; iBucket < iBucketsNum; ++iBucket) {
        static pBucket; pBucket = ArrayGetCell(g_irgpBuckets, iBucket);
        static iBucketTeam; iBucketTeam = pev(pBucket, pev_team);

        if (iBucketTeam && iBucketTeam != iTeam) continue;

        CE_SetMember(pBucket, "flReleaseBoiling", get_gametime() + 0.1);
    }
}
