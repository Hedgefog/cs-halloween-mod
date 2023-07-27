#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <nvault>

#include <api_player_inventory>
#include <api_player_cosmetic>

#define PLUGIN "[Player Inventory Item] Cosmetic"
#define VERSION "1.1.0"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_PLAYER_TIMER 1000

#define ITEM_TYPE "cosmetic"
#define UNUSUAL_ENTITY_RENDER_AMT 1.0

enum ItemState {
    ItemState_None = 0,
    ItemState_Equiped,
    ItemState_Equip,
    ItemState_Unequip
};

enum ItemData {
    ItemData_Cosmetic = 0,
    PCosmetic_Type:ItemData_CosmeticType,
    ItemData_Time,
    ItemState:ItemData_State,
    ItemData_Entity
};

new Trie:g_itCosmetic;
new Array:g_irgCosmeticName;
new Array:g_irgCosmeticGroups;
new Array:g_irgCosmeticModelIndex;
new Array:g_irgCosmeticUnusualColor;
new g_iCosmeticsNum = 0;

new g_rgPlayerRenderMode[MAX_PLAYERS + 1];
new Float:g_rgPlayerRenderAmt[MAX_PLAYERS + 1];

new g_irgCosmeticClassName;

new PInv_ItemType:g_iItemType;
new g_hVault;

new g_fwEquipmentChanged;

public plugin_precache() {
    g_irgCosmeticClassName = engfunc(EngFunc_AllocString, "info_target");

    g_hVault = nvault_open("api_player_cosmetic");
    g_iItemType = PInv_RegisterItemType(ITEM_TYPE);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);

    g_fwEquipmentChanged = CreateMultiForward("PCosmetic_Fw_EquipmentChanged", ET_IGNORE, FP_CELL);
}

public plugin_natives() {
    register_library("api_player_cosmetic");
    register_native("PCosmetic_Register", "Native_Register");
    register_native("PCosmetic_Give", "Native_Give");

    register_native("PCosmetic_Equip", "Native_Equip");
    register_native("PCosmetic_Unequip", "Native_Unequip");
    register_native("PCosmetic_IsItemEquiped", "Native_IsItemEquiped");
    register_native("PCosmetic_UpdateEquipment", "Native_UpdateEquipment");
    register_native("PCosmetic_CanBeEquiped", "Native_CanBeEquiped");

    register_native("PCosmetic_GetItemCosmetic", "Native_GetItemCosmetic");
    register_native("PCosmetic_GetItemCosmeticType", "Native_GetItemCosmeticType");
    register_native("PCosmetic_GetItemTime", "Native_GetItemTime");

    register_native("PCosmetic_GetCosmeticName", "Native_GetCosmeticName");
    register_native("PCosmetic_GetCosmeticGroups", "Native_GetCosmeticGroups");
}

public client_disconnected(pPlayer) {
    new iSize = PInv_Size(pPlayer);
    for (new i = 0; i < iSize; ++i)
    {
        new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, i);
        if (iItemType != g_iItemType) {
            continue;
        }

        Unequip(pPlayer, i, .bChangeState = false);
    }

    ClearPlayerTasks(pPlayer);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    UpdateEquipment(pPlayer);
}

public HamHook_Player_Killed_Post(pPlayer) {
    ClearPlayerTasks(pPlayer);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new PCosmetic_Groups:iGroups = PCosmetic_Groups:get_param(2);
    new iModelIndex = get_param(3);

    new Float:rgflColor[3];
    get_array_f(4, rgflColor, 3);

    return Register(szName, iGroups, iModelIndex, rgflColor);
}

public Native_Give(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iCosmetic = get_param(2);
    new PCosmetic_Type:iCosmeticType = PCosmetic_Type:get_param(3);
    new iTime = get_param(4);

    return Give(pPlayer, iCosmetic, iCosmeticType, iTime);
}

public Native_GetCosmeticName(iPluginId, iArgc) {
    new iCosmetic = get_param(1);
    new iLen = get_param(3);

    static szName[32];
    ArrayGetString(g_irgCosmeticName, iCosmetic, szName, charsmax(szName));
    set_string(2, szName, iLen);
}

public Native_GetCosmeticGroups(iPluginId, iArgc) {
    new iCosmetic = get_param(1);

    return ArrayGetCell(g_irgCosmeticGroups, iCosmetic);
}

