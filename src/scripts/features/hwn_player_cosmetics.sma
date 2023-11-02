#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <json>

#include <cellstruct>

#include <api_player_inventory>
#include <api_player_camera>
#include <api_player_cosmetics>

#include <hwn>
#include <hwn_player_cosmetics>

#define PLUGIN "[Hwn] Cosmetics"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define INVENTORY_ITEM_TYPE "hwn_cosmetic"

#define COSMETICS_DOCUMENT_VERSION 2

#define UNUSUAL_ENTITY_RENDER_AMT 1.0

#define PREVIEW_CAMERA_ANGLES Float:{15.0, 180.0, 0.0}
#define PREVIEW_CAMERA_DISTANCE 96.0
#define PREVIEW_CAMERA_LIGHT_RADIUS 4
#define PREVIEW_CAMERA_LIGHT_BRIGHTNESS 1.0
#define PREVIEW_CAMERA_LIGHT_LIFETIME 5
#define PREVIEW_CAMERA_LIGHT_DECAYRATE 1

enum ItemState {
    ItemState_None,
    ItemState_Equiped,
    ItemState_Equip,
    ItemState_Unequip
};

enum SlotItem {
    SlotItem_Id[32],
    Hwn_PlayerCosmetic_Type:SlotItem_CosmeticType,
    Float:SlotItem_Time,
    Float:SlotItem_LastThink,
    ItemState:SlotItem_State
};

enum CosmeticData {
    Array:CosmeticData_Name,
    Array:CosmeticData_Groups,
    Array:CosmeticData_ModelIndex,
    Array:CosmeticData_Body,
    Array:CosmeticData_Skin,
    Array:CosmeticData_EffectColor
};

new g_pCvarPreview;
new g_pCvarPreviewLight;

new g_fwEquipmentChanged;

new g_szCosmeticsDir[MAX_RESOURCE_PATH_LENGTH];

new Trie:g_itCosmetic;
new g_rgiCosmeticData[CosmeticData];
new g_iCosmeticsNum = 0;

new Float:g_rgflPlayerNextSlotsUpdate[MAX_PLAYERS + 1];
new Array:g_rgirgPlayerMenuSlotRefs[MAX_PLAYERS + 1] = { Invalid_Array, ... };
new bool:g_rbPlayerInPreview[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextHighlight[MAX_PLAYERS + 1];
new g_rgiPlayerEquipedGroups[MAX_PLAYERS + 1];

public plugin_precache() {
    get_configsdir(g_szCosmeticsDir, charsmax(g_szCosmeticsDir));
    format(g_szCosmeticsDir, charsmax(g_szCosmeticsDir), "%s/hwn/cosmetics", g_szCosmeticsDir);

    LoadCosmetics();
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);
    RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink_Post", .Post = 1);

    RegisterHam(Ham_Think, "info_target", "HamHook_Target_Think_Post", .Post = 1);

    g_fwEquipmentChanged = CreateMultiForward("Hwn_Player_Fw_CosmeticsChanged", ET_IGNORE, FP_CELL);

    g_pCvarPreview = register_cvar("hwn_pcosmetic_menu_preview", "1");
    g_pCvarPreviewLight = register_cvar("hwn_pcosmetic_menu_preview_light", "1");

    register_clcmd("hwn_cosmetics", "Command_OpenMenu");
}

public plugin_natives() {
    register_library("hwn_player_cosmetics");
    register_native("Hwn_PlayerCosmetic_Register", "Native_Register");
    register_native("Hwn_PlayerCosmetic_GetCount", "Native_GetCount");
    register_native("Hwn_PlayerCosmetic_GetIdByIndex", "Native_GetIdByIndex");
    register_native("Hwn_Player_GiveCosmetic", "Native_Give");
    register_native("Hwn_Player_UpdateCosmetics", "Native_UpdateEquipment");
    register_native("Hwn_Player_Cosmetic_OpenPlayerMenu", "Native_OpenPlayerMenu");
}

