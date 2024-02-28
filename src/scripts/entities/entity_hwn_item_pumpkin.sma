#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <fun>

#include <api_custom_entities>
#include <api_player_effects>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Item Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_pumpkin"
#define ENTITY_NAME_BIG "hwn_item_pumpkin_big"

#define m_bBig "bBig"
#define m_iType "iType"

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

new const g_szModel[] = "models/hwn/items/pumpkin_loot_v3.mdl";
new const g_szBigModel[] = "models/hwn/items/pumpkin_loot_big_v2.mdl";
new const g_szSndItemSpawn[] = "hwn/items/pumpkin/pumpkin_drop.wav";
new const g_szSndItemPickup[] = "hwn/items/pumpkin/pumpkin_pickup.wav";

new g_pCvarPumpkinFlash;

public plugin_precache() {
    precache_model(g_szModel);
    precache_model(g_szBigModel);
    precache_sound(g_szSndItemSpawn);
    precache_sound(g_szSndItemPickup);

    CE_Register(ENTITY_NAME, CEPreset_Item);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Pickup, "@Entity_Pickup");

    CE_Register(ENTITY_NAME_BIG, CEPreset_Item);
    CE_RegisterHook(ENTITY_NAME_BIG, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME_BIG, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME_BIG, CEFunction_Pickup, "@Entity_Pickup");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarPumpkinFlash = register_cvar("hwn_pumpkin_pickup_flash", "1");
}

@Entity_Init(this) {
    new bool:bBig = CE_GetHandlerByEntity(this) == CE_GetHandler(ENTITY_NAME_BIG);

    if (bBig) {
        CE_SetMember(this, CE_MEMBER_LIFETIME, 30.0);
        CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -16.0, 0.0});
        CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 16.0, 32.0});
        CE_SetMemberString(this, CE_MEMBER_MODEL, g_szBigModel);
    } else {
        CE_SetMember(this, CE_MEMBER_LIFETIME, 10.0);
        CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, 0.0});
        CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 24.0});
        CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel);
    }

    CE_SetMember(this, m_bBig, bBig);
    CE_SetMember(this, CE_MEMBER_RESPAWNTIME, HWN_ITEM_RESPAWN_TIME);
}

@Entity_Spawned(this) {
    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);

    new iType = CE_GetMember(this, m_iType);
    if (iType == Hwn_PumpkinType_Uninitialized) {
        new iMinType = Hwn_PumpkinType_Default + 1;
        iType = iMinType + random(Hwn_PumpkinType - iMinType);
    }

    CE_SetMember(this, m_iType, iType);
    set_pev(this, pev_rendercolor, g_rgflLootTypeColor[iType]);
    set_pev(this, pev_framerate, 1.0);


    emit_sound(this, CHAN_BODY, g_szSndItemSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_Pickup(this, pPlayer) {
    new iType = CE_GetMember(this, m_iType);

    switch (iType) {
        case Hwn_PumpkinType_Crits: {
            PlayerEffect_Set(pPlayer, "hwn-crits", true, 2.0);
        }
        case Hwn_PumpkinType_Equipment: {
            Hwn_PEquipment_GiveAmmo(pPlayer);
            Hwn_PEquipment_GiveArmor(pPlayer, 30);
        }
        case Hwn_PumpkinType_Health: {
            Hwn_PEquipment_GiveHealth(pPlayer, 30);
        }
        case Hwn_PumpkinType_Gravity: {
            PlayerEffect_Set(pPlayer, "hwn-moonjump", true, 2.0);
        }
    }

    static Float:vecPlayerOrigin[3];
    pev(pPlayer, pev_origin, vecPlayerOrigin);

    emit_sound(this, CHAN_BODY, g_szSndItemPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    if (get_pcvar_num(g_pCvarPumpkinFlash) > 0) {
        @Entity_FlashEffect(this, vecPlayerOrigin, iType);
    }

    return PLUGIN_HANDLED;
}

@Entity_FlashEffect(pEntity, const Float:vecOrigin[3], type) {
    if (CE_GetMember(pEntity, m_bBig)) {
        UTIL_Message_Dlight(vecOrigin, FLASH_RADIUS_BIG, {HWN_COLOR_SECONDARY}, FLASH_LIFETIME, FLASH_DECAY_RATE_BIG);
    } else {
        new rgiColor[3];
        for (new i = 0; i < 3; ++i) rgiColor[i] = floatround(g_rgflLootTypeColor[type][i]);
        UTIL_Message_Dlight(vecOrigin, FLASH_RADIUS, rgiColor, FLASH_LIFETIME, FLASH_DECAY_RATE);
    }
}