public Native_Equip(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);
    new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);

    if (iItemState == ItemState_None) {
        iItemState = ItemState_Equip;
    } else if (iItemState == ItemState_Unequip) {
        iItemState = ItemState_Equiped;
    }

    ArraySetCell(irgItem, _:ItemData_State, iItemState);
    ExecuteForward(g_fwEquipmentChanged, _, pPlayer);
}

public Native_Unequip(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);
    new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);

    if (iItemState == ItemState_Equiped) {
        iItemState = ItemState_Unequip;
    } else if (iItemState == ItemState_Equip) {
        iItemState = ItemState_None;
    }

    ArraySetCell(irgItem, _:ItemData_State, iItemState);
    ExecuteForward(g_fwEquipmentChanged, _, pPlayer);
}

public Native_IsItemEquiped(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);
    new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);

    return (iItemState == ItemState_Equiped || iItemState == ItemState_Equip);
}

public Native_UpdateEquipment(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    UpdateEquipment(pPlayer);
}

public Native_CanBeEquiped(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iCosmetic = get_param(2);
    new iIgnoreSlot = get_param(3);

    return CanBeEquiped(pPlayer, iCosmetic, iIgnoreSlot);
}

public Native_GetItemCosmetic(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);
    return ArrayGetCell(irgItem, _:ItemData_Cosmetic);
}

public Native_GetItemCosmeticType(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);
    return ArrayGetCell(irgItem, _:ItemData_CosmeticType);
}

public Native_GetItemTime(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSlot = get_param(2);

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);
    return ArrayGetCell(irgItem, _:ItemData_Time);
}

/*--------------------------------[ Events ]--------------------------------*/

public PInv_Event_SlotLoaded(pPlayer, iSlot) {
    new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);
    if (PInv_ItemType:iItemType != g_iItemType) {
        return; //Invalid irgItem iType
    }

    new irgItem = PInv_GetItem(pPlayer, iSlot);
    if (irgItem == _:Invalid_Array) {
        return; //Handler is invalid
    }

    new iCosmetic;
    new PCosmetic_Type:iCosmeticType;
    new iItemTime;
    new ItemState:iItemState;

    if (!LoadItem(irgItem, iCosmetic, iCosmeticType, iItemTime, iItemState)) {
        PInv_SetItem(pPlayer, iSlot, Invalid_Array, PInv_Invalid_ItemType);
        PInv_TakeItem(pPlayer, iSlot);
        return; //Invalid iCosmetic
    }

    irgItem = _:CreateCosmetic(iCosmetic, iCosmeticType, iItemTime);

    if (iItemState == ItemState_Equiped) {
        iItemState = ItemState_Equip;
    } else if (iItemState == ItemState_Unequip) {
        iItemState = ItemState_None;
    }

    PInv_SetItem(pPlayer, iSlot, irgItem, g_iItemType);
    ArraySetCell(Array:irgItem, _:ItemData_State, iItemState); //Change state of irgItem
}

public PInv_Event_SlotSaved(pPlayer, iSlot) {
    new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);
    if (iItemType != g_iItemType) {
        return; //Invalid irgItem iType
    }

    new irgItem = PInv_GetItem(pPlayer, iSlot);
    if (irgItem == _:Invalid_Array) {
        return; //Handler is invalid
    }

    SaveItem(irgItem); //Save data about handler
}

public PInv_Event_TakeSlot(pPlayer, iSlot) {
    new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);
    if (iItemType != g_iItemType) {
        return; //Invalid irgItem iType
    }

    new Array:irgItem = PInv_GetItem(pPlayer, iSlot);
    if (irgItem == Invalid_Array) {
        return; //Handler is invalid
    }

    ArrayDestroy(irgItem);
}

public PInv_Event_Destroy() {
    TrieDestroy(g_itCosmetic);

    if (g_iCosmeticsNum)  {
        ArrayDestroy(g_irgCosmeticName);
        ArrayDestroy(g_irgCosmeticGroups);
        ArrayDestroy(g_irgCosmeticModelIndex);
        ArrayDestroy(g_irgCosmeticUnusualColor);
    }

    nvault_close(g_hVault);
}

/*--------------------------------[ Methods ]--------------------------------*/