public plugin_end() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (g_rgirgPlayerMenuSlotRefs[pPlayer] != Invalid_Array) {
            ArrayDestroy(g_rgirgPlayerMenuSlotRefs[pPlayer]);
        }
    }

    TrieDestroy(g_itCosmetic);

    if (g_iCosmeticsNum)  {
        ArrayDestroy(g_rgiCosmeticData[CosmeticData_Name]);
        ArrayDestroy(g_rgiCosmeticData[CosmeticData_Groups]);
        ArrayDestroy(g_rgiCosmeticData[CosmeticData_ModelIndex]);
        ArrayDestroy(g_rgiCosmeticData[CosmeticData_Body]);
        ArrayDestroy(g_rgiCosmeticData[CosmeticData_Skin]);
        ArrayDestroy(g_rgiCosmeticData[CosmeticData_EffectColor]);
    }
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Register(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new Hwn_PlayerCosmetic_Group:iGroups = Hwn_PlayerCosmetic_Group:get_param(2);
    new iModelIndex = get_param(3);

    new rgiEffectColor[3];
    get_array(4, rgiEffectColor, 3);

    return Register(szName, iGroups, iModelIndex, 0, 0, rgiEffectColor);
}

public Native_GetCount(iPluginId, iArgc) {
    return g_iCosmeticsNum;
}

public Native_GetIdByIndex(iPluginId, iArgc) {
    new iId = get_param(1);

    if (!g_iCosmeticsNum) {
        set_string(2, "", get_param(3));
        return;
    }

    static szId[32]; ArrayGetString(g_rgiCosmeticData[CosmeticData_Name], iId, szId, charsmax(szId));

    set_string(2, szId, get_param(3));
}

public Native_Give(iPluginId, iArgc) {
    if (!g_iCosmeticsNum) return -1;

    new pPlayer = get_param(1);

    static szCosmetic[32];
    get_string(2, szCosmetic, charsmax(szCosmetic));

    new Hwn_PlayerCosmetic_Type:iCosmeticType = Hwn_PlayerCosmetic_Type:get_param(3);
    new Float:flTime = get_param_f(4);

    return @Player_GiveCosmetic(pPlayer, szCosmetic, iCosmeticType, flTime);
}

public Native_UpdateEquipment(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    @Player_UpdateEquipment(pPlayer);
}

public Native_OpenPlayerMenu(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    @Player_OpenCosmeticMenu(pPlayer, 0);
}


