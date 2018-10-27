#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <hamsandwich>

#include <cstrike>
#include <fun>

#include <cs_weapons_consts>

#include <hwn>
#include <hwn_utils>

#define PLUGIN    "[Hwn] Player Equipment"
#define AUTHOR    "Hedgehog Fog"

new const g_weaponIndexes[] =
{
    0,
    CSW_UMP45,
    CSW_MP5NAVY,
    CSW_P90,
    CSW_SCOUT,
    CSW_M3
};

new g_fwResult;
new g_fwEquipmentChanged;

new Array:g_playerEquipment;

new g_weaponMenu;

new g_maxPlayers;

static g_szMenuTitle[32];

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    g_maxPlayers = get_maxplayers();
    
    g_playerEquipment = ArrayCreate(1, g_maxPlayers+1);
    for (new i = 0; i <= g_maxPlayers; ++i) {
        ArrayPushCell(g_playerEquipment, 0);
    }
    
    g_fwEquipmentChanged = CreateMultiForward("Hwn_PEquipment_Event_Changed", ET_IGNORE, FP_CELL);
    
    format(g_szMenuTitle, charsmax(g_szMenuTitle), "%L", LANG_SERVER, "HWN_EQUIPMENT_MENU_TITLE");
    
    SetupMenu();
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_PEquipment_ShowMenu", "Native_ShowMenu");
    register_native("Hwn_PEquipment_Equip", "Native_Equip");
}

public plugin_end()
{
    ArrayDestroy(g_playerEquipment);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_ShowMenu(pluginID, argc)
{
    new id = get_param(1);
    ShowMenu(id);
}

public Native_Equip(pluginID, argc)
{
    new id = get_param(1);
    Equip(id);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_connect(id)
{
    ArraySetCell(g_playerEquipment, id, random(sizeof(g_weaponIndexes)));
}

/*--------------------------------[ Methods ]--------------------------------*/

SetupMenu()
{
    if (g_weaponMenu) {
        menu_destroy(g_weaponMenu);
        g_weaponMenu = 0;
    }

    g_weaponMenu = menu_create(g_szMenuTitle, "MenuHandler");
    new callback = menu_makecallback("MenuCallback");
    
    for(new i = 0; i < sizeof(g_weaponIndexes); ++i) {
        menu_additem(g_weaponMenu, "", "", _, callback);
    }
    menu_setprop(g_weaponMenu, MPROP_EXIT, MEXIT_ALL);
}

Equip(id)
{
    if(!is_user_alive(id)) {
        return;
    }

    strip_user_weapons(id);
    
    give_item(id, WeaponEntityNames[CSW_KNIFE]);
    
    give_item(id, WeaponEntityNames[CSW_GLOCK18]);
    cs_set_user_bpammo(id, CSW_MP5NAVY, WeaponMaxBPAmmo[CSW_MP5NAVY]);
    
    new equipment = ArrayGetCell(g_playerEquipment, id);
    new wpnIdx = g_weaponIndexes[equipment];
    
    if (wpnIdx) {
        give_item(id, WeaponEntityNames[wpnIdx]);
        cs_set_user_bpammo(id, wpnIdx, WeaponMaxBPAmmo[wpnIdx]);
    }

    cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM);
}

ShowMenu(id)
{
    menu_display(id, g_weaponMenu);
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler(id, menu, item)
{
    if(item != MENU_EXIT)
    {
        ArraySetCell(g_playerEquipment, id, item);
        ExecuteForward(g_fwEquipmentChanged, g_fwResult, id);
    }
    
    if(is_user_connected(id)) {
        menu_cancel(id);
    }
        
    return PLUGIN_HANDLED;
}

public MenuCallback(id, menu, item)
{
    new szText[128];
    new weaponIndex = g_weaponIndexes[item];

    new equipment = ArrayGetCell(g_playerEquipment, id);
    if(item == equipment) {
        format(szText, charsmax(szText), "\y%s", WeaponNames[weaponIndex]);
    } else {
        format(szText, charsmax(szText), "%s", WeaponNames[weaponIndex]);
    }
        
    menu_item_setname(menu, item, szText);
    
    return ITEM_ENABLED;
}
