#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_player_cosmetic>

#include <hwn>

#define PLUGIN "[Hwn] Cosmetics"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_COSMETIC_TIMER 100

#define UNUSUAL_ENTITY_RENDER_AMT 1.0

new Array:g_cosmetics;

public plugin_precache()
{
	g_cosmetics = ArrayCreate();

	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Coffin Pack",
			.modelIndex = precache_model("models/hwn/cosmetics/coffinpack.mdl"),
			.groups = (PCosmetic_Group_Back)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Devil Horns",
			.modelIndex = precache_model("models/hwn/cosmetics/devil_horns.mdl"),
			.groups = (PCosmetic_Group_Mask)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Devil Tail",
			.modelIndex = precache_model("models/hwn/cosmetics/devil_tail.mdl"),
			.groups = (PCosmetic_Group_Fanny)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Devil Wings",
			.modelIndex = precache_model("models/hwn/cosmetics/devil_wings.mdl"),
			.groups = (PCosmetic_Group_Back)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Garlik Flank Stake",
			.modelIndex = precache_model("models/hwn/cosmetics/garlic_flank_stake.mdl"),
			.groups = (PCosmetic_Group_Legs)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Holy Hunter",
			.modelIndex = precache_model("models/hwn/cosmetics/holy_hunter.mdl"),
			.groups = (PCosmetic_Group_Hat)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Pumpkin",
			.modelIndex = precache_model("models/hwn/cosmetics/pumpkin_hat.mdl"),
			.groups = (PCosmetic_Group_Hat | PCosmetic_Group_Mask)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Silver Bullets",
			.modelIndex = precache_model("models/hwn/cosmetics/silver_bullets.mdl"),
			.groups = (PCosmetic_Group_Body)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Skull",
			.modelIndex = precache_model("models/hwn/cosmetics/skull.mdl"),
			.groups = (PCosmetic_Group_Mask)
		)
	);
	
	ArrayPushCell(g_cosmetics,
		PCosmetic_Register(
			.szName = "Spookyhood",
			.modelIndex = precache_model("models/hwn/cosmetics/spookyhood.mdl"),
			.groups = (PCosmetic_Group_Hat)
		)
	);
}

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_natives()
{
	register_library("hwn");
	register_native("Hwn_Cosmetic_GetCount", "Native_GetCount");
	register_native("Hwn_Cosmetic_GetCosmetic", "Native_GetCosmetic");
}

public plugin_end()
{
	ArrayDestroy(g_cosmetics);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_GetCount(pluginID, argc)
{
	return ArraySize(g_cosmetics);
}

public Native_GetCosmetic(pluginID, argc)
{
	new index = get_param(1);
	return ArrayGetCell(g_cosmetics, index);
}