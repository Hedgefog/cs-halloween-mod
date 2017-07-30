#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <nvault>

#include <api_player_inventory>
#include <api_player_cosmetic>

#define PLUGIN "[Player Inventory Item] Cosmetic"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_PLAYER_TIMER 1000

#define ITEM_TYPE "cosmetic"
#define UNUSUAL_ENTITY_RENDER_AMT 1.0

enum ItemState
{
	ItemState_None = 0,
	ItemState_Equiped,
	ItemState_Equip,
	ItemState_Unequip
};

enum ItemData
{
	ItemData_Cosmetic = 0,
	PCosmetic_Type:ItemData_CosmeticType,
	ItemData_Time,
	ItemState:ItemData_State,
	ItemData_Entity
};

new Trie:g_cosmeticIndexes;
new Array:g_cosmeticName;
new Array:g_cosmeticGroups;
new Array:g_cosmeticModelIndex;
new g_cosmeticCount = 0;

new Array:g_playerRenderMode;
new Array:g_playerRenderAmt;

new g_allocClassname;

new PInv_ItemType:g_itemType;
new g_hVault;

new g_maxPlayers;

public plugin_precache()
{
	g_allocClassname = engfunc(EngFunc_AllocString, "info_target");	
	
	g_hVault = nvault_open("api_player_cosmetic");
	g_itemType = PInv_RegisterItemType(ITEM_TYPE);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
	
	g_playerRenderMode	= ArrayCreate(1, g_maxPlayers+1);
	g_playerRenderAmt	= ArrayCreate(1, g_maxPlayers+1);
	
	g_maxPlayers = get_maxplayers();	
	
	for (new i = 0; i <= g_maxPlayers; ++i) {
		ArrayPushCell(g_playerRenderMode, 0);
		ArrayPushCell(g_playerRenderAmt, 0);
	}
}

public plugin_natives()
{
	register_library("api_player_cosmetic");
	register_native("PCosmetic_Register", "Native_Register");
	register_native("PCosmetic_Give", "Native_Give");
	
	register_native("PCosmetic_Equip", "Native_Equip");
	register_native("PCosmetic_Unequip", "Native_Unequip");
	register_native("PCosmetic_IsItemEquiped", "Native_IsItemEquiped");
	register_native("PCosmetic_CanBeEquiped", "Native_CanBeEquiped");
	
	register_native("PCosmetic_GetItemCosmetic", "Native_GetItemCosmetic");
	register_native("PCosmetic_GetItemCosmeticType", "Native_GetItemCosmeticType");
	register_native("PCosmetic_GetItemTime", "Native_GetItemTime");
	
	register_native("PCosmetic_GetCosmeticName", "Native_GetCosmeticName");
	register_native("PCosmetic_GetCosmeticGroups", "Native_GetCosmeticGroups");
}

public plugin_end()
{
	TrieDestroy(g_cosmeticIndexes);

	if (g_cosmeticCount)  {
		ArrayDestroy(g_cosmeticName);
		ArrayDestroy(g_cosmeticGroups);
		ArrayDestroy(g_cosmeticModelIndex);		
	}

	ArrayDestroy(g_playerRenderMode);
	ArrayDestroy(g_playerRenderAmt);
	
	nvault_close(g_hVault);
}

#if AMXX_VERSION_NUM < 183
	public client_disconnect(id)
#else
	public client_disconnected(id)