Array:CreateCosmetic(iCosmetic, PCosmetic_Type:iCosmeticType, iTime) {
    new Array:irgItem = ArrayCreate(1, _:ItemData);
    for (new i = 0; i < _:ItemData; ++i) {
        ArrayPushCell(irgItem, 0);
    }

    ArraySetCell(irgItem, _:ItemData_Cosmetic, iCosmetic);
    ArraySetCell(irgItem, _:ItemData_CosmeticType, iCosmeticType);
    ArraySetCell(irgItem, _:ItemData_Time, iTime);
    ArraySetCell(irgItem, _:ItemData_State, ItemState_None);

    return irgItem;
}

Register(const szName[], PCosmetic_Groups:iGroups, iModelIndex, const Float:unusualColor[3]) {
    if (!g_iCosmeticsNum) {
        g_irgCosmeticName = ArrayCreate(32);
        g_irgCosmeticGroups = ArrayCreate();
        g_irgCosmeticModelIndex = ArrayCreate();
        g_irgCosmeticUnusualColor = ArrayCreate(3);
        g_itCosmetic = TrieCreate();
    }

    ArrayPushString(g_irgCosmeticName, szName);
    ArrayPushCell(g_irgCosmeticGroups, iGroups);
    ArrayPushCell(g_irgCosmeticModelIndex, iModelIndex);
    ArrayPushArray(g_irgCosmeticUnusualColor, unusualColor);

    new iCosmetic = g_iCosmeticsNum;
    TrieSetCell(g_itCosmetic, szName, iCosmetic);

    g_iCosmeticsNum++;

    return iCosmetic;
}

Give(pPlayer, iCosmetic, PCosmetic_Type:iCosmeticType, iTime) {
    new iSlot = -1;
    new Array:irgItem = Invalid_Array;

    new iSize = PInv_Size(pPlayer);
    for (new i = 0; i < iSize; ++i)
    {
        if (g_iItemType != PInv_GetItemType(pPlayer, i)) {
            continue;
        }

        irgItem = Array:PInv_GetItem(pPlayer, i);
        new itemCosmetic = ArrayGetCell(irgItem, _:ItemData_Cosmetic);
        new PCosmetic_Type:itemCosmeticType = ArrayGetCell(irgItem, _:ItemData_CosmeticType);

        if (iCosmetic == itemCosmetic && iCosmeticType == itemCosmeticType) {
            iSlot = i;
            break;
        }
    }

    if (iSlot == -1) {
        irgItem = CreateCosmetic(iCosmetic, iCosmeticType, iTime);
        iSlot = PInv_GiveItem(pPlayer, irgItem, g_iItemType);
    }

    return iSlot;
}

Equip(pPlayer, iSlot) {
    new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);
    if (iItemType != g_iItemType) {
        return; //Is not a iCosmetic
    }

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);

    new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);

    if (iItemState == ItemState_Equiped) {
        return; //Already equiped
    }

    new iCosmetic = ArrayGetCell(irgItem, _:ItemData_Cosmetic);
    if (!CanBeEquiped(pPlayer, iCosmetic, iSlot)) {
        return; //Can't be equiped
    }

    new PCosmetic_Type:iCosmeticType = ArrayGetCell(irgItem, _:ItemData_CosmeticType);

    new pEntity = CreateCosmeticEntity(pPlayer, iCosmetic, iCosmeticType);
    ArraySetCell(irgItem, _:ItemData_Entity, pEntity);
    ArraySetCell(irgItem, _:ItemData_State, ItemState_Equiped);

    ExecuteForward(g_fwEquipmentChanged, _, pPlayer);
}

Unequip(pPlayer, iSlot, bool:bChangeState = true) {
    new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);
    if (iItemType != g_iItemType) {
        return; //Is not a iCosmetic
    }

    new Array:irgItem = Array:PInv_GetItem(pPlayer, iSlot);
    new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);

    if (iItemState == ItemState_None) {
        return; //Not equiped
    }

    new pEntity = ArrayGetCell(irgItem, _:ItemData_Entity);
    if (pev_valid(pEntity)) {
        set_pev(pEntity, pev_movetype, MOVETYPE_NONE);
        set_pev(pEntity, pev_aiment, 0);
        engfunc(EngFunc_RemoveEntity, pEntity);
    }

    ArraySetCell(irgItem, _:ItemData_Entity, 0);

    if (bChangeState) {
        ArraySetCell(irgItem, _:ItemData_State, ItemState_None);
    }

    new iItemTime = ArrayGetCell(irgItem, _:ItemData_Time);
    if (iItemTime <= 0) {
        PInv_TakeItem(pPlayer, iSlot);
    }
    
    ExecuteForward(g_fwEquipmentChanged, _, pPlayer);
}