public Command_OpenMenu(pPlayer) {
    @Player_OpenCosmeticMenu(pPlayer, 0);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_connect(pPlayer) {
    g_rgflPlayerNextSlotsUpdate[pPlayer] = get_gametime();
}

public client_disconnected(pPlayer) {
    new iSize = PlayerInventory_Size(pPlayer);
    for (new iSlot = 0; iSlot < iSize; ++iSlot) {
        if (!PlayerInventory_CheckItemType(pPlayer, iSlot, INVENTORY_ITEM_TYPE)) continue;

        @Player_UnequipInventorySlot(pPlayer, iSlot, .bChangeState = false);
    }

    @Player_DeactivatePreview(pPlayer);
}

public PlayerInventory_Fw_SlotLoaded(pPlayer, iSlot) {
    if (!PlayerInventory_CheckItemType(pPlayer, iSlot, INVENTORY_ITEM_TYPE)) return;

    new Struct:sItem = PlayerInventory_GetItem(pPlayer, iSlot);

    if (sItem == Invalid_Struct) {
        PlayerInventory_TakeItem(pPlayer, iSlot);
        return;
    }

    new ItemState:iItemState = @SlotItem_GetState(sItem);

    if (iItemState == ItemState_Equiped) {
        iItemState = ItemState_Equip;
    } else if (iItemState == ItemState_Unequip) {
        iItemState = ItemState_None;
    }

    @SlotItem_SetState(sItem, iItemState);
}

public PlayerInventory_Fw_SlotRemoved(pPlayer, iSlot) {
    if (!PlayerInventory_CheckItemType(pPlayer, iSlot, INVENTORY_ITEM_TYPE)) return;

    new Struct:sItem = PlayerInventory_GetItem(pPlayer, iSlot);
    if (sItem == Invalid_Struct) return;

    @Player_UnequipInventorySlot(pPlayer, iSlot, true);

    @SlotItem_Destroy(sItem);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_AddToFullPack_Post(es, e, pEntity, pHost, iHostFlags, iPlayer, pSet) {
    if (g_rbPlayerInPreview[pHost]) {
        if (pEntity == pHost) {
            set_es(es, ES_Sequence, 64);
            set_es(es, ES_GaitSequence, 1);
            set_es(es, ES_MoveType, MOVETYPE_NONE); // disable blending
            set_es(es, ES_RenderFx, kRenderFxNone);
            set_es(es, ES_RenderAmt, 255.0);
        }

        if (pEntity == pHost || (pev_valid(pEntity) && pev(pEntity, pev_aiment) == pHost)) {
            set_es(es, ES_RenderMode, kRenderNormal);
        }

        return FMRES_HANDLED;
    }

    return FMRES_IGNORED;
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (is_user_alive(pPlayer)) {
        @Player_UpdateEquipment(pPlayer);
    }

    @Player_DeactivatePreview(pPlayer);
}

public HamHook_Player_Killed(pPlayer) {
    @Player_DeactivatePreview(pPlayer);
}

public HamHook_Player_PreThink_Post(pPlayer) {
    if (g_rgflPlayerNextHighlight[pPlayer] && g_rgflPlayerNextHighlight[pPlayer] <= get_gametime()) {
      static Float:vecOrigin[3];
      pev(pPlayer, pev_origin, vecOrigin);

      new iBrightness = floatround(255 * PREVIEW_CAMERA_LIGHT_BRIGHTNESS);

      engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vecOrigin, pPlayer);
      write_byte(TE_DLIGHT);
      engfunc(EngFunc_WriteCoord, vecOrigin[0]);
      engfunc(EngFunc_WriteCoord, vecOrigin[1]);
      engfunc(EngFunc_WriteCoord, vecOrigin[2]);
      write_byte(PREVIEW_CAMERA_LIGHT_RADIUS);
      write_byte(iBrightness);
      write_byte(iBrightness);
      write_byte(iBrightness);
      write_byte(PREVIEW_CAMERA_LIGHT_LIFETIME);
      write_byte(PREVIEW_CAMERA_LIGHT_DECAYRATE);
      message_end();

      g_rgflPlayerNextHighlight[pPlayer] = get_gametime() + (PREVIEW_CAMERA_LIGHT_DECAYRATE * 0.1);
    }
}

public HamHook_Player_PostThink_Post(pPlayer) {
    new Float:flGameTime = get_gametime();

    if (is_user_alive(pPlayer)) {
        if (g_rgflPlayerNextSlotsUpdate[pPlayer] <= flGameTime) {
            new iSize = PlayerInventory_Size(pPlayer);
            for (new iSlot = 0; iSlot < iSize; ++iSlot) {
                if (!PlayerInventory_CheckItemType(pPlayer, iSlot, INVENTORY_ITEM_TYPE)) continue;

                static Struct:sItem; sItem = PlayerInventory_GetItem(pPlayer, iSlot);
                @SlotItem_Think(sItem);
            }

            g_rgflPlayerNextSlotsUpdate[pPlayer] = flGameTime + 1.0;
        }
    }
}

public HamHook_Target_Think_Post(pEntity) {
    static szClassName[32]; pev(pEntity, pev_classname, szClassName, charsmax(szClassName));
    if (equal(szClassName, "_cosmetic")) {
        @PlayerCosmetic_Think(pEntity);
    }
}

/*--------------------------------[ Slot Item Methods ]--------------------------------*/

Struct:@SlotItem_Create(const szCosmetic[], Hwn_PlayerCosmetic_Type:iCosmeticType, Float:flTime) {
    new Struct:this = StructCreate(SlotItem);

    StructSetString(this, SlotItem_Id, szCosmetic);
    StructSetCell(this, SlotItem_CosmeticType, iCosmeticType);
    StructSetCell(this, SlotItem_Time, flTime);
    StructSetCell(this, SlotItem_LastThink, 0.0);
    StructSetCell(this, SlotItem_State, ItemState_None);

    return this;
}

@SlotItem_Destroy(&Struct:this) {
    StructDestroy(this);
}

@SlotItem_Think(const &Struct:this) {
    if (@SlotItem_IsEquiped(this)) {
        new Float:flGameTime = get_gametime();
        new Float:flTime = StructGetCell(this, SlotItem_Time);
        new Float:flLastThink = StructGetCell(this, SlotItem_LastThink);

        flTime = floatmax(flTime - (flGameTime - flLastThink), 0.0);

        StructSetCell(this, SlotItem_Time, flTime);
        StructSetCell(this, SlotItem_LastThink, flGameTime);

        if (flTime <= 0) {
            @SlotItem_SetState(this, ItemState_Unequip);
        }
    }
}

bool:@SlotItem_IsEquiped(const &Struct:this) {
    static ItemState:iItemState; iItemState = @SlotItem_GetState(this);

    return (
        iItemState == ItemState_Equiped ||
        iItemState == ItemState_Unequip
    );
}

ItemState:@SlotItem_GetState(const &Struct:this) {
    return StructGetCell(this, SlotItem_State);
}

@SlotItem_SetState(const &Struct:this, ItemState:iState) {
    StructSetCell(this, SlotItem_State, iState);

    if (iState == ItemState_Equiped) {
        StructSetCell(this, SlotItem_LastThink, get_gametime());
    }
}

/*--------------------------------[ Player Cosmetic Methods ]--------------------------------*/

@PlayerCosmetic_Think(this) {
    static Struct:sItem; sItem = Struct:pev(this, pev_iuser1);

    if (!sItem) return;

    if (StructGetCell(sItem, SlotItem_CosmeticType) == Hwn_PlayerCosmetic_Type_Unusual) {
        static szId[32]; StructGetString(sItem, SlotItem_Id, szId, charsmax(szId));
        static iCosmetic; TrieGetCell(g_itCosmetic, szId, iCosmetic);

        static Float:rgflColor[3];
        for (new i = 0; i < sizeof(rgflColor); ++i) {
            rgflColor[i] = float(ArrayGetCell(g_rgiCosmeticData[CosmeticData_EffectColor], iCosmetic, i));
        }

        set_pev(this, pev_renderfx, kRenderFxGlowShell);
        set_pev(this, pev_renderamt, UNUSUAL_ENTITY_RENDER_AMT);
        set_pev(this, pev_rendercolor, rgflColor);
    }
}

/*--------------------------------[ Player Methods ]--------------------------------*/

@Player_GiveCosmetic(this, const szCosmetic[], Hwn_PlayerCosmetic_Type:iCosmeticType, Float:flTime) {
    new iSlot = -1;
    new Struct:sItem = Invalid_Struct;

    new iSize = PlayerInventory_Size(this);
    for (new i = 0; i < iSize; ++i) {
        if (!PlayerInventory_CheckItemType(this, i, INVENTORY_ITEM_TYPE)) continue;

        sItem = PlayerInventory_GetItem(this, i);

        static szItemCosmetic[32];
        StructGetString(sItem, SlotItem_Id, szItemCosmetic, charsmax(szItemCosmetic));
        new Hwn_PlayerCosmetic_Type:iItemCosmeticType = StructGetCell(sItem, SlotItem_CosmeticType);

        if (equal(szCosmetic, szItemCosmetic) && iCosmeticType == iItemCosmeticType) {
            iSlot = i;
            break;
        }
    }

    if (iSlot == -1) {
        sItem = @SlotItem_Create(szCosmetic, iCosmeticType, flTime);
        iSlot = PlayerInventory_GiveItem(this, INVENTORY_ITEM_TYPE, sItem);
    }

    return iSlot;
}

bool:@Player_IsInventorySlotEquiped(this, iSlot) {
    new Struct:sItem = PlayerInventory_GetItem(this, iSlot);

    return @SlotItem_IsEquiped(sItem);
}

bool:@Player_CanEquipInventorySlot(this, iSlot) {
    new Struct:sItem = PlayerInventory_GetItem(this, iSlot);

    static szId[32]; StructGetString(sItem, SlotItem_Id, szId, charsmax(szId));

    new iCosmetic;
    if (!TrieGetCell(g_itCosmetic, szId, iCosmetic)) return false;

    new iGroups = ArrayGetCell(g_rgiCosmeticData[CosmeticData_Groups], iCosmetic);

    return !(g_rgiPlayerEquipedGroups[this] & iGroups);
}

@Player_EquipInventorySlot(this, iSlot) {
    if (!PlayerInventory_CheckItemType(this, iSlot, INVENTORY_ITEM_TYPE)) return;

    new Struct:sItem = PlayerInventory_GetItem(this, iSlot);

    if (@SlotItem_IsEquiped(sItem)) return;

    if (!@Player_CanEquipInventorySlot(this, iSlot)) return;

    static szId[32]; StructGetString(sItem, SlotItem_Id, szId, charsmax(szId));
    new iCosmetic; TrieGetCell(g_itCosmetic, szId, iCosmetic);
    new iModelIndex = ArrayGetCell(g_rgiCosmeticData[CosmeticData_ModelIndex], iCosmetic);

    new pCosmetic = PlayerCosmetic_Equip(this, iModelIndex);
    set_pev(pCosmetic, pev_iuser1, sItem);

    @SlotItem_SetState(sItem, ItemState_Equiped);

    @Player_UpdateEquipedGroups(this);

    ExecuteForward(g_fwEquipmentChanged, _, this);
}

@Player_UnequipInventorySlot(this, iSlot, bool:bChangeState) {
    if (!PlayerInventory_CheckItemType(this, iSlot, INVENTORY_ITEM_TYPE)) return;

    new Struct:sItem = PlayerInventory_GetItem(this, iSlot);

    new ItemState:iItemState = @SlotItem_GetState(sItem);
    if (iItemState == ItemState_None) return;

    static szId[32]; StructGetString(sItem, SlotItem_Id, szId, charsmax(szId));
    new iCosmetic; TrieGetCell(g_itCosmetic, szId, iCosmetic);
    new iModelIndex = ArrayGetCell(g_rgiCosmeticData[CosmeticData_ModelIndex], iCosmetic);

    PlayerCosmetic_Unequip(this, iModelIndex);

    if (bChangeState) {
        @SlotItem_SetState(sItem, ItemState_None);
    }

    new Float:flItemTime = StructGetCell(sItem, SlotItem_Time);
    if (flItemTime <= 0) {
        PlayerInventory_TakeItem(this, iSlot);
    }

    @Player_UpdateEquipedGroups(this);
    
    ExecuteForward(g_fwEquipmentChanged, _, this);
}

@Player_UpdateEquipment(this) {
    if (!g_iCosmeticsNum) return;

    new iSize = PlayerInventory_Size(this);
    for (new iSlot = 0; iSlot < iSize; ++iSlot) {
        if (!PlayerInventory_CheckItemType(this, iSlot, INVENTORY_ITEM_TYPE)) continue;

        new Struct:sItem = PlayerInventory_GetItem(this, iSlot);
        new ItemState:iItemState = @SlotItem_GetState(sItem);

        if (iItemState == ItemState_Equip) {
            @Player_EquipInventorySlot(this, iSlot);
        } else if (iItemState == ItemState_Unequip) {
            @Player_UnequipInventorySlot(this, iSlot, true);
        }
    }
}

@Player_OpenCosmeticMenu(pPlayer, iPage) {
    new iMenu = CreatePlayerCosmeticMenu(pPlayer);

    menu_display(pPlayer, iMenu, iPage);

    if (get_pcvar_num(g_pCvarPreview) > 0 && Hwn_Gamemode_IsPlayerOnSpawn(pPlayer)) {
        new bool:bLight = get_pcvar_num(g_pCvarPreviewLight) > 0;
        @Player_ActivatePreview(pPlayer, bLight);
    }
}

@Player_UpdateEquipedGroups(this) {
    g_rgiPlayerEquipedGroups[this] = 0;

    new iSize = PlayerInventory_Size(this);
    for (new iSlot = 0; iSlot < iSize; ++iSlot) {
        if (!PlayerInventory_CheckItemType(this, iSlot, INVENTORY_ITEM_TYPE)) continue;

        new Struct:sItem = PlayerInventory_GetItem(this, iSlot);
        if (!@SlotItem_IsEquiped(sItem)) continue;

        static szId[32]; StructGetString(sItem, SlotItem_Id, szId, charsmax(szId));
        new iCosmetic; TrieGetCell(g_itCosmetic, szId, iCosmetic);

        g_rgiPlayerEquipedGroups[this] |= ArrayGetCell(g_rgiCosmeticData[CosmeticData_Groups], iCosmetic);
    }
}

bool:@Player_ActivatePreview(pPlayer, bool:bLight) {
    if (!is_user_alive(pPlayer)) return false;
    if (~pev(pPlayer, pev_flags) & FL_ONGROUND) return false;
    if (PlayerCamera_IsActive(pPlayer)) return false;

    set_pev(pPlayer, pev_velocity, Float:{0.0, 0.0, 0.0});
    set_pev(pPlayer, pev_avelocity, Float:{0.0, 0.0, 0.0});
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) | FL_FROZEN);

    PlayerCamera_Activate(pPlayer);
    PlayerCamera_SetDistance(pPlayer, PREVIEW_CAMERA_DISTANCE);
    PlayerCamera_SetAngles(pPlayer, PREVIEW_CAMERA_ANGLES);
    // PlayerCamera_SetOffset(pPlayer);
    PlayerCamera_SetThinkDelay(pPlayer, 1.0);

    g_rbPlayerInPreview[pPlayer] = true;
    g_rgflPlayerNextHighlight[pPlayer] = bLight ? get_gametime() : 0.0;

    return true;
}

