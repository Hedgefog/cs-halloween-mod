#pragma semicolon 1

#include <amxmodx>

#include <api_player_inventory>
#include <api_player_cosmetic>
#include <api_player_preview>

#include <hwn>

#define PLUGIN "[Hwn] Menu Player Cosmetic"
#define AUTHOR "Hedgehog Fog"

new g_cvarPreview;
new g_cvarPreviewLight;

new PInv_ItemType:g_hCosmeticItemType;

new Array:g_playerMenu;
new Array:g_playerMenuSlotRefs;

new g_maxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_cvarPreview = register_cvar("hwn_pcosmetic_menu_preview", "1");
    g_cvarPreviewLight = register_cvar("hwn_pcosmetic_menu_preview_light", "1");

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

Open(id, page = 0)
{
    new menu = ArrayGetCell(g_playerMenu, id);
    if (menu) {
        menu_destroy(menu);
    }

    menu = Create(id);
    ArraySetCell(g_playerMenu, id, menu);

    menu_display(id, menu, page);

    if (get_pcvar_num(g_cvarPreview) > 0 && Hwn_Gamemode_IsPlayerOnSpawn(id)) {
        new bool:light = get_pcvar_num(g_cvarPreviewLight) > 0;
        PlayerPreview_Activate(id, light);
    }
}

Create(id)
{
    new callbackDisabled = menu_makecallback("MenuDisabledCallback");

    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", id, "HWN_COSMETIC_MENU_TITLE");
    
    new menu = menu_create(szMenuTitle, "MenuHandler");

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

        menu_additem(menu, text, .callback = PCosmetic_CanBeEquiped(id, cosmetic, i)
            || PCosmetic_IsItemEquiped(id, i)  ? -1 : callbackDisabled);
    }

    if (!size) {
        static szEmptyCosmeticText[64];
        format(szEmptyCosmeticText, charsmax(szEmptyCosmeticText), "%L", id, "HWN_COSMETIC_MENU_EMPTY");

        menu_additem(menu, szEmptyCosmeticText, .callback = callbackDisabled);
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
        PlayerPreview_Deactivate(id);

        new page = 0;
        {
            new _unusedRef;
            player_menu_info(id, _unusedRef, _unusedRef, page);
        }

        if (item != MENU_EXIT) {
            Open(id, page);
        }
    }

    return PLUGIN_HANDLED;
}

public MenuDisabledCallback()
{
    return ITEM_DISABLED;
}
