#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>
#include <hwn_player_cosmetics>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Gifts"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define GIFT_ENTITY_CLASSNAME "hwn_item_gift"

new Array:g_irgGiftTargets;

new const g_szSndGiftSpawn[] = "hwn/items/gift/gift_spawn.wav";
new const g_szSndGiftPickup[] = "hwn/items/gift/gift_pickup.wav";

new g_pCvarGiftSpawnDelay;
new g_pCvarGiftCosmeticMinTime;
new g_pCvarGiftCosmeticMaxTime;

new g_fwGiftSpawn;
new g_fwGiftPicked;
new g_fwGiftDisappear;

new Float:g_rgflPlayerNextGiftSpawn[MAX_PLAYERS + 1];

public plugin_precache() {
    precache_sound(g_szSndGiftSpawn);
    precache_sound(g_szSndGiftPickup);

    CE_RegisterHook(GIFT_ENTITY_CLASSNAME, CEFunction_Picked, "@Gift_Picked");
    CE_RegisterHook(GIFT_ENTITY_CLASSNAME, CEFunction_Killed, "@Gift_Killed");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_pCvarGiftSpawnDelay = register_cvar("hwn_gifts_spawn_delay", "300.0");
    g_pCvarGiftCosmeticMinTime = register_cvar("hwn_gifts_cosmetic_min_time", "450");
    g_pCvarGiftCosmeticMaxTime = register_cvar("hwn_gifts_cosmetic_max_time", "1200");

    g_fwGiftSpawn = CreateMultiForward("Hwn_Gifts_Fw_GiftSpawn", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwGiftPicked = CreateMultiForward("Hwn_Gifts_Fw_GiftPicked", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwGiftDisappear = CreateMultiForward("Hwn_Gifts_Fw_GiftDisappear", ET_IGNORE, FP_CELL, FP_CELL);

    set_task(1.0, "Task_GiftSpawnThink", _, _, _, "b");
}

public plugin_end() {
    if (g_irgGiftTargets != Invalid_Array) {
        ArrayDestroy(g_irgGiftTargets);
    }
}

public plugin_natives() {
    register_library("hwn_gifts");
    register_native("Hwn_Gifts_AddTarget", "Native_AddTarget");
    register_native("Hwn_Gifts_GetTargetCount", "Native_GetTargetCount");
    register_native("Hwn_Gifts_GetTarget", "Native_GetTarget");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_AddTarget(iPluginId, iArgc) {
    new Float:vecOrigin[3];
    get_array_f(1, vecOrigin, sizeof(vecOrigin));

    return AddGiftTarget(vecOrigin);
}

public Native_GetTargetCount(iPluginId, iArgc) {
    return g_irgGiftTargets == Invalid_Array ? 0 : ArraySize(g_irgGiftTargets);
}

public Native_GetTarget(iPluginId, iArgc) {
    new iTarget = get_param(1);

    new Float:vecOrigin[3];
    ArrayGetArray(g_irgGiftTargets, iTarget, vecOrigin);

    set_array_f(2, vecOrigin, sizeof(vecOrigin));
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver(pPlayer) {
    ScheduleGiftSpawn(pPlayer);
}

public Hwn_Bosses_Fw_Winner(pPlayer) {
    new iNum = Hwn_PlayerCosmetic_GetCount();
    new iTime = get_pcvar_num(g_pCvarGiftCosmeticMaxTime);

    static szCosmetic[32];
    Hwn_PlayerCosmetic_GetIdByIndex(random(iNum), szCosmetic, charsmax(szCosmetic));

    Hwn_Player_GiveCosmetic(pPlayer, szCosmetic, Hwn_PlayerCosmetic_Type_Unusual, float(iTime));
}

/*--------------------------------[ Methods ]--------------------------------*/

@Gift_Picked(this, pPlayer) {
    new iNum = Hwn_PlayerCosmetic_GetCount();

    new iTime = random_num(
        get_pcvar_num(g_pCvarGiftCosmeticMinTime),
        get_pcvar_num(g_pCvarGiftCosmeticMaxTime)
    );

    new Hwn_PlayerCosmetic_Type:iType = Hwn_PlayerCosmetic_Type_Normal;
    if (random(100) >= 20 && random(100) <= 40) { //Find random number two times
        iType = Hwn_PlayerCosmetic_Type_Unusual;
    }

    static szCosmetic[32];
    Hwn_PlayerCosmetic_GetIdByIndex(random(iNum), szCosmetic, charsmax(szCosmetic));

    Hwn_Player_GiveCosmetic(pPlayer, szCosmetic, iType, float(iTime));

    client_cmd(pPlayer, "spk %s", g_szSndGiftPickup);

    ExecuteForward(g_fwGiftPicked, _, pPlayer, this);
}

@Gift_Killed(this, bool:bPicked) {
    new pOwner = pev(this, pev_owner);
    if (!pOwner) return;

    if (is_user_connected(pOwner)) {
        ScheduleGiftSpawn(pOwner);
    }

    if (!bPicked) {
        ExecuteForward(g_fwGiftDisappear, _, pOwner, this);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

AddGiftTarget(const Float:vecOrigin[3]) {
    if (g_irgGiftTargets == Invalid_Array) {
        g_irgGiftTargets = ArrayCreate(3);
    }

    return ArrayPushArray(g_irgGiftTargets, vecOrigin);
}

SpawnGift(pPlayer, const Float:vecOrigin[3]) {
    new pEntity = CE_Create(GIFT_ENTITY_CLASSNAME, vecOrigin);

    if (!pEntity) return;

    set_pev(pEntity, pev_owner, pPlayer);
    dllfunc(DLLFunc_Spawn, pEntity);

    client_cmd(pPlayer, "spk %s", g_szSndGiftSpawn);

    ExecuteForward(g_fwGiftSpawn, _, pPlayer, pEntity);
}

ScheduleGiftSpawn(pPlayer) {
    g_rgflPlayerNextGiftSpawn[pPlayer] = get_gametime() + get_pcvar_float(g_pCvarGiftSpawnDelay);
}

PlayerGiftSpawnCheck(pPlayer) {
    new iTeam = get_ent_data(pPlayer, "CBasePlayer", "m_iTeam");
    if (iTeam != 1 && iTeam != 2) return;

    new Float:vecOrigin[3];

    if (g_irgGiftTargets != Invalid_Array && ArraySize(g_irgGiftTargets) > 0) {
        new iTargetsNum = ArraySize(g_irgGiftTargets);
        ArrayGetArray(g_irgGiftTargets, random(iTargetsNum), vecOrigin);
    } else {
        if (!Hwn_EventPoints_GetRandom(vecOrigin)) return;
    }

    SpawnGift(pPlayer, vecOrigin);
    g_rgflPlayerNextGiftSpawn[pPlayer] = 0.0;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_GiftSpawnThink() {
    new Float:flGameTime = get_gametime();

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_connected(pPlayer)) continue;
        if (!g_rgflPlayerNextGiftSpawn[pPlayer]) continue;
        if (g_rgflPlayerNextGiftSpawn[pPlayer] > flGameTime) continue;

        PlayerGiftSpawnCheck(pPlayer);
    }
}