bool:CanBeEquiped(pPlayer, iCosmetic, iIgnoreSlot = -1) {
    new iCosmeticGroups = ArrayGetCell(g_irgCosmeticGroups, iCosmetic);

    new iSize = PInv_Size(pPlayer);
    for (new i = 0; i < iSize; ++i)
    {
        if (i == iIgnoreSlot) {
            continue;
        }

        new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, i);
        if (iItemType != g_iItemType) {
            continue;
        }

        new Array:irgItem = Array:PInv_GetItem(pPlayer, i);

        new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);
        if (iItemState != ItemState_Equiped && iItemState != ItemState_Equip) {
            continue; //This irgItem not equiped.
        }

        new itemCosmetic = ArrayGetCell(irgItem, _:ItemData_Cosmetic);
        if (iCosmetic == itemCosmetic) {
            return false; //This irgItem is already equiped
        }

        new itemCosmeticGroups = ArrayGetCell(g_irgCosmeticGroups, itemCosmetic);
        if (iCosmeticGroups & itemCosmeticGroups) {
            return false; //Item with some iGroups already equiped
        }
    }

    return true;
}

CreateCosmeticEntity(pOwner, iCosmetic, PCosmetic_Type:iType = PCosmetic_Type_Normal) {
    new pEntity = engfunc(EngFunc_CreateNamedEntity, g_irgCosmeticClassName);
    set_pev(pEntity, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(pEntity, pev_aiment, pOwner);

    if (iType == PCosmetic_Type_Unusual) {
        static Float:rgflColor[3];
        ArrayGetArray(g_irgCosmeticUnusualColor, iCosmetic, rgflColor);

        set_pev(pEntity, pev_renderfx, kRenderFxGlowShell);
        set_pev(pEntity, pev_rendercolor, rgflColor);
        set_pev(pEntity, pev_renderamt, UNUSUAL_ENTITY_RENDER_AMT);
    }

    new iModelIndex = ArrayGetCell(g_irgCosmeticModelIndex, iCosmetic);
    set_pev(pEntity, pev_modelindex, iModelIndex);

    return pEntity;
}

UpdateEquipment(pPlayer) {
    if (!g_iCosmeticsNum) {
        return;
    }

    new iSize = PInv_Size(pPlayer);
    for (new i = 0; i < iSize; ++i)
    {
        new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, i);
        if (iItemType != g_iItemType) {
            continue; //Invalid irgItem iType
        }

        new Array:irgItem = Array:PInv_GetItem(pPlayer, i);
        new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);

        if (iItemState == ItemState_Equip) {
            Equip(pPlayer, i);
        } else if (iItemState == ItemState_Unequip) {
            Unequip(pPlayer, i);
        }
    }

    SetupPlayerTasks(pPlayer);
}

SetupPlayerTasks(pPlayer) {
    if (!task_exists(pPlayer)) {
        set_task(0.1, "Task_PlayerThink", pPlayer, _, _, "b");
    }

    if (!task_exists(pPlayer+TASKID_SUM_PLAYER_TIMER)) {
        set_task(1.0, "Task_PlayerTimer", pPlayer+TASKID_SUM_PLAYER_TIMER, _, _, "b");
    }
}

ClearPlayerTasks(pPlayer) {
    remove_task(pPlayer);
    remove_task(pPlayer+TASKID_SUM_PLAYER_TIMER);
}

/*--------------------------------[ Vault ]--------------------------------*/

bool:LoadItem(any:irgItem, &iCosmetic, &PCosmetic_Type:iCosmeticType, &iItemTime, &ItemState:iItemState) {
    if (!g_iCosmeticsNum) {
        return false;
    }

    new szKey[32];
    new szValue[32];

    //iCosmetic;
    {
        format(szKey, charsmax(szKey), "%i_name", irgItem);
        nvault_get(g_hVault, szKey, szValue, charsmax(szValue));
        nvault_remove(g_hVault, szKey);

        if (equal(szValue, NULL_STRING)) {
            return false;
        }

        if (!TrieKeyExists(g_itCosmetic, szValue)) {
            return false;
        }

        //Get index by name
        if (!TrieGetCell(g_itCosmetic, szValue, iCosmetic)) {
            return false;
        }
    }

    //iCosmeticType;
    {
        format(szKey, charsmax(szKey), "%i_cosmeticType", irgItem);
        iCosmeticType = PCosmetic_Type:nvault_get(g_hVault, szKey);
        nvault_remove(g_hVault, szKey);
    }

    //iItemTime;
    {
        format(szKey, charsmax(szKey), "%i_time", irgItem);
        iItemTime = nvault_get(g_hVault, szKey);
        nvault_remove(g_hVault, szKey);
    }

    //ItemState:iItemState;
    {
        format(szKey, charsmax(szKey), "%i_state", irgItem);
        iItemState = ItemState:nvault_get(g_hVault, szKey);
        nvault_remove(g_hVault, szKey);
    }

    return true;
}