@Player_DeactivatePreview(pPlayer) {
    if (!g_rbPlayerInPreview[pPlayer]) return;

    PlayerCamera_Deactivate(pPlayer);
    g_rbPlayerInPreview[pPlayer] = false;
    g_rgflPlayerNextHighlight[pPlayer] = 0.0;
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
}

/*--------------------------------[ Functions ]--------------------------------*/

Register(const szName[], Hwn_PlayerCosmetic_Group:iGroups, iModelIndex, iBody, iSkin, const rgiEffectColor[3]) {
    if (!g_iCosmeticsNum) {
        g_rgiCosmeticData[CosmeticData_Name] = ArrayCreate(32);
        g_rgiCosmeticData[CosmeticData_Groups] = ArrayCreate();
        g_rgiCosmeticData[CosmeticData_ModelIndex] = ArrayCreate();
        g_rgiCosmeticData[CosmeticData_Body] = ArrayCreate();
        g_rgiCosmeticData[CosmeticData_Skin] = ArrayCreate();
        g_rgiCosmeticData[CosmeticData_EffectColor] = ArrayCreate(3);
        g_itCosmetic = TrieCreate();
    }

    ArrayPushString(g_rgiCosmeticData[CosmeticData_Name], szName);
    ArrayPushCell(g_rgiCosmeticData[CosmeticData_Groups], iGroups);
    ArrayPushCell(g_rgiCosmeticData[CosmeticData_ModelIndex], iModelIndex);
    ArrayPushCell(g_rgiCosmeticData[CosmeticData_Body], iBody);
    ArrayPushCell(g_rgiCosmeticData[CosmeticData_Skin], iSkin);
    ArrayPushArray(g_rgiCosmeticData[CosmeticData_EffectColor], rgiEffectColor);

    new iCosmetic = g_iCosmeticsNum;
    TrieSetCell(g_itCosmetic, szName, iCosmetic);

    g_iCosmeticsNum++;

    log_amx("[Hwn Cosmetics] Cosmetic ^"%s^" registered.", szName);

    return iCosmetic;
}

