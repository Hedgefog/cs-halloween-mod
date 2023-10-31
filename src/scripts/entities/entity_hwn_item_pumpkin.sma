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

#define FLASH_RADIUS 16
#define FLASH_LIFETIME 10
#define FLASH_DECAY_RATE 16
#define FLASH_RADIUS_BIG 24
#define FLASH_DECAY_RATE_BIG 24

new const Float:g_rgflLootTypeColor[Hwn_PumpkinType][3] = {
    {0.0, 0.0, 0.0},
    {HWN_COLOR_SECONDARY_F},
    {HWN_COLOR_PRIMARY_F},
    {HWN_COLOR_YELLOW_F},
    {HWN_COLOR_RED_F},
    {50.0, 50.0, 50.0},
};

new const g_szSndItemSpawn[] = "hwn/items/pumpkin/pumpkin_drop.wav";
new const g_szSndItemPickup[] = "hwn/items/pumpkin/pumpkin_pickup.wav";

new g_pCvarPumpkinFlash;

public plugin_precache() {
    precache_sound(g_szSndItemSpawn);
    precache_sound(g_szSndItemPickup);

    CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/items/pumpkin_loot_v3.mdl",
        .vMins = Float:{-12.0, -12.0, 0.0},
        .vMaxs = Float:{12.0, 12.0, 24.0},
        .fLifeTime = 10.0,
        .fRespawnTime = HWN_ITEM_RESPAWN_TIME,
        .preset = CEPreset_Item
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "@Entity_Pickup");

    CE_Register(
        ENTITY_NAME_BIG,
        .szModel = "models/hwn/items/pumpkin_loot_big_v2.mdl",
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 32.0},
        .fLifeTime = 30.0,
        .fRespawnTime = HWN_ITEM_RESPAWN_TIME,
        .preset = CEPreset_Item
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_BIG, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME_BIG, "@Entity_Pickup");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarPumpkinFlash = register_cvar("hwn_pumpkin_pickup_flash", "1");
}

@Entity_Spawn(pEntity) {
    set_pev(pEntity, pev_rendermode, kRenderNormal);
    set_pev(pEntity, pev_renderfx, kRenderFxGlowShell);
    set_pev(pEntity, pev_renderamt, 4.0);

    new iType = pev(pEntity, pev_iuser1);
    if (iType == Hwn_PumpkinType_Uninitialized) {
        new iMinType = Hwn_PumpkinType_Default + 1;
        iType = iMinType + random(Hwn_PumpkinType - iMinType);
    }

    set_pev(pEntity, pev_iuser1, iType);
    set_pev(pEntity, pev_rendercolor, g_rgflLootTypeColor[iType]);
    set_pev(pEntity, pev_framerate, 1.0);

    CE_SetMember(pEntity, "bBig", CE_GetHandlerByEntity(pEntity) == CE_GetHandler(ENTITY_NAME_BIG));

    emit_sound(pEntity, CHAN_BODY, g_szSndItemSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_Pickup(pEntity, pPlayer) {
    new iType = pev(pEntity, pev_iuser1);

    switch (iType) {
        case Hwn_PumpkinType_Crits: {
            Hwn_Player_SetEffect(pPlayer, "crits", true, 2.0);
        }
        case Hwn_PumpkinType_Equipment: {
            Hwn_PEquipment_GiveAmmo(pPlayer);
            Hwn_PEquipment_GiveArmor(pPlayer, 30);
        }
        case Hwn_PumpkinType_Health: {
            Hwn_PEquipment_GiveHealth(pPlayer, 30);
        }
        case Hwn_PumpkinType_Gravity: {
            Hwn_Player_SetEffect(pPlayer, "moonjump", true, 2.0);
        }
    }

    static Float:vecPlayerOrigin[3];
    pev(pPlayer, pev_origin, vecPlayerOrigin);

    emit_sound(pEntity, CHAN_BODY, g_szSndItemPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    if (get_pcvar_num(g_pCvarPumpkinFlash) > 0) {
        @Entity_FlashEffect(pEntity, vecPlayerOrigin, iType);
    }

    return PLUGIN_HANDLED;
}

@Entity_FlashEffect(pEntity, const Float:vecOrigin[3], type) {
    if (CE_GetMember(pEntity, "bBig")) {
        UTIL_Message_Dlight(vecOrigin, FLASH_RADIUS_BIG, {HWN_COLOR_SECONDARY}, FLASH_LIFETIME, FLASH_DECAY_RATE_BIG);
    } else {
        new rgiColor[3];
        for (new i = 0; i < 3; ++i) {
            rgiColor[i] = floatround(g_rgflLootTypeColor[type][i]);
        }

        UTIL_Message_Dlight(vecOrigin, FLASH_RADIUS, rgiColor, FLASH_LIFETIME, FLASH_DECAY_RATE);
    }
}

