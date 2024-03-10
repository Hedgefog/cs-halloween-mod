#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Item Gift"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_gift"

new const g_szModel[] = "models/hwn/items/gift_v2.mdl";

new CE:g_iCeHandler;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
}

public plugin_precache() {
    precache_model(g_szModel);

    g_iCeHandler = CE_Register(ENTITY_NAME, CEPreset_Item);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Pickup, "@Entity_Pickup");
}

@Entity_Init(this) {
    CE_SetMember(this, CE_MEMBER_LIFETIME, 120.0);
    CE_SetMember(this, CE_MEMBER_IGNOREROUNDS, true);
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -16.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 16.0, 32.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
}

@Entity_Spawned(this) {
    set_pev(this, pev_framerate, 1.0);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 1.0);
    set_pev(this, pev_rendercolor, {32.0, 32.0, 32.0});
}

@Entity_Pickup(this, pPlayer) {
    new pOwner = pev(this, pev_owner);
    if (pOwner && pPlayer != pOwner) return PLUGIN_CONTINUE;

    return PLUGIN_HANDLED;
}

public FMHook_AddToFullPack_Post(es, e, pEntity, pHost, pHostFlags, pPlayer, pSet) {
    if (!pev_valid(pEntity)) return;
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) return;
    if (!is_user_connected(pHost)) return;

    new pOwner = pev(pEntity, pev_owner);
    if (!pOwner || pOwner == pHost) return;

    set_es(es, ES_RenderMode, kRenderTransTexture);
    set_es(es, ES_RenderAmt, 0);
}