CreatePlayerCosmeticMenu(pPlayer) {
    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", pPlayer, "HWN_COSMETIC_MENU_TITLE");

    if (g_rgirgPlayerMenuSlotRefs[pPlayer] == Invalid_Array) {
        g_rgirgPlayerMenuSlotRefs[pPlayer] = ArrayCreate();
    } else {
        ArrayClear(g_rgirgPlayerMenuSlotRefs[pPlayer]);
    }

    new iMenu = menu_create(szMenuTitle, "MenuHandler_PlayerCosmetics");

    new iInventorySize = PlayerInventory_Size(pPlayer);

    for (new iSlot = 0; iSlot < iInventorySize; ++iSlot) {
        if (!PlayerInventory_CheckItemType(pPlayer, iSlot, INVENTORY_ITEM_TYPE)) continue;

        new Struct:sItem = PlayerInventory_GetItem(pPlayer, iSlot);
        new Floa:flTime = StructGetCell(sItem, SlotItem_Time);

        if (!flTime) continue;

        new iItemCallback = menu_makecallback("MenuCallback_PlayerCosmetics_Item");
        menu_additem(iMenu, "", .callback = iItemCallback);
        ArrayPushCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iSlot);
    }

    if (!ArraySize(g_rgirgPlayerMenuSlotRefs[pPlayer])) {
        static szEmptyCosmeticText[64];
        format(szEmptyCosmeticText, charsmax(szEmptyCosmeticText), "\d%L", pPlayer, "HWN_COSMETIC_MENU_EMPTY");
        menu_addtext2(iMenu, szEmptyCosmeticText);
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    return iMenu;
}

