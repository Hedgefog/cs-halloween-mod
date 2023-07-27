#pragma semicolon 1

#include <amxmodx>

#include <api_player_inventory>
#include <api_player_cosmetic>
#include <api_player_preview>

#include <hwn>

#define PLUGIN "[Hwn] Menu Player Cosmetic"
#define AUTHOR "Hedgehog Fog"

new g_pCvarPreview;
new g_pCvarPreviewLight;

new PInv_ItemType:g_iCosmeticItemType;
new Array:g_rgirgPlayerMenuSlotRefs[MAX_PLAYERS + 1] = { Invalid_Array, ... };


public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarPreview = register_cvar("hwn_pcosmetic_menu_preview", "1");
    g_pCvarPreviewLight = register_cvar("hwn_pcosmetic_menu_preview_light", "1");

    g_iCosmeticItemType = PInv_GetItemTypeHandler("cosmetic");
}

public plugin_natives() {
    register_library("menu_player_cosmetic");
    register_native("PCosmetic_Menu_Open", "Native_Open");
}

public plugin_end() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (g_rgirgPlayerMenuSlotRefs[pPlayer] != Invalid_Array) {
            ArrayDestroy(g_rgirgPlayerMenuSlotRefs[pPlayer]);
        }
    }
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Open(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    @Player_OpenMenu(pPlayer, 0);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_OpenMenu(pPlayer, iPage) {
    new iMenu = CreateMenu(pPlayer);

    menu_display(pPlayer, iMenu, iPage);

    if (get_pcvar_num(g_pCvarPreview) > 0 && Hwn_Gamemode_IsPlayerOnSpawn(pPlayer)) {
        new bool:bLight = get_pcvar_num(g_pCvarPreviewLight) > 0;
        PlayerPreview_Activate(pPlayer, bLight);
    }
}

/*--------------------------------[ Functions ]--------------------------------*/

CreateMenu(pPlayer) {
    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", pPlayer, "HWN_COSMETIC_MENU_TITLE");

    if (g_rgirgPlayerMenuSlotRefs[pPlayer] == Invalid_Array) {
        g_rgirgPlayerMenuSlotRefs[pPlayer] = ArrayCreate();
    } else {
        ArrayClear(g_rgirgPlayerMenuSlotRefs[pPlayer]);
    }

    new iMenu = menu_create(szMenuTitle, "MenuHandler_Main");

    new iInvSize = PInv_Size(pPlayer);
    if (!iInvSize) {
        static szEmptyCosmeticText[64];
        format(szEmptyCosmeticText, charsmax(szEmptyCosmeticText), "\d%L", pPlayer, "HWN_COSMETIC_MENU_EMPTY");
        menu_addtext2(iMenu, szEmptyCosmeticText);
    }

    for (new iSlot = 0; iSlot < iInvSize; ++iSlot) {
        if (PInv_GetItemType(pPlayer, iSlot) != g_iCosmeticItemType) {
            continue;
        }

        if (!PCosmetic_GetItemTime(pPlayer, iSlot)) {
            continue;
        }

        new iItemCallback = menu_makecallback("MenuCallback_Main_Item");
        menu_additem(iMenu, "", .callback = iItemCallback);
        ArrayPushCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iSlot);
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    return iMenu;
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler_Main(pPlayer, iMenu, iItem) {
    menu_destroy(iMenu);

    if (iItem != MENU_EXIT) {
        new iSlot = ArrayGetCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iItem);
        new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);

        if (iItemType == g_iCosmeticItemType) {
            new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);
            if (iItemType == g_iCosmeticItemType) {
                if (PCosmetic_IsItemEquiped(pPlayer, iSlot)) {
                    PCosmetic_Unequip(pPlayer, iSlot);
                } else {
                    PCosmetic_Equip(pPlayer, iSlot);
                }
            }
        }
    }

    if (is_user_connected(pPlayer)) {
        if (iItem != MENU_EXIT) {
            new iPage = 0;
            new _iUnusedRef;
            player_menu_info(pPlayer, _iUnusedRef, _iUnusedRef, iPage);

            @Player_OpenMenu(pPlayer, iPage);
        } else {
            PlayerPreview_Deactivate(pPlayer);
        }
    }

    return PLUGIN_HANDLED;
}

public MenuCallback_Main_Item(pPlayer, iMenu, iItem) {
    new iSlot = ArrayGetCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iItem);
    new iCosmetic = PCosmetic_GetItemCosmetic(pPlayer, iSlot);
    new iItemTime = PCosmetic_GetItemTime(pPlayer, iSlot);
    new PCosmetic_Type:iCosmeticType = PCosmetic_GetItemCosmeticType(pPlayer, iSlot);

    static szCosmeticName[32];
    PCosmetic_GetCosmeticName(iCosmetic, szCosmeticName, charsmax(szCosmeticName));

    static szText[128];
    format(
        szText,
        charsmax(szText),
        "%s%s%s (%i seconds left)",
        (PCosmetic_IsItemEquiped(pPlayer, iSlot) ? "\y" : ""),
        (iCosmeticType == PCosmetic_Type_Unusual ? "Unusual " : "^0"),
        szCosmeticName,
        iItemTime
    );

    menu_item_setname(iMenu, iItem, szText);

    if (!PCosmetic_CanBeEquiped(pPlayer, iCosmetic, iSlot) && !PCosmetic_IsItemEquiped(pPlayer, iSlot)) {
        return ITEM_DISABLED;
    }

    if (!iItemTime) {
        return ITEM_DISABLED;
    }

    return ITEM_ENABLED;
}