#endif
{
	new size = PInv_Size(id);
	for (new i = 0; i < size; ++i)
	{
		new PInv_ItemType:itemType = PInv_GetItemType(id, i);
		if (itemType != g_itemType) {
			continue;
		}
	
		Unequip(id, i);
	}
	
	remove_task(id);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerSpawn(id)
{
	UpdateEquipment(id);
	
	if (!task_exists(id)) {
		set_task(0.1, "TaskPlayerThink", id);
	}
}

public OnPlayerKilled(id)
{
	remove_task(id);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskPlayerThink(id)
{
	new renderMode = pev(id, pev_rendermode);
	
	static Float:renderAmt;
	pev(id, pev_renderamt, renderAmt);
	
	if (renderMode == ArrayGetCell(g_playerRenderMode, id)
		&& renderAmt == ArrayGetCell(g_playerRenderAmt, id))
	{
		return;
	}
	
	ArraySetCell(g_playerRenderMode, id, renderMode);
	ArraySetCell(g_playerRenderAmt, id, renderAmt);

	new size = PInv_Size(id);
	for (new i = 0; i < size; ++i)
	{
		if (g_itemType != PInv_GetItemType(id, i)) {
			continue;
		}
		
		new Array:item = Array:PInv_GetItem(id, i);
		
		if (ArrayGetCell(item, _:ItemData_State) != ItemState_Equiped) {
			continue;
		}
		
		new ent = ArrayGetCell(item, _:ItemData_Entity);
		set_pev(ent, pev_rendermode, renderMode);
		
		if (ArrayGetCell(item, _:ItemData_CosmeticType) == PCosmetic_Type_Normal) {
			set_pev(ent, pev_renderamt, renderAmt);	
		} else {
			set_pev(ent, pev_renderamt, UNUSUAL_ENTITY_RENDER_AMT);
		}
	}
	
	set_task(0.1, "TaskPlayerThink", id);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(pluginID, argc)
{
	new szName[32];
	get_string(1, szName, charsmax(szName));
	
	new PCosmetic_Groups:groups = PCosmetic_Groups:get_param(2);
	new modelIndex = get_param(3);
	
	return Register(szName, groups, modelIndex);
}

public Native_Give(pluginID, argc)
{
	new id = get_param(1);
	new cosmetic = get_param(2);
	new PCosmetic_Type:cosmeticType = PCosmetic_Type:get_param(3);
	new time = get_param(4);
	
	return Give(id, cosmetic, cosmeticType, time);
}

public Native_GetCosmeticName(pluginID, argc)
{
	new cosmetic = get_param(1);
	new maxlen = get_param(3);	
	
	static szName[32];
	ArrayGetString(g_cosmeticName, cosmetic, szName, charsmax(szName));
	set_string(2, szName, maxlen);
}

public Native_GetCosmeticGroups(pluginID, argc)
{
	new cosmetic = get_param(1);
	
	return ArrayGetCell(g_cosmeticGroups, cosmetic);
}

public Native_Equip(pluginID, argc)
{
	new id = get_param(1);
	new slotIdx = get_param(2);

	new Array:item = Array:PInv_GetItem(id, slotIdx);		
	new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
	
	if (itemState == ItemState_Equiped) {
		return;
	}
	
	if (itemState == ItemState_Equip) {
		return;
	}
	
	ArraySetCell(item, _:ItemData_State, ItemState_Equip);
}

public Native_Unequip(pluginID, argc)
{
	new id = get_param(1);
	new slotIdx = get_param(2);

	new Array:item = Array:PInv_GetItem(id, slotIdx);		
	new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
	
	if (itemState == ItemState_None) {
		return;
	}
	
	if (itemState == ItemState_Unequip) {
		return;
	}
	
	ArraySetCell(item, _:ItemData_State, ItemState_Unequip);
}

public Native_IsItemEquiped(pluginID, argc)
{
	new id = get_param(1);
	new slotIdx = get_param(2);
	
	new Array:item = Array:PInv_GetItem(id, slotIdx);		
	new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
	
	return (itemState == ItemState_Equiped || itemState == ItemState_Equip);
}

public Native_CanBeEquiped(pluginID, argc)
{
	new id = get_param(1);
	new cosmetic = get_param(2);
	new ignoreSlotIdx = get_param(3);
	
	return CanBeEquiped(id, cosmetic, ignoreSlotIdx);
}

public Native_GetItemCosmetic(pluginID, argc)
{
	new id = get_param(1);
	new slotIdx = get_param(2);
	
	new Array:item = Array:PInv_GetItem(id, slotIdx);
	return ArrayGetCell(item, _:ItemData_Cosmetic);
}

public Native_GetItemCosmeticType(pluginID, argc)
{
	new id = get_param(1);
	new slotIdx = get_param(2);
	
	new Array:item = Array:PInv_GetItem(id, slotIdx);		
	return ArrayGetCell(item, _:ItemData_CosmeticType);
}

public Native_GetItemTime(pluginID, argc)
{
	new id = get_param(1);
	new slotIdx = get_param(2);
	
	new Array:item = Array:PInv_GetItem(id, slotIdx);		
	return ArrayGetCell(item, _:ItemData_Time);
}

/*--------------------------------[ Events ]--------------------------------*/

public PInv_Event_SlotLoaded(id, slotIdx)
{
	new PInv_ItemType:itemType = PInv_GetItemType(id, slotIdx);
	if (PInv_ItemType:itemType != g_itemType) {
		return; //Invalid item type
	}
	
	new item = PInv_GetItem(id, slotIdx);
	
	new cosmetic;	
	new PCosmetic_Type:cosmeticType;
	new itemTime;
	new ItemState:itemState;	
	
	if (item == _:Invalid_Array) {
		return; //Handler is invalid
	}
	
	if (!LoadItem(item, cosmetic, cosmeticType, itemTime, itemState)) {
		PInv_SetItem(id, slotIdx, Invalid_Array, PInv_Invalid_ItemType);
		PInv_TakeItem(id, slotIdx);
		return; //Invalid cosmetic
	}
	
	new _item = _:CreateCosmetic(cosmetic, cosmeticType, itemTime);
	item = _item;
	
	PInv_SetItem(id, slotIdx, item, g_itemType);
	ArraySetCell(Array:item, _:ItemData_State, itemState); //Change state of item
}

public PInv_Event_SlotSaved(id, slotIdx)
{
	new PInv_ItemType:itemType = PInv_GetItemType(id, slotIdx);
	if (itemType != g_itemType) {
		return; //Invalid item type
	}
	
	new item = PInv_GetItem(id, slotIdx);
	if (item == _:Invalid_Array) {
		return; //Handler is invalid
	}
	
	SaveItem(item); //Save data about handler
}

public PInv_Event_TakeSlot(id, slotIdx)
{
	new PInv_ItemType:itemType = PInv_GetItemType(id, slotIdx);
	if (itemType != g_itemType) {
		return; //Invalid item type
	}
	
	new Array:item = PInv_GetItem(id, slotIdx);
	if (item == Invalid_Array) {
		return; //Handler is invalid
	}
	
	ArrayDestroy(item);
}

/*--------------------------------[ Methods ]--------------------------------*/

Array:CreateCosmetic(cosmetic, PCosmetic_Type:cosmeticType, time)
{
	new Array:item = ArrayCreate(1, _:ItemData);
	for (new i = 0; i < _:ItemData; ++i) {
		ArrayPushCell(item, 0);
	}
	
	ArraySetCell(item, _:ItemData_Cosmetic, cosmetic);
	ArraySetCell(item, _:ItemData_CosmeticType, cosmeticType);
	ArraySetCell(item, _:ItemData_Time, time);
	ArraySetCell(item, _:ItemData_State, ItemState_None);
	
	return item;
}

Register(const szName[], PCosmetic_Groups:groups, modelIndex)
{
	if (!g_cosmeticCount) {
		g_cosmeticName = ArrayCreate(32);		
		g_cosmeticGroups = ArrayCreate();
		g_cosmeticModelIndex = ArrayCreate();
		g_cosmeticIndexes = TrieCreate();
	}

	ArrayPushString(g_cosmeticName, szName);
	ArrayPushCell(g_cosmeticGroups, groups);
	ArrayPushCell(g_cosmeticModelIndex, modelIndex);
	
	new cosmetic = g_cosmeticCount;
	TrieSetCell(g_cosmeticIndexes, szName, cosmetic);
	
	g_cosmeticCount++;
	
	return cosmetic;
}

Give(id, cosmetic, PCosmetic_Type:cosmeticType, time)
{
	new slotIdx = -1;
	new Array:item = Invalid_Array;

	new size = PInv_Size(id);
	for (new i = 0; i < size; ++i)
	{
		if (g_itemType != PInv_GetItemType(id, i)) {
			continue;
		}
		
		item = Array:PInv_GetItem(id, i);
		new itemCosmetic = ArrayGetCell(item, _:ItemData_Cosmetic);
		new PCosmetic_Type:itemCosmeticType = ArrayGetCell(item, _:ItemData_CosmeticType);
		
		if (cosmetic == itemCosmetic && cosmeticType == itemCosmeticType) {
			slotIdx = i;
			break;
		}
	}
	
	if (slotIdx == -1) {
		item = CreateCosmetic(cosmetic, cosmeticType, time);
		slotIdx = PInv_GiveItem(id, item, g_itemType);
	}
	
	return slotIdx;
}

Equip(id, slotIdx)
{
	new PInv_ItemType:itemType = PInv_GetItemType(id, slotIdx);
	if (itemType != g_itemType) {
		return; //Is not a cosmetic
	}
	
	new Array:item = Array:PInv_GetItem(id, slotIdx);
	
	new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
	
	if (itemState == ItemState_Equiped) {
		return; //Already equiped
	}
	
	new cosmetic = ArrayGetCell(item, _:ItemData_Cosmetic);
	if (!CanBeEquiped(id, cosmetic, slotIdx)) {
		return; //Can't be equiped
	}
	
	new PCosmetic_Type:cosmeticType = ArrayGetCell(item, _:ItemData_CosmeticType);	

	new ent = CreateCosmeticEntity(id, cosmetic, cosmeticType);
	ArraySetCell(item, _:ItemData_Entity, ent);
	ArraySetCell(item, _:ItemData_State, ItemState_Equiped);
	
	if (!task_exists(id+TASKID_SUM_PLAYER_TIMER)) {
		set_task(1.0, "TaskPlayerTimer", id+TASKID_SUM_PLAYER_TIMER, _, _, "b");
	}
}

Unequip(id, slotIdx)
{
	new PInv_ItemType:itemType = PInv_GetItemType(id, slotIdx);
	if (itemType != g_itemType) {
		return; //Is not a cosmetic
	}
	
	new Array:item = Array:PInv_GetItem(id, slotIdx);
	new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
	
	if (itemState == ItemState_None) {
		return; //Not equiped
	}
	
	new ent = ArrayGetCell(item, _:ItemData_Entity);
	set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);

	ArraySetCell(item, _:ItemData_Entity, 0);
	ArraySetCell(item, _:ItemData_State, ItemState_None);
	
	new itemTime = ArrayGetCell(item, _:ItemData_Time);
	if (!itemTime) {
		PInv_TakeItem(id, slotIdx);
	}
}

bool:CanBeEquiped(id, cosmetic, ignoreSlotIdx = -1)
{
	new cosmeticGroups = ArrayGetCell(g_cosmeticGroups, cosmetic);

	new size = PInv_Size(id);
	for (new i = 0; i < size; ++i)
	{
		if (i == ignoreSlotIdx) {
			continue;
		}
		
		new PInv_ItemType:itemType = PInv_GetItemType(id, i);
		if (itemType != g_itemType) {
			continue;
		}
	
		new Array:item = Array:PInv_GetItem(id, i);

		new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
		if (itemState != ItemState_Equiped && itemState != ItemState_Equip) {
			continue; //This item not equiped.
		}
		
		new itemCosmetic = ArrayGetCell(item, _:ItemData_Cosmetic);
		if (cosmetic == itemCosmetic) {
			return false; //This item is already equiped
		}
		
		new itemCosmeticGroups = ArrayGetCell(g_cosmeticGroups, itemCosmetic);
		if (cosmeticGroups & itemCosmeticGroups) {
			return false; //Item with some groups already equiped
		}
	}
	
	return true;
}

CreateCosmeticEntity(owner, cosmetic, PCosmetic_Type:type = PCosmetic_Type_Normal)
{
	new ent = engfunc(EngFunc_CreateNamedEntity, g_allocClassname);
	set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
	set_pev(ent, pev_aiment, owner);
	
	if (type == PCosmetic_Type_Unusual) {
		set_pev(ent, pev_renderfx, kRenderFxGlowShell);
		set_pev(ent, pev_rendercolor, {120.0, 0.0, 200.0});
		set_pev(ent, pev_renderamt, UNUSUAL_ENTITY_RENDER_AMT);
	}
	
	new modelIndex = ArrayGetCell(g_cosmeticModelIndex, cosmetic);
	set_pev(ent, pev_modelindex, modelIndex);
	
	return ent;
}

UpdateEquipment(id)
{
	new size = PInv_Size(id);
	for (new i = 0; i < size; ++i)
	{
		new PInv_ItemType:itemType = PInv_GetItemType(id, i);
		if (itemType != g_itemType) {
			return; //Invalid item type
		}	
	
		new Array:item = Array:PInv_GetItem(id, i);
		new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
		
		if (itemState == ItemState_Equip) {
			Equip(id, i);
		} else if (itemState == ItemState_Unequip) {
			Unequip(id, i);
		}
	}
}

/*--------------------------------[ Vault ]--------------------------------*/

bool:LoadItem(any:item, &cosmetic, &PCosmetic_Type:cosmeticType, &itemTime, &ItemState:itemState)
{
	new szKey[32];
	new szValue[32];
	
	//cosmetic;
	{
		format(szKey, charsmax(szKey), "%i_name", item);
		nvault_get(g_hVault, szKey, szValue, charsmax(szValue));
		nvault_remove(g_hVault, szKey);
		
		if (szValue[0] == '^0') {
			return false;
		}
		
		//Get index by name
		if (!TrieGetCell(g_cosmeticIndexes, szValue, cosmetic)) {
			return false;
		}
	}
	
	//cosmeticType;
	{
		format(szKey, charsmax(szKey), "%i_cosmeticType", item);
		cosmeticType = PCosmetic_Type:nvault_get(g_hVault, szKey);
		nvault_remove(g_hVault, szKey);
	}
	
	//itemTime;
	{
		format(szKey, charsmax(szKey), "%i_time", item);
		itemTime = nvault_get(g_hVault, szKey);
		nvault_remove(g_hVault, szKey);
	}
	
	//ItemState:itemState;
	{
		format(szKey, charsmax(szKey), "%i_state", item);
		itemState = ItemState:nvault_get(g_hVault, szKey);
		nvault_remove(g_hVault, szKey);
	}
	
	return true;
}

SaveItem(any:item)
{
	new itemTime = ArrayGetCell(item, _:ItemData_Time);
	if (!itemTime) {
		return;
	}
	
	new szKey[32];
	new szValue[32];
	
	new cosmetic = ArrayGetCell(item, _:ItemData_Cosmetic);
	{
		format(szKey, charsmax(szKey), "%i_name", item);
		ArrayGetString(g_cosmeticName, cosmetic, szValue, charsmax(szValue));
		
		nvault_set(g_hVault, szKey, szValue);
	}
	
	new cosmeticType = ArrayGetCell(item, _:ItemData_CosmeticType);
	{
		format(szKey, charsmax(szKey), "%i_cosmeticType", item);
		format(szValue, charsmax(szValue), "%i", cosmeticType);
		
		nvault_set(g_hVault, szKey, szValue);
	}
	
	//itemTime
	{
		format(szKey, charsmax(szKey), "%i_time", item);
		format(szValue, charsmax(szValue), "%i", itemTime);
		
		nvault_set(g_hVault, szKey, szValue);
	}
	
	new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
	{
		if (itemState == ItemState_Equip) {
			itemState = ItemState_Equiped;
		} else if (itemState == ItemState_Unequip) {
			itemState = ItemState_None;
		}
	
		format(szKey, charsmax(szKey), "%i_state", item);
		format(szValue, charsmax(szValue), "%i", itemState);
		
		nvault_set(g_hVault, szKey, szValue);
	}
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskPlayerTimer(taskID)
{
	new id = taskID - TASKID_SUM_PLAYER_TIMER;

	if (!is_user_alive(id)) {
		return;
	}

	new size = PInv_Size(id);
	for (new i = 0; i < size; ++i)
	{
		if (g_itemType != PInv_GetItemType(id, i)) {
			continue; //Invalid item type
		}	
	
		new Array:item = Array:PInv_GetItem(id, i);
		new ItemState:itemState = ArrayGetCell(item, _:ItemData_State);
		
		if (itemState == ItemState_None) {
			continue; //This item not equiped.
		}
		
		if (itemState == ItemState_Equip) {
			continue; //This item not equiped.
		}
		
		new time = ArrayGetCell(item, _:ItemData_Time) - 1;
		if (time >= 0) {
			ArraySetCell(item, _:ItemData_Time, time);
		} else {
			ArraySetCell(item, _:ItemData_State, ItemState_Unequip);
		}
	}	
}