LoadCosmetics() {
    new szFileName[32];

    new FileType:iFileType;
    new iDir = open_dir(g_szCosmeticsDir, szFileName, charsmax(szFileName), iFileType);

    if (!iDir) return;

    do {
        if (iFileType != FileType_File) continue;

        new iLen = strlen(szFileName);
        if (iLen > 5 && equal(szFileName[iLen - 5], ".json")) {
            new szFilePath[MAX_RESOURCE_PATH_LENGTH];
            format(szFilePath, charsmax(szFilePath), "%s/%s", g_szCosmeticsDir, szFileName);
            LoadCosmeticsFromFile(szFilePath);
        }

    } while (next_file(iDir, szFileName, charsmax(szFileName), iFileType));

    close_dir(iDir);
}

LoadCosmeticsFromFile(const szFilePath[]) {
    new JSON:jsonDoc = json_parse(szFilePath, true);

    new iVersion = json_object_get_number(jsonDoc, "_version");
    if (iVersion > COSMETICS_DOCUMENT_VERSION) {
        log_amx("Cannot load cosmetics from ^"%s^". Cosmetics version should be less than or equal to %d.", szFilePath, COSMETICS_DOCUMENT_VERSION);
        return;
    }

    new JSON:jsonItems = json_object_get_value(jsonDoc, "items");

    for (new iCosmetic = 0; iCosmetic < json_array_get_count(jsonItems); ++iCosmetic) {
        new JSON:jsonCosmetic = json_array_get_value(jsonItems, iCosmetic);

        new szName[256];
        json_object_get_string(jsonCosmetic, "name", szName, charsmax(szName));

        new szModel[256];
        json_object_get_string(jsonCosmetic, "model", szModel, charsmax(szModel));

        new iModelIndex = precache_model(szModel);
        new iBody = json_object_get_number(jsonCosmetic, "body");
        new iSkin = json_object_get_number(jsonCosmetic, "skin");
        new Hwn_PlayerCosmetic_Group:iGroups = GetGroupsFromJson(json_object_get_value(jsonCosmetic, "groups"));

        new JSON:jsonEffectColor = json_object_get_value(jsonCosmetic, "effectColor");

        new rgiEffectColor[3];
        for (new i = 0; i < 3; ++i) {
            rgiEffectColor[i] = json_array_get_number(jsonEffectColor, i);
        }

        Register(szName, iGroups, iModelIndex, iBody, iSkin, rgiEffectColor);
    }

    json_free(jsonDoc);
}

