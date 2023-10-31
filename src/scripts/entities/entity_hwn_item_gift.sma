#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Item Gift"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_gift"

new g_iCeHandler;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
}

public plugin_precache() {
    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/items/gift_v2.mdl",
        .vecMins = Float:{-16.0, -16.0, 0.0},
        .vecMaxs = Float:{16.0, 16.0, 32.0},
        .flLifeTime = 120.0,
        .bIgnoreRounds = true,
        .iPreset = CEPreset_Item
    );

    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "@Entity_Pickup");
}

@Entity_Spawned(this) {
    set_pev(this, pev_framerate, 1.0);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 1.0);
    set_pev(this, pev_rendercolor, {32.0, 32.0, 32.0});
}

@Entity_Pickup(this, pPlayer) {
    new pOwner = pev(this, pev_owner);
    if (pOwner && pPlayer != pOwner) {
        return PLUGIN_CONTINUE;
    }

    return PLUGIN_HANDLED;
}

public FMHook_AddToFullPack_Post(es, e, pEntity, host, hostflags, player, pSet) {
    if (!pev_valid(pEntity)) {
        return;
    }

    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    if (!is_user_connected(host)) {
        return;
    }

    new pOwner = pev(pEntity, pev_owner);
    if (!pOwner || pOwner == host) {
        return;
    }

    set_es(es, ES_RenderMode, kRenderTransTexture);
    set_es(es, ES_RenderAmt, 0);
}
