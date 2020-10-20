#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Item Pumpkin Big"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_pumpkin_big"

#define FLASH_RADIUS 24
#define FLASH_LIFETIME 10
#define FLASH_DECAY_RATE 24

new const g_szSndItemSpawn[] = "hwn/items/pumpkin/pumpkin_drop.wav";
new const g_szSndItemPickup[] = "hwn/items/pumpkin/pumpkin_pickup.wav";

new g_cvarPumpkinFlash;

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
        .modelIndex = precache_model("models/hwn/items/pumpkin_loot_big_v2.mdl"),
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 32.0},
        .fLifeTime = 30.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_Item
    );
    
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "OnPickup");

    if (cvar_exists("hwn_pumpkin_pickup_flash")) {
        g_cvarPumpkinFlash = get_cvar_pointer("hwn_pumpkin_pickup_flash");
    } else {
        g_cvarPumpkinFlash = register_cvar("hwn_pumpkin_pickup_flash", "1");
    }
}

/*------------[ Hooks ]------------*/

public OnSpawn(ent)
{    
    set_pev(ent, pev_rendermode, kRenderNormal);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 4.0);
    set_pev(ent, pev_rendercolor, {HWN_COLOR_GREEN_DARK_F});
    
    set_pev(ent, pev_framerate, 1.0);    
    
    emit_sound(ent, CHAN_BODY, g_szSndItemSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public OnPickup(ent, id)
{    
    static Float:vPlayerOrigin[3];
    pev(ent, pev_origin, vPlayerOrigin);
    
    emit_sound(ent, CHAN_BODY, g_szSndItemPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    if (get_pcvar_num(g_cvarPumpkinFlash) > 0) {
        UTIL_Message_Dlight(vPlayerOrigin, FLASH_RADIUS, {HWN_COLOR_GREEN_DARK}, FLASH_LIFETIME, FLASH_DECAY_RATE);
    }

    return PLUGIN_HANDLED;
}