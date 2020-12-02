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

new Array:g_giftTargets;

new const g_szSndGiftSpawn[] = "hwn/items/gift/gift_spawn.wav";
new const g_szSndGiftPickup[] = "hwn/items/gift/gift_pickup.wav";

new g_cvarGiftSpawnDelay;
new g_cvarGiftCosmeticMinTime;
new g_cvarGiftCosmeticMaxTime;

new g_fwResult;
new g_fwGiftSpawn;
new g_fwGiftPicked;
new g_fwGiftDisappear;

public plugin_precache()
{
    precache_sound(g_szSndGiftSpawn);
    precache_sound(g_szSndGiftPickup);

    CE_RegisterHook(CEFunction_Picked, GIFT_ENTITY_CLASSNAME, "OnGiftPicked");
    CE_RegisterHook(CEFunction_Killed, GIFT_ENTITY_CLASSNAME, "OnGiftKilled");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_cvarGiftSpawnDelay = register_cvar("hwn_gifts_spawn_delay", "300.0");
    g_cvarGiftCosmeticMinTime = register_cvar("hwn_gifts_cosmetic_min_time", "450");
    g_cvarGiftCosmeticMaxTime = register_cvar("hwn_gifts_cosmetic_max_time", "1200");

    g_fwGiftSpawn = CreateMultiForward("Hwn_Gifts_Fw_GiftSpawn", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwGiftPicked = CreateMultiForward("Hwn_Gifts_Fw_GiftPicked", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwGiftDisappear = CreateMultiForward("Hwn_Gifts_Fw_GiftDisappear", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_end()
{
    if (g_giftTargets != Invalid_Array) {
        ArrayDestroy(g_giftTargets);
    }
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Gifts_AddTarget", "Native_AddTarget");
    register_native("Hwn_Gifts_GetTargetCount", "Native_GetTargetCount");
    register_native("Hwn_Gifts_GetTarget", "Native_GetTarget");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_AddTarget(pluginID, argc)
{
    new Float:vOrigin[3];
    get_array_f(1, vOrigin, sizeof(vOrigin));

    AddGiftTarget(vOrigin);
}

public Native_GetTargetCount(pluginID, argc)
{
    return g_giftTargets == Invalid_Array ? 0 : ArraySize(g_giftTargets);
}

public Native_GetTarget(pluginID, argc)
{
    new targetIdx = get_param(1);

    new Float:vOrigin[3];
    ArrayGetArray(g_giftTargets, targetIdx, vOrigin);

    set_array_f(2, vOrigin, sizeof(vOrigin));
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver(id)
{
    SetupSpawnGiftTask(id);
}

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    remove_task(id + TASKID_SUM_SPAWN_GIFT);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnGiftPicked(ent, id)
{
    new count = Hwn_Cosmetic_GetCount();
    new cosmetic = Hwn_Cosmetic_GetCosmetic(random(count));
    new time = random_num(
        get_pcvar_num(g_cvarGiftCosmeticMinTime),
        get_pcvar_num(g_cvarGiftCosmeticMaxTime)
    );

    new PCosmetic_Type:type = PCosmetic_Type_Normal;
    if (random(100) >= 20 && random(100) <= 40) { //Find random number two times
        type = PCosmetic_Type_Unusual;
    }

    PCosmetic_Give(id, cosmetic, type, time);

    client_cmd(id, "spk %s", g_szSndGiftPickup);

    ExecuteForward(g_fwGiftPicked, g_fwResult, id, ent);
}

public OnGiftKilled(ent, bool:picked)
{
    new owner = pev(ent, pev_owner);
    if (!owner) {
        return;
    }

    if (is_user_connected(owner)) {
        SetupSpawnGiftTask(owner);
    }


    if (!picked) {
        ExecuteForward(g_fwGiftDisappear, g_fwResult, owner, ent);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

AddGiftTarget(const Float:vOrigin[3])
{
    if (g_giftTargets == Invalid_Array) {
        g_giftTargets = ArrayCreate(3);
    }

    ArrayPushArray(g_giftTargets, vOrigin);
}

SpawnGift(id, const Float:vOrigin[3])
{
    new ent = CE_Create(GIFT_ENTITY_CLASSNAME, vOrigin);

    if (!ent) {
        return;
    }

    set_pev(ent, pev_owner, id);
    dllfunc(DLLFunc_Spawn, ent);

    client_cmd(id, "spk %s", g_szSndGiftSpawn);

    ExecuteForward(g_fwGiftSpawn, g_fwResult, id, ent);
}

SetupSpawnGiftTask(id)
{
    set_task(get_pcvar_float(g_cvarGiftSpawnDelay), "TaskSpawnGift", id + TASKID_SUM_SPAWN_GIFT);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskSpawnGift(taskID)
{
    new id = taskID - TASKID_SUM_SPAWN_GIFT;

    new team = UTIL_GetPlayerTeam(id);
    if (team != 1 && team != 2) {
        SetupSpawnGiftTask(id);
        return;
    }

    new Float:vOrigin[3];
    if (g_giftTargets != Invalid_Array && ArraySize(g_giftTargets) > 0) {
        new targetCount = ArraySize(g_giftTargets);
        ArrayGetArray(g_giftTargets, random(targetCount), vOrigin);
    } else {
        if (!Hwn_EventPoints_GetRandom(vOrigin)) {
            SetupSpawnGiftTask(id);
            return;
        }
    }

    SpawnGift(id, vOrigin);
}
