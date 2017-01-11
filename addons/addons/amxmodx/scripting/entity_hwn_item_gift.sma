#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Item Gift"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_gift"

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
	
	register_forward(FM_AddToFullPack, "onAddToFullPack", ._post = 1);
}

public plugin_precache()
{
	CE_Register(
		.szName = ENTITY_NAME,
		.modelIndex = precache_model("models/hwn/items/gift_v2.mdl"),
		.vMins = Float:{-16.0, -16.0, 0.0},
		.vMaxs = Float:{16.0, 16.0, 32.0},
		.fLifeTime = 120.0,
		.preset = CEPreset_Item
	);
	
	CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
	CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "OnPickup");
}

public OnSpawn(ent)
{
	set_pev(ent, pev_framerate, 1.0);
	
	set_pev(ent, pev_renderfx, kRenderFxGlowShell);
	set_pev(ent, pev_renderamt, 1.0);
	set_pev(ent, pev_rendercolor, {32.0, 32.0, 32.0});
}

public OnPickup(ent, id)
{
	new owner = pev(ent, pev_owner);
	
	if (id != owner) {
		return PLUGIN_CONTINUE;
	}
	
	return PLUGIN_HANDLED;
}

public onAddToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if (!pev_valid(ent)) {
		return;
	}

	if (!CE_CheckAssociation(ent)) {
		return;
	}
	
	if(pev(ent, pev_owner) == host) {
		return;
	}
	
	set_es(es, ES_RenderMode, kRenderTransTexture);
	set_es(es, ES_RenderAmt, 0);
}