#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>
#include <api_player_cosmetic>

#include <hwn>

#define PLUGIN "[Hwn] Gifts"
#define AUTHOR "Hedgehog Fog"

#define GIFT_ENTITY_CLASSNAME "hwn_item_gift"
#define GIFT_TARGET_ENTITY_CLASSNAME "hwn_gift_target"

#define TASKID_SUM_SPAWN_GIFT 1000

new Array:g_giftTargets;

new const g_szSndGiftSpawn[] = "hwn/items/gift/gift_spawn.wav";
new const g_szSndGiftPickup[] = "hwn/items/gift/gift_pickup.wav";

new g_cvarGiftSpawnDelay;
new g_cvarGiftCosmeticMinTime;
new g_cvarGiftCosmeticMaxTime;

public plugin_precache()
{
    CE_RegisterHook(CEFunction_Spawn, GIFT_TARGET_ENTITY_CLASSNAME, "OnGiftTargetSpawn");
    CE_RegisterHook(CEFunction_Picked, GIFT_ENTITY_CLASSNAME, "OnGiftPicked");

    precache_sound(g_szSndGiftSpawn);
    precache_sound(g_szSndGiftPickup);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_cvarGiftSpawnDelay = register_cvar("hwn_gifts_spawn_delay", "450.0");
    g_cvarGiftCosmeticMinTime = register_cvar("hwn_gifts_cosmetic_min_time", "450");
    g_cvarGiftCosmeticMaxTime = register_cvar("hwn_gifts_cosmetic_max_time", "1200");
}

public plugin_end()
{
    if (g_giftTargets != Invalid_Array) {
        ArrayDestroy(g_giftTargets);
    }
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

public OnGiftTargetSpawn(ent)
{
    if (g_giftTargets == Invalid_Array) {
        g_giftTargets = ArrayCreate(3);
    }

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    ArrayPushArray(g_giftTargets, vOrigin);

    CE_Remove(ent);
}

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
}

/*--------------------------------[ Methods ]--------------------------------*/

SpawnGift(id, const Float:vOrigin[3])
{
    new ent = CE_Create(GIFT_ENTITY_CLASSNAME, vOrigin);

    if (!ent) {
        return;
    }

    set_pev(ent, pev_owner, id);
    dllfunc(DLLFunc_Spawn, ent);

    client_cmd(id, "spk %s", g_szSndGiftSpawn);
}

SetupSpawnGiftTask(id)
{
    set_task(get_pcvar_float(g_cvarGiftSpawnDelay), "TaskSpawnGift", id + TASKID_SUM_SPAWN_GIFT);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskSpawnGift(taskID)
{
    new id = taskID - TASKID_SUM_SPAWN_GIFT;

    static Float:vOrigin[3];
    if (g_giftTargets != Invalid_Array) {
        new targetCount = ArraySize(g_giftTargets);
        new targetIdx = random(targetCount);

        ArrayGetArray(g_giftTargets, targetIdx, vOrigin);
        SpawnGift(id, vOrigin);
    } else {
        if (Hwn_Gamemode_FindEventPoint(vOrigin)) {
            SpawnGift(id, vOrigin);
        }
    }

    SetupSpawnGiftTask(id);
}