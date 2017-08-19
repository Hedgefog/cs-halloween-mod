#pragma semicolon 1

#include <amxmodx>

#include <api_player_inventory>
#include <api_player_cosmetic>

#define PLUGIN "[Menu] Player Cosmetic"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

new PInv_ItemType:g_hCosmeticItemType;

new Array:g_playerMenu;
new Array:g_playerMenuSlotRefs;

new g_maxPlayers;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	g_hCosmeticItemType = PInv_GetItemTypeHandler("cosmetic");
	
	g_maxPlayers = get_maxplayers();	
	
	g_playerMenu = ArrayCreate(1, g_maxPlayers+1);
	g_playerMenuSlotRefs = ArrayCreate(1, g_maxPlayers+1);
	for (new i = 0; i <= g_maxPlayers; ++i) {
		ArrayPushCell(g_playerMenu, 0);
		ArrayPushCell(g_playerMenuSlotRefs, Invalid_Array);
	}
}

public plugin_natives()
{
	register_library("menu_player_cosmetic");
	register_native("PCosmetic_Menu_Open", "Native_Open");
}

public plugin_end()
{
	ArrayDestroy(g_playerMenu);
	
	for (new i = 1; i <= g_maxPlayers; ++i) {
		new Array:slotRefs = ArrayGetCell(g_playerMenuSlotRefs, i);
		if (slotRefs != Invalid_Array) {
			ArrayDestroy(slotRefs);
		}
	} ArrayDestroy(g_playerMenuSlotRefs);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Open(pluginID, argc)
{
	new id = get_param(1);
	Open(id);
}

/*--------------------------------[ Methods ]--------------------------------*/

Open(id)
{
	new menu = ArrayGetCell(g_playerMenu, id);
	if (menu) {
		menu_destroy(menu);
	}
	
	menu = Create(id);
	ArraySetCell(g_playerMenu, id, menu);

	menu_display(id, menu);
}

Create(id)
{	
	new callbackDisabled = menu_makecallback("MenuDisabledCallback");	
	new menu = menu_create("Cosmetic Inventory", "MenuHandler");
	
	new Array:slotRefs = ArrayGetCell(g_playerMenuSlotRefs, id);
	if (slotRefs != Invalid_Array) {
		ArrayClear(slotRefs);
	} else {
		slotRefs = ArrayCreate();
		ArraySetCell(g_playerMenuSlotRefs, id, slotRefs);
	}
	
	new size = PInv_Size(id);

	for (new i = 0; i < size; ++i)
	{
		if (g_hCosmeticItemType != PInv_GetItemType(id, i)) {
			continue;
		}
		
		new itemTime = PCosmetic_GetItemTime(id, i);
		if (!itemTime) {
			continue;
		}
		
		ArrayPushCell(slotRefs, i);
		
		new cosmetic = PCosmetic_GetItemCosmetic(id, i);
		new PCosmetic_Type:cosmeticType = PCosmetic_GetItemCosmeticType(id, i);
		
		static szCosmeticName[32];
		PCosmetic_GetCosmeticName(cosmetic, szCosmeticName, charsmax(szCosmeticName));
		
		static text[64];
		format
		(
			text,
			charsmax(text), 
			"%s%s%s (%i seconds left)",
			(PCosmetic_IsItemEquiped(id, i) ? "\y" : ""),
			(cosmeticType == PCosmetic_Type_Unusual ? "Unusual " : "^0"),
			szCosmeticName,
			itemTime
		);
		
		menu_additem(menu, text, .callback = PCosmetic_CanBeEquiped(id, cosmetic, i) ? -1 : callbackDisabled);
	}
	
	if (!size) {
		menu_additem(menu, "You have no cosmetic items", .callback = callbackDisabled);
	}
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	
	return menu;
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler(id, menu, item)
{
	if (item != MENU_EXIT)
	{
		new Array:slotRefs = ArrayGetCell(g_playerMenuSlotRefs, id);
		new slotIdx = ArrayGetCell(slotRefs, item);
		
		new PInv_ItemType:itemType = PInv_GetItemType(id, slotIdx);
		if (itemType == g_hCosmeticItemType) {
			if (PCosmetic_IsItemEquiped(id, slotIdx)) {
				PCosmetic_Unequip(id, slotIdx);
			} else {
				PCosmetic_Equip(id, slotIdx);
			}
		}
	}
	
	if (is_user_connected(id)) {
		menu_cancel(id);	
	}
	
	return PLUGIN_HANDLED;
}

public MenuDisabledCallback()
{
	return ITEM_DISABLED;
}