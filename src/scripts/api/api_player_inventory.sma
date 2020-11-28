#pragma semicolon 1

#include <amxmodx>

#include <cellarray>
#include <celltrie>

#include <nvault>

#include <api_player_inventory>

#define PLUGIN "[API] Player Inventory"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

enum _:Slot
{
    Slot_Item,
    Slot_ItemType
};

new g_fwNewSlot;
new g_fwTakeSlot;
new g_fwSlotLoaded;
new g_fwSlotSaved;
new g_fwResult;
new g_fwDestroy;

new g_hVault;

new Array:g_playerInventories[MAX_PLAYERS + 1] = { Invalid_Array, ... };

new Trie:g_itemTypeHandlers;
new Array:g_itemTypeNames;
new g_itemTypeCount = 0;

new g_userAuthID[MAX_PLAYERS + 1][32];

new g_maxPlayers;

public plugin_precache()
{
    g_hVault = nvault_open("api_player_inventory");

    g_fwNewSlot = CreateMultiForward("PInv_Event_NewSlot", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwTakeSlot = CreateMultiForward("PInv_Event_TakeSlot", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwSlotLoaded = CreateMultiForward("PInv_Event_SlotLoaded", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwSlotSaved = CreateMultiForward("PInv_Event_SlotSaved", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwDestroy = CreateMultiForward("PInv_Event_Destroy", ET_IGNORE);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_maxPlayers = get_maxplayers();
}

public plugin_end()
{
    for (new id = 1; id <= g_maxPlayers; ++id) {
        SavePlayerInventory(id);
        DestroyPlayerInventory(id);
    }

    if (g_itemTypeCount) {
        TrieDestroy(g_itemTypeHandlers);
        ArrayDestroy(g_itemTypeNames);
    }

    nvault_close(g_hVault);

    ExecuteForward(g_fwDestroy, g_fwResult);
}

public plugin_natives()
{
    register_library("api_player_inventory");

    register_native("PInv_RegisterItemType", "Native_RegisterItemType");
    register_native("PInv_GetItemTypeHandler", "Native_GetItemTypeHandler");
    register_native("PInv_GetItem", "Native_GetItem");
    register_native("PInv_GetItemType", "Native_GetItemType");
    register_native("PInv_GiveItem", "Native_GiveItem");
    register_native("PInv_TakeItem", "Native_TakeItem");
    register_native("PInv_SetItem", "Native_SetItem");
    register_native("PInv_Size", "Native_Size");
}

public client_authorized(id)
{
    static authID[32];
    get_user_authid(id, authID, charsmax(authID));
    copy(g_userAuthID[id], charsmax(g_userAuthID[]), authID);
}

public client_putinserver(id)
{
    LoadPlayerInventory(id);
}

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    SavePlayerInventory(id);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterItemType(pluginID, argc)
{
    new typeName[32];
    get_string(1, typeName, charsmax(typeName));

    return RegisterItemType(typeName);
}

public PInv_ItemType:Native_GetItemTypeHandler(pluginID, argc)
{
    new typeName[32];
    get_string(1, typeName, charsmax(typeName));

    new PInv_ItemType:itemType;
    if (!TrieGetCell(g_itemTypeHandlers, typeName, itemType)) {
        return PInv_Invalid_ItemType;
    }

    return itemType;
}

public Native_GetItem(pluginID, argc)
{
    new id = get_param(1);
    new slotIdx = get_param(2);

    new Array:inventory = g_playerInventories[id];
    new Array:slot = ArrayGetCell(inventory, slotIdx);
    new item = ArrayGetCell(slot, Slot_Item);

    return item;
}

public Native_GetItemType(pluginID, argc)
{
    new id = get_param(1);
    new slotIdx = get_param(2);

    new Array:inventory = g_playerInventories[id];
    new Array:slot = ArrayGetCell(inventory, slotIdx);
    new itemType = ArrayGetCell(slot, Slot_ItemType);

    return itemType;
}

public Native_GiveItem(pluginID, argc)
{
    new id = get_param(1);
    new item = get_param(2);
    new itemType = get_param(3);

    return GiveItem(id, item, itemType);
}

public Native_TakeItem(pluginID, argc)
{
    new id = get_param(1);
    new slotIdx = get_param(2);

    TakeItem(id, slotIdx);
}

public Native_SetItem(pluginID, argc)
{
    new id = get_param(1);
    new slotIdx = get_param(2);
    new item = get_param(3);
    new itemType = get_param(4);

    SetItem(id, slotIdx, item, itemType);
}

public Native_Size(pluginID, argc)
{
    new id = get_param(1);

    new Array:inventory = g_playerInventories[id];
    if (inventory == Invalid_Array) {
        return 0;
    }

    return ArraySize(inventory);
}

/*--------------------------------[ Methods ]--------------------------------*/

RegisterItemType(const szTypeName[])
{
    if (!g_itemTypeCount) {
        g_itemTypeHandlers = TrieCreate();
        g_itemTypeNames = ArrayCreate(32);
    }

    new itemType = g_itemTypeCount;

    ArrayPushString(g_itemTypeNames, szTypeName);
    TrieSetCell(g_itemTypeHandlers, szTypeName, itemType);

    g_itemTypeCount++;

    return itemType;
}

GetItemTypeIndex(const szTypeName[])
{
    if (!g_itemTypeHandlers) {
        return -1;
    }

    new type = 0;
    if (!TrieGetCell(g_itemTypeHandlers, szTypeName, type)) {
        return -1;
    }

    return type;
}

GetItemTypeName(itemType, szTypeName[], maxlen)
{
    ArrayGetString(g_itemTypeNames, itemType, szTypeName, maxlen);
}

Array:CreatePlayerInventory(id)
{
    new Array:inventory = ArrayCreate(1);
    g_playerInventories[id] = inventory;

    return inventory;
}

Array:DestroyPlayerInventory(id)
{
    new Array:inventory = g_playerInventories[id];
    if (inventory == Invalid_Array) {
        return;
    }

    ArrayDestroy(inventory);
}

Array:ClearPlayerInventory(id)
{
    new Array:inventory = g_playerInventories[id];
    if (inventory == Invalid_Array) {
        return;
    }

    ArrayClear(inventory);
}

AddSlot(Array:inventory)
{
    new Array:slot = ArrayCreate(1, Slot);
    for (new i = 0; i < Slot; ++i) {
        ArrayPushCell(slot, 0);
    }

    new index = ArraySize(inventory);
    ArrayPushCell(inventory, slot);
    return index;
}

GiveItem(id, item, itemType)
{
    if (itemType == _:PInv_Invalid_ItemType) {
        return -1;
    }

    new Array:inventory = g_playerInventories[id];

    if (inventory == Invalid_Array) {
        inventory = CreatePlayerInventory(id);
    }

    new slotIdx = AddSlot(inventory);

    new Array:slot = ArrayGetCell(inventory, slotIdx);
    ArraySetCell(slot, Slot_Item, item);
    ArraySetCell(slot, Slot_ItemType, itemType);

    ExecuteForward(g_fwNewSlot, g_fwResult, id, slotIdx);
    return slotIdx;
}

TakeItem(id, slotIdx)
{
    ExecuteForward(g_fwTakeSlot, g_fwResult, id, slotIdx);

    new Array:inventory = g_playerInventories[id];
    new Array:slot = ArrayGetCell(inventory, slotIdx);
    ArraySetCell(slot, Slot_ItemType, PInv_Invalid_ItemType);
}

SetItem(id, slotIdx, item, itemType)
{
    new Array:inventory = g_playerInventories[id];
    new Array:slot = ArrayGetCell(inventory, slotIdx);

    ArraySetCell(slot, Slot_Item, item);
    ArraySetCell(slot, Slot_ItemType, itemType);
}
/*--------------------------------[ Vault ]--------------------------------*/

LoadPlayerInventory(id)
{
    ClearPlayerInventory(id);

    new key[32];

    new size;
    {
        format(key, charsmax(key), "%s_size", g_userAuthID[id]);
        size = nvault_get(g_hVault, key);
    }

    //Save items
    for (new i = 0; i < size; ++i)
    {
        static typeName[32];
        new itemType;
        {
            format(key, charsmax(key), "%s_%i_itemType", g_userAuthID[id], i);
            nvault_get(g_hVault, key, typeName, charsmax(typeName));
            itemType = GetItemTypeIndex(typeName);
        }

        /*if (itemType == _:PInv_Invalid_ItemType) {
            continue;
        }*/

        new item;
        {
            format(key, charsmax(key), "%s_%i_item", g_userAuthID[id], i);
            item = nvault_get(g_hVault, key);
        }

        new slotIdx = GiveItem(id, item, itemType);
        ExecuteForward(g_fwSlotLoaded, g_fwResult, id, slotIdx);
    }
}

SavePlayerInventory(id)
{
    if (g_userAuthID[id][0] == '^0') {
        return;
    }

    new Array:inventory = g_playerInventories[id];
    if (inventory == Invalid_Array) {
        return;
    }

    new size = ArraySize(inventory);
    if (!size) {
        return;
    }

    new key[32];
    new value[32];

    //Save items
    new inventorySize = 0;
    for (new i = 0; i < size; ++i)
    {
        new Array:slot = ArrayGetCell(inventory, i);

        new itemType = ArrayGetCell(slot, Slot_ItemType);
        if (itemType == _:PInv_Invalid_ItemType) {
            continue;
        }

        new item = ArrayGetCell(slot, Slot_Item);
        {
            format(key, charsmax(key), "%s_%i_item", g_userAuthID[id], inventorySize);
            format(value, charsmax(value), "%i", item);
            nvault_set(g_hVault, key, value);
        }

        //itemType
        {
            static itemTypeName[32];
            format(key, charsmax(key), "%s_%i_itemType", g_userAuthID[id], inventorySize);
            GetItemTypeName(itemType, itemTypeName, charsmax(itemTypeName));
            nvault_set(g_hVault, key, itemTypeName);
        }

        inventorySize++;

        ExecuteForward(g_fwSlotSaved, g_fwResult, id, i);
    }

    //Save inventory size
    {
        format(key, charsmax(key), "%s_size", g_userAuthID[id]);
        format(value, charsmax(value), "%i", inventorySize);

        nvault_set(g_hVault, key, value);
    }
}