#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>
#include <api_player_cosmetic>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Gifts"
#define AUTHOR "Hedgehog Fog"

#define GIFT_ENTITY_CLASSNAME "hwn_item_gift"

#define TASKID_SUM_SPAWN_GIFT 1000

new Array:g_irgGiftTargets;

new const g_szSndGiftSpawn[] = "hwn/items/gift/gift_spawn.wav";
new const g_szSndGiftPickup[] = "hwn/items/gift/gift_pickup.wav";

new g_pCvarGiftSpawnDelay;
new g_pCvarGiftCosmeticMinTime;
new g_pCvarGiftCosmeticMaxTime;

new g_fwGiftSpawn;
new g_fwGiftPicked;
new g_fwGiftDisappear;

public plugin_precache() {
    precache_sound(g_szSndGiftSpawn);
    precache_sound(g_szSndGiftPickup);

    CE_RegisterHook(CEFunction_Picked, GIFT_ENTITY_CLASSNAME, "OnGiftPicked");
    CE_RegisterHook(CEFunction_Killed, GIFT_ENTITY_CLASSNAME, "OnGiftKilled");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarGiftSpawnDelay = register_cvar("hwn_gifts_spawn_delay", "300.0");
    g_pCvarGiftCosmeticMinTime = register_cvar("hwn_gifts_cosmetic_min_time", "450");
    g_pCvarGiftCosmeticMaxTime = register_cvar("hwn_gifts_cosmetic_max_time", "1200");

    g_fwGiftSpawn = CreateMultiForward("Hwn_Gifts_Fw_GiftSpawn", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwGiftPicked = CreateMultiForward("Hwn_Gifts_Fw_GiftPicked", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwGiftDisappear = CreateMultiForward("Hwn_Gifts_Fw_GiftDisappear", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_end() {
    if (g_irgGiftTargets != Invalid_Array) {
        ArrayDestroy(g_irgGiftTargets);
    }
}

public plugin_natives() {
    register_library("hwn");
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
    SetupSpawnGiftTask(pPlayer);
}

public client_disconnected(pPlayer) {
    remove_task(pPlayer + TASKID_SUM_SPAWN_GIFT);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnGiftPicked(pEntity, pPlayer) {
    new iNum = Hwn_Cosmetic_GetCount();
    new iCosmetic = Hwn_Cosmetic_GetCosmetic(random(iNum));
    new iTime = random_num(
        get_pcvar_num(g_pCvarGiftCosmeticMinTime),
        get_pcvar_num(g_pCvarGiftCosmeticMaxTime)
    );

    new PCosmetic_Type:iType = PCosmetic_Type_Normal;
    if (random(100) >= 20 && random(100) <= 40) { //Find random number two times
        iType = PCosmetic_Type_Unusual;
    }

    PCosmetic_Give(pPlayer, iCosmetic, iType, iTime);

    client_cmd(pPlayer, "spk %s", g_szSndGiftPickup);

    ExecuteForward(g_fwGiftPicked, _, pPlayer, pEntity);
}

public OnGiftKilled(pEntity, bool:picked) {
    new pOwner = pev(pEntity, pev_owner);
    if (!pOwner) {
        return;
    }

    if (is_user_connected(pOwner)) {
        SetupSpawnGiftTask(pOwner);
    }

    if (!picked) {
        ExecuteForward(g_fwGiftDisappear, _, pOwner, pEntity);
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

    if (!pEntity) {
        return;
    }

    set_pev(pEntity, pev_owner, pPlayer);
    dllfunc(DLLFunc_Spawn, pEntity);

    client_cmd(pPlayer, "spk %s", g_szSndGiftSpawn);

    ExecuteForward(g_fwGiftSpawn, _, pPlayer, pEntity);
}

SetupSpawnGiftTask(pPlayer) {
    set_task(get_pcvar_float(g_pCvarGiftSpawnDelay), "Task_SpawnGift", pPlayer + TASKID_SUM_SPAWN_GIFT);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_SpawnGift(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_SPAWN_GIFT;

    new iTeam = get_member(pPlayer, m_iTeam);
    if (iTeam != 1 && iTeam != 2) {
        SetupSpawnGiftTask(pPlayer);
        return;
    }

    new Float:vecOrigin[3];
    if (g_irgGiftTargets != Invalid_Array && ArraySize(g_irgGiftTargets) > 0) {
        new iTargetsNum = ArraySize(g_irgGiftTargets);
        ArrayGetArray(g_irgGiftTargets, random(iTargetsNum), vecOrigin);
    } else {
        if (!Hwn_EventPoints_GetRandom(vecOrigin)) {
            SetupSpawnGiftTask(pPlayer);
            return;
        }
    }

    SpawnGift(pPlayer, vecOrigin);
}