SaveItem(any:irgItem) {
    new iItemTime = ArrayGetCell(irgItem, _:ItemData_Time);
    if (iItemTime <= 0) {
        return;
    }

    new szKey[32];
    new szValue[32];

    new iCosmetic = ArrayGetCell(irgItem, _:ItemData_Cosmetic);
    {
        format(szKey, charsmax(szKey), "%i_name", irgItem);
        ArrayGetString(g_irgCosmeticName, iCosmetic, szValue, charsmax(szValue));

        nvault_set(g_hVault, szKey, szValue);
    }

    new iCosmeticType = ArrayGetCell(irgItem, _:ItemData_CosmeticType);
    {
        format(szKey, charsmax(szKey), "%i_cosmeticType", irgItem);
        format(szValue, charsmax(szValue), "%i", iCosmeticType);

        nvault_set(g_hVault, szKey, szValue);
    }

    //iItemTime
    {
        format(szKey, charsmax(szKey), "%i_time", irgItem);
        format(szValue, charsmax(szValue), "%i", iItemTime);

        nvault_set(g_hVault, szKey, szValue);
    }

    new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);
    {
        format(szKey, charsmax(szKey), "%i_state", irgItem);
        format(szValue, charsmax(szValue), "%i", iItemState);

        nvault_set(g_hVault, szKey, szValue);
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_PlayerTimer(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_PLAYER_TIMER;

    if (!is_user_alive(pPlayer)) {
        return;
    }

    new iSize = PInv_Size(pPlayer);
    for (new i = 0; i < iSize; ++i)
    {
        if (g_iItemType != PInv_GetItemType(pPlayer, i)) {
            continue; //Invalid irgItem iType
        }

        new Array:irgItem = Array:PInv_GetItem(pPlayer, i);
        new ItemState:iItemState = ArrayGetCell(irgItem, _:ItemData_State);

        if (iItemState == ItemState_None) {
            continue; //This irgItem not equiped.
        }

        if (iItemState == ItemState_Equip) {
            continue; //This irgItem not equiped.
        }

        new iTime = ArrayGetCell(irgItem, _:ItemData_Time) - 1;
        if (iTime >= 0) {
            ArraySetCell(irgItem, _:ItemData_Time, iTime);
        } else {
            ArraySetCell(irgItem, _:ItemData_State, ItemState_Unequip);
        }
    }
}

public Task_PlayerThink(pPlayer) {
    new iRenderMode = pev(pPlayer, pev_rendermode);

    static Float:flRenderAmt;
    pev(pPlayer, pev_renderamt, flRenderAmt);

    if (iRenderMode != g_rgPlayerRenderMode[pPlayer]
        || flRenderAmt != g_rgPlayerRenderAmt[pPlayer])
    {
        g_rgPlayerRenderMode[pPlayer] = iRenderMode;
        g_rgPlayerRenderAmt[pPlayer] = flRenderAmt;

        new iSize = PInv_Size(pPlayer);
        for (new i = 0; i < iSize; ++i)
        {
            if (g_iItemType != PInv_GetItemType(pPlayer, i)) {
                continue;
            }

            new Array:irgItem = Array:PInv_GetItem(pPlayer, i);

            if (ArrayGetCell(irgItem, _:ItemData_State) != ItemState_Equiped
                && ArrayGetCell(irgItem, _:ItemData_State) != ItemState_Unequip) {
                continue;
            }

            new pEntity = ArrayGetCell(irgItem, _:ItemData_Entity);
            if (!pEntity) {
                continue;
            }

            set_pev(pEntity, pev_rendermode, iRenderMode);

            if (ArrayGetCell(irgItem, _:ItemData_CosmeticType) == PCosmetic_Type_Normal) {
                set_pev(pEntity, pev_renderamt, flRenderAmt);
            } else {
                set_pev(pEntity, pev_renderamt, UNUSUAL_ENTITY_RENDER_AMT);
            }
        }
    }
}