Hwn_PlayerCosmetic_Group:GetGroupsFromJson(JSON:jsonGroups) {
    new Trie:itGroups = TrieCreate();
    for (new i = 0; i < sizeof(Hwn_PlayerCosmetic_GroupNames); ++i) {
        TrieSetCell(itGroups, Hwn_PlayerCosmetic_GroupNames[i], 1 << (i + 1));
    }

    new Hwn_PlayerCosmetic_Group:iGroups = Hwn_PlayerCosmetic_Group:0;

    for (new i = 0; i < json_array_get_count(jsonGroups); ++i) {
        new szGroup[32];
        json_array_get_string(jsonGroups, i, szGroup, charsmax(szGroup));

        new Hwn_PlayerCosmetic_Group:iGroup;
        TrieGetCell(itGroups, szGroup, iGroup);

        iGroups |= iGroup;
    }

    TrieDestroy(itGroups);

    return iGroups;
}

public MenuHandler_PlayerCosmetics(pPlayer, iMenu, iItem) {
    menu_destroy(iMenu);

    if (iItem != MENU_EXIT) {
        new iSlot = ArrayGetCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iItem);
        if (PlayerInventory_CheckItemType(pPlayer, iSlot, INVENTORY_ITEM_TYPE)) {
            new Struct:sItem = PlayerInventory_GetItem(pPlayer, iSlot);

            if (@SlotItem_IsEquiped(sItem)) {
                @Player_UnequipInventorySlot(pPlayer, iSlot, true);
            } else {
                @Player_EquipInventorySlot(pPlayer, iSlot);
            }
        }
    }

    if (is_user_connected(pPlayer)) {
        if (iItem != MENU_EXIT) {
            new iPage = 0;
            new _iUnusedRef;
            player_menu_info(pPlayer, _iUnusedRef, _iUnusedRef, iPage);

            @Player_OpenCosmeticMenu(pPlayer, iPage);
        } else {
            @Player_DeactivatePreview(pPlayer);
        }
    }

    return PLUGIN_HANDLED;
}

