#pragma semicolon 1

#include <amxmodx>

#include <cellarray>
#include <celltrie>

#include <nvault>

#include <api_player_inventory>

#define PLUGIN "[API] Player Inventory"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

enum _:Slot {
    Slot_Item,
    Slot_ItemType
};

new g_fwNewSlot;
new g_fwTakeSlot;
new g_fwSlotLoaded;
new g_fwSlotSaved;
new g_fwDestroy;

new g_hVault;

new Array:g_rgPlayerInventories[MAX_PLAYERS + 1] = { Invalid_Array, ... };

new Trie:g_itemTypeHandlers;
new Array:g_itemTypeNames;
new g_iItemTypesNum = 0;

new g_userAuthId[MAX_PLAYERS + 1][32];

public plugin_precache() {
    g_hVault = nvault_open("api_player_inventory");

    g_fwNewSlot = CreateMultiForward("PInv_Event_NewSlot", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwTakeSlot = CreateMultiForward("PInv_Event_TakeSlot", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwSlotLoaded = CreateMultiForward("PInv_Event_SlotLoaded", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwSlotSaved = CreateMultiForward("PInv_Event_SlotSaved", ET_IGNORE, FP_CELL, FP_CELL);
    g_fwDestroy = CreateMultiForward("PInv_Event_Destroy", ET_IGNORE);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

public plugin_end() {
    if (g_iItemTypesNum) {
        TrieDestroy(g_itemTypeHandlers);
        ArrayDestroy(g_itemTypeNames);
    }

    nvault_close(g_hVault);

    ExecuteForward(g_fwDestroy);
}

public plugin_natives() {
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

public client_connect(pPlayer) {
    if (g_rgPlayerInventories[pPlayer] != Invalid_Array) {
        ArrayDestroy(g_rgPlayerInventories[pPlayer]);
    }

    g_rgPlayerInventories[pPlayer] = ArrayCreate();
}

public client_disconnected(pPlayer) {
    SavePlayerInventory(pPlayer);
}

public client_authorized(pPlayer) {
    get_user_authid(pPlayer, g_userAuthId[pPlayer], charsmax(g_userAuthId[]));
}

public client_putinserver(pPlayer) {
    LoadPlayerInventory(pPlayer);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_RegisterItemType(iPluginId, iArgc) {
    new szTypeName[32];
    get_string(1, szTypeName, charsmax(szTypeName));

    return RegisterItemType(szTypeName);
}

public PInv_ItemType:Native_GetItemTypeHandler(iPluginId, iArgc) {
    new szTypeName[32];
    get_string(1, szTypeName, charsmax(szTypeName));

    new PInv_ItemType:iItemType;
    if (!TrieGetCell(g_itemTypeHandlers, szTypeName, iItemType)) {
        return PInv_Invalid_ItemType;
    }

    return iItemType;
}

public Native_GetItem(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgSlot = ArrayGetCell(g_rgPlayerInventories[pPlayer], iSlot);
    new iItem = ArrayGetCell(irgSlot, Slot_Item);

    return iItem;
}

public Native_GetItemType(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgSlot = ArrayGetCell(g_rgPlayerInventories[pPlayer], iSlot);
    new iItemType = ArrayGetCell(irgSlot, Slot_ItemType);

    return iItemType;
}

public Native_GiveItem(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iItem = get_param(2);
    new iItemType = get_param(3);

    return GiveItem(pPlayer, iItem, iItemType);
}

public Native_TakeItem(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    TakeItem(pPlayer, iSlot);
}

public Native_SetItem(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);
    new iItem = get_param(3);
    new iItemType = get_param(4);

    SetItem(pPlayer, iSlot, iItem, iItemType);
}

public Native_Size(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    return ArraySize(g_rgPlayerInventories[pPlayer]);
}

/*--------------------------------[ Methods ]--------------------------------*/

RegisterItemType(const szTypeName[]) {
    if (!g_iItemTypesNum) {
        g_itemTypeHandlers = TrieCreate();
        g_itemTypeNames = ArrayCreate(32);
    }

    new iItemType = g_iItemTypesNum;

    ArrayPushString(g_itemTypeNames, szTypeName);
    TrieSetCell(g_itemTypeHandlers, szTypeName, iItemType);

    g_iItemTypesNum++;

    return iItemType;
}

GetItemTypeIndex(const szTypeName[]) {
    if (!g_itemTypeHandlers) {
        return -1;
    }

    new iType = 0;
    if (!TrieGetCell(g_itemTypeHandlers, szTypeName, iType)) {
        return -1;
    }

    return iType;
}

GetItemTypeName(iItemType, szTypeName[], iLen) {
    ArrayGetString(g_itemTypeNames, iItemType, szTypeName, iLen);
}

AddSlot(Array:irgInventory) {
    new Array:irgSlot = ArrayCreate(1, Slot);
    for (new i = 0; i < Slot; ++i) {
        ArrayPushCell(irgSlot, 0);
    }

    new iId = ArraySize(irgInventory);
    ArrayPushCell(irgInventory, irgSlot);
    return iId;
}

GiveItem(pPlayer, iItem, iItemType) {
    if (iItemType == _:PInv_Invalid_ItemType) {
        return -1;
    }

    new iSlot = AddSlot(g_rgPlayerInventories[pPlayer]);
    new Array:irgSlot = ArrayGetCell(g_rgPlayerInventories[pPlayer], iSlot);
    ArraySetCell(irgSlot, Slot_Item, iItem);
    ArraySetCell(irgSlot, Slot_ItemType, iItemType);

    ExecuteForward(g_fwNewSlot, _, pPlayer, iSlot);
    return iSlot;
}

TakeItem(pPlayer, iSlot) {
    ExecuteForward(g_fwTakeSlot, _, pPlayer, iSlot);

    new Array:irgSlot = ArrayGetCell(g_rgPlayerInventories[pPlayer], iSlot);
    ArraySetCell(irgSlot, Slot_ItemType, PInv_Invalid_ItemType);
}

SetItem(pPlayer, iSlot, iItem, iItemType) {
    new Array:irgSlot = ArrayGetCell(g_rgPlayerInventories[pPlayer], iSlot);
    ArraySetCell(irgSlot, Slot_Item, iItem);
    ArraySetCell(irgSlot, Slot_ItemType, iItemType);
}
/*--------------------------------[ Vault ]--------------------------------*/

LoadPlayerInventory(pPlayer) {
    ArrayClear(g_rgPlayerInventories[pPlayer]);

    new szKey[32];

    format(szKey, charsmax(szKey), "%s_size", g_userAuthId[pPlayer]);
    new iSize = nvault_get(g_hVault, szKey);

    //Save items
    for (new i = 0; i < iSize; ++i) {        
        static szTypeName[32];
        format(szKey, charsmax(szKey), "%s_%i_itemType", g_userAuthId[pPlayer], i);
        nvault_get(g_hVault, szKey, szTypeName, charsmax(szTypeName));

        new iItemType = GetItemTypeIndex(szTypeName);

        /*if (iItemType == _:PInv_Invalid_ItemType) {
            continue;
        }*/

        format(szKey, charsmax(szKey), "%s_%i_item", g_userAuthId[pPlayer], i);
        new iItem = nvault_get(g_hVault, szKey);

        new iSlot = GiveItem(pPlayer, iItem, iItemType);
        if (iSlot == -1) {
            continue;
        }

        ExecuteForward(g_fwSlotLoaded, _, pPlayer, iSlot);
    }
}

SavePlayerInventory(pPlayer) {
    if (g_userAuthId[pPlayer][0] == '^0') {
        return;
    }

    new Array:irgInventory = g_rgPlayerInventories[pPlayer];

    new iSize = ArraySize(irgInventory);
    if (!iSize) {
        return;
    }

    new szKey[32];
    new szValue[32];

    //Save items
    new iInventorySize = 0;
    for (new i = 0; i < iSize; ++i)
    {
        new Array:irgSlot = ArrayGetCell(irgInventory, i);

        new iItemType = ArrayGetCell(irgSlot, Slot_ItemType);
        if (iItemType == _:PInv_Invalid_ItemType) {
            continue;
        }

        new iItem = ArrayGetCell(irgSlot, Slot_Item);
        {
            format(szKey, charsmax(szKey), "%s_%i_item", g_userAuthId[pPlayer], iInventorySize);
            format(szValue, charsmax(szValue), "%i", iItem);
            nvault_set(g_hVault, szKey, szValue);
        }

        //iItemType
        {
            static itemTypeName[32];
            format(szKey, charsmax(szKey), "%s_%i_itemType", g_userAuthId[pPlayer], iInventorySize);
            GetItemTypeName(iItemType, itemTypeName, charsmax(itemTypeName));
            nvault_set(g_hVault, szKey, itemTypeName);
        }

        iInventorySize++;

        ExecuteForward(g_fwSlotSaved, _, pPlayer, i);
    }

    //Save inventory size
    {
        format(szKey, charsmax(szKey), "%s_size", g_userAuthId[pPlayer]);
        format(szValue, charsmax(szValue), "%i", iInventorySize);

        nvault_set(g_hVault, szKey, szValue);
    }
}
