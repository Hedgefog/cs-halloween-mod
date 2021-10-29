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

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

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

new g_playerEquipment[MAX_PLAYERS + 1] = { 0, ... };

new g_weaponMenu;

static g_szMenuTitle[32];

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_fwEquipmentChanged = CreateMultiForward("Hwn_PEquipment_Event_Changed", ET_IGNORE, FP_CELL);

    format(g_szMenuTitle, charsmax(g_szMenuTitle), "%L", LANG_SERVER, "HWN_EQUIPMENT_MENU_TITLE");

    SetupMenu();
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_PEquipment_ShowMenu", "Native_ShowMenu");
    register_native("Hwn_PEquipment_Equip", "Native_Equip");
    register_native("Hwn_PEquipment_GiveHealth", "Native_GiveHealth");
    register_native("Hwn_PEquipment_GiveArmor", "Native_GiveArmor");
    register_native("Hwn_PEquipment_GiveAmmo", "Native_GiveAmmo");
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

public Native_GiveHealth(pluginID, argc)
{
    new id = get_param(1);
    new amount = get_param(2);
    GiveHealth(id, amount);
}

public Native_GiveArmor(pluginID, argc)
{
    new id = get_param(1);
    new amount = get_param(2);
    GiveArmor(id, amount);
}

public Native_GiveAmmo(pluginID, argc)
{
    new id = get_param(1);
    new amount = get_param(2);
    GiveAmmo(id, amount);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_connect(id)
{
    new equipment = is_user_bot(id) ? random(sizeof(g_weaponIndexes)) : 0;
    g_playerEquipment[id] = equipment;
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

    for (new i = 0; i < sizeof(g_weaponIndexes); ++i) {
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

    new equipment = g_playerEquipment[id];
    new wpnIdx = g_weaponIndexes[equipment];

    if (wpnIdx) {
        give_item(id, WeaponEntityNames[wpnIdx]);
        cs_set_user_bpammo(id, wpnIdx, WeaponMaxBPAmmo[wpnIdx]);
    }

    cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM);
}

GiveHealth(id, amount)
{
    new Float:fHealth;
    pev(id, pev_health, fHealth);

    if (fHealth < 100.0) {
        fHealth += float(amount);

        if (fHealth > 100.0) {
            fHealth = 100.0;
        }

        set_pev(id, pev_health, fHealth);
    }
}


GiveArmor(id, amount)
{
    new Float:fArmor = float(pev(id, pev_armorvalue));

    if (fArmor < 100.0) {
        fArmor += float(amount);

        if (fArmor > 100.0) {
            fArmor = 100.0;
        }

        set_pev(id, pev_armorvalue, fArmor);
    }
}

GiveAmmo(id, amount)
{
    new weapons[32];
    new weaponCount = 0;

    get_user_weapons(id, weapons, weaponCount);

    for (new i = 0; i < weaponCount; ++i) {
        new weapon = weapons[i];
        new ammoType = WeaponAmmo[weapon];

        if (ammoType >= 0) {
            for (new i = 0; i < amount; ++i) {
                give_item(id, AmmoEntityNames[ammoType]);
            }
        }
    }
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
        g_playerEquipment[id] = item;
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

    new equipment = g_playerEquipment[id];
    if(item == equipment) {
        format(szText, charsmax(szText), "\y%s", WeaponNames[weaponIndex]);
    } else {
        format(szText, charsmax(szText), "%s", WeaponNames[weaponIndex]);
    }

    menu_item_setname(menu, item, szText);

    return ITEM_ENABLED;
}
