#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <fun>

#include <cs_weapons_consts>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Item Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_pumpkin"
#define ENTITY_NAME_BIG "hwn_item_pumpkin_big"

#define TASKID_SUM_DISABLE_CRITS 1000

#define FLASH_RADIUS 16
#define FLASH_LIFETIME 10
#define FLASH_DECAY_RATE 16
#define FLASH_RADIUS_BIG 24
#define FLASH_DECAY_RATE_BIG 24

enum _:PumpkinType
{
    PumpkinType_Crits,
    PumpkinType_Equipment,
    PumpkinType_Health
};

new const Float:g_fLootTypeColor[PumpkinType][3] =
{
    {HWN_COLOR_PURPLE_F},
    {HWN_COLOR_YELLOW_F},
    {HWN_COLOR_RED_F}
};

new const g_szSndItemSpawn[] = "hwn/items/pumpkin/pumpkin_drop.wav";
new const g_szSndItemPickup[] = "hwn/items/pumpkin/pumpkin_pickup.wav";

new g_cvarPumpkinFlash;

new g_ceHandlerBig;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{
    precache_sound(g_szSndItemSpawn);
    precache_sound(g_szSndItemPickup);

    CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/items/pumpkin_loot_v3.mdl"),
        .vMins = Float:{-12.0, -12.0, 0.0},
        .vMaxs = Float:{12.0, 12.0, 24.0},
        .fLifeTime = 10.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_Item
    );

    g_ceHandlerBig = CE_Register(
        .szName = ENTITY_NAME_BIG,
        .modelIndex = precache_model("models/hwn/items/pumpkin_loot_big_v2.mdl"),
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 32.0},
        .fLifeTime = 30.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_Item
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "OnPickup");

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_BIG, "OnSpawn");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME_BIG, "OnPickup");

    g_cvarPumpkinFlash = register_cvar("hwn_pumpkin_pickup_flash", "1");
}

/*------------[ Hooks ]------------*/

public OnSpawn(ent)
{
    new type = random(PumpkinType);
    set_pev(ent, pev_iuser1, type);

    set_pev(ent, pev_rendermode, kRenderNormal);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 4.0);

    if (isBig(ent)) {
        set_pev(ent, pev_rendercolor, Float:{HWN_COLOR_GREEN_DARK_F});
    } else {
        set_pev(ent, pev_rendercolor, g_fLootTypeColor[type]);
    }

    set_pev(ent, pev_framerate, 1.0);

    emit_sound(ent, CHAN_BODY, g_szSndItemSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public OnPickup(ent, id)
{
    new type = isBig(ent) ? -1 : pev(ent, pev_iuser1);
    switch (type)
    {
        case PumpkinType_Crits:
        {
            GiveCrits(id, 1.0);
        }
        case PumpkinType_Equipment:
        {
            GiveAmmo(id);
            GiveArmor(id, 30.0);
        }
        case PumpkinType_Health:
        {
            GiveHealth(id, 30.0);
        }
    }

    static Float:vPlayerOrigin[3];
    pev(id, pev_origin, vPlayerOrigin);

    emit_sound(ent, CHAN_BODY, g_szSndItemPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    if (get_pcvar_num(g_cvarPumpkinFlash) > 0) {
        FlashEffect(ent, vPlayerOrigin, type);
    }

    return PLUGIN_HANDLED;
}

/*------------[ Methods ]------------*/

GiveCrits(id, Float:fTime)
{
    if (Hwn_Crits_Get(id) && !task_exists(id + TASKID_SUM_DISABLE_CRITS)) {
        return;
    }

    Hwn_Crits_Set(id, true);
    remove_task(id + TASKID_SUM_DISABLE_CRITS);
    set_task(fTime, "TaskDisableCrits", id + TASKID_SUM_DISABLE_CRITS);
}

GiveHealth(id, Float:fCount)
{
    new Float:fHealth;
    pev(id, pev_health, fHealth);

    if (fHealth < 100.0) {
        fHealth += fCount;

        if (fHealth > 100.0) {
            fHealth = 100.0;
        }

        set_pev(id, pev_health, fHealth);
    }
}


GiveArmor(id, Float:fCount)
{
    new Float:fArmor = float(pev(id, pev_armorvalue));

    if (fArmor < 100.0) {
        fArmor += fCount;

        if (fArmor > 100.0) {
            fArmor = 100.0;
        }

        set_pev(id, pev_armorvalue, fArmor);
    }
}

GiveAmmo(id)
{
    new weapons[32];
    new weaponCount = 0;

    get_user_weapons(id, weapons, weaponCount);

    for (new i = 0; i < weaponCount; ++i) {
        new weapon = weapons[i];
        new ammoType = WeaponAmmo[weapon];

        if (ammoType >= 0) {
            give_item(id, AmmoEntityNames[ammoType]);
        }
    }
}

FlashEffect(ent, const Float:vOrigin[3], type)
{
    if (isBig(ent)) {
        UTIL_Message_Dlight(vOrigin, FLASH_RADIUS_BIG, {HWN_COLOR_GREEN_DARK}, FLASH_LIFETIME, FLASH_DECAY_RATE_BIG);
    } else {
        new color[3];
        for (new i = 0; i < 3; ++i) {
            color[i] = floatround(g_fLootTypeColor[type][i]);
        }

        UTIL_Message_Dlight(vOrigin, FLASH_RADIUS, color, FLASH_LIFETIME, FLASH_DECAY_RATE);
    }
}

bool:isBig(ent) {
    return CE_GetHandlerByEntity(ent) == g_ceHandlerBig;
}

/*------------[ Tasks ]------------*/

public TaskDisableCrits(taskID)
{
    new id = taskID - TASKID_SUM_DISABLE_CRITS;
    Hwn_Crits_Set(id, false);
}
