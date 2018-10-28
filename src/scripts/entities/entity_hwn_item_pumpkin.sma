#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <fun>

#include <cs_weapons_consts>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Item Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_pumpkin"

enum _:PumpkinType
{
    PumpkinType_Default,
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
    
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "OnPickup");
}

/*------------[ Hooks ]------------*/

public OnSpawn(ent)
{
    new type = random(PumpkinType);
    set_pev(ent, pev_iuser1, type);
    
    set_pev(ent, pev_rendermode, kRenderNormal);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 4.0);
    set_pev(ent, pev_rendercolor, g_fLootTypeColor[type]);
    
    set_pev(ent, pev_framerate, 1.0);    
    
    emit_sound(ent, CHAN_BODY, g_szSndItemSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public OnPickup(ent, id)
{
    new type = pev(ent, pev_iuser1);
    
    switch (type)
    {
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
    
    emit_sound(ent, CHAN_BODY, g_szSndItemPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    return PLUGIN_HANDLED;
}

/*------------[ Methods ]------------*/

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