public MenuCallback_PlayerCosmetics_Item(pPlayer, iMenu, iItem) {
    new iSlot = ArrayGetCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iItem);
    new Struct:sItem = PlayerInventory_GetItem(pPlayer, iSlot);
    new Float:flTime = StructGetCell(sItem, SlotItem_Time);

    new Hwn_PlayerCosmetic_Type:iCosmeticType = StructGetCell(sItem, SlotItem_CosmeticType);

    static szCosmeticName[32];
    StructGetString(sItem, SlotItem_Id, szCosmeticName, charsmax(szCosmeticName));

    static szText[128];
    format(
        szText,
        charsmax(szText),
        "%s%s%s (%i seconds left)",
        (@Player_IsInventorySlotEquiped(pPlayer, iSlot) ? "\y" : ""),
        (iCosmeticType == Hwn_PlayerCosmetic_Type_Unusual ? "Unusual " : "^0"),
        szCosmeticName,
        floatround(flTime)
    );

    menu_item_setname(iMenu, iItem, szText);

    if (!@Player_CanEquipInventorySlot(pPlayer, iSlot) && !@Player_IsInventorySlotEquiped(pPlayer, iSlot)) {
        return ITEM_DISABLED;
    }

    if (!flTime) return ITEM_DISABLED;

    return ITEM_ENABLED;
}
