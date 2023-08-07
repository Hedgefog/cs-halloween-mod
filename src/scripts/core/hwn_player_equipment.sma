#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <reapi>
#include <hamsandwich>

#include <cstrike>
#include <fun>

#include <cs_weapons_consts>

#include <hwn>
#include <hwn_utils>

#define PLUGIN    "[Hwn] Player Equipment"
#define AUTHOR    "Hedgehog Fog"

new const g_rgiWeapons[] = {
    0,
    CSW_UMP45,
    CSW_MP5NAVY,
    CSW_P90,
    CSW_SCOUT,
    CSW_M3
};

new g_fwEquipmentChanged;

new g_iWeaponMenu;
new g_szMenuTitle[32];

new g_rgiPlayerWeapon[MAX_PLAYERS + 1];

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_fwEquipmentChanged = CreateMultiForward("Hwn_PEquipment_Event_Changed", ET_IGNORE, FP_CELL);

    format(g_szMenuTitle, charsmax(g_szMenuTitle), "%L", LANG_SERVER, "HWN_EQUIPMENT_MENU_TITLE");

    SetupMenu();
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_PEquipment_ShowMenu", "Native_ShowMenu");
    register_native("Hwn_PEquipment_Equip", "Native_Equip");
    register_native("Hwn_PEquipment_GiveHealth", "Native_GiveHealth");
    register_native("Hwn_PEquipment_GiveArmor", "Native_GiveArmor");
    register_native("Hwn_PEquipment_GiveAmmo", "Native_GiveAmmo");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_ShowMenu(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    ShowMenu(pPlayer);
}

public Native_Equip(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    Equip(pPlayer);
}

public Native_GiveHealth(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);
    GiveHealth(pPlayer, iAmount);
}

public Native_GiveArmor(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);
    GiveArmor(pPlayer, iAmount);
}

public Native_GiveAmmo(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);
    GiveAmmo(pPlayer, iAmount);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_connect(pPlayer) {
    new iEquipment = is_user_bot(pPlayer) ? random(sizeof(g_rgiWeapons)) : 0;
    g_rgiPlayerWeapon[pPlayer] = iEquipment;
}

/*--------------------------------[ Methods ]--------------------------------*/

SetupMenu() {
    if (g_iWeaponMenu) {
        menu_destroy(g_iWeaponMenu);
        g_iWeaponMenu = 0;
    }

    g_iWeaponMenu = menu_create(g_szMenuTitle, "MenuHandler");

    new iCallback = menu_makecallback("MenuCallback");

    for (new iWeapon = 0; iWeapon < sizeof(g_rgiWeapons); ++iWeapon) {
        menu_additem(g_iWeaponMenu, "", "", _, iCallback);
    }

    menu_setprop(g_iWeaponMenu, MPROP_EXIT, MEXIT_ALL);
}

Equip(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    rg_remove_all_items(pPlayer);

    give_item(pPlayer, WeaponEntityNames[CSW_KNIFE]);

    give_item(pPlayer, WeaponEntityNames[CSW_GLOCK18]);
    cs_set_user_bpammo(pPlayer, CSW_MP5NAVY, WeaponMaxBPAmmo[CSW_MP5NAVY]);

    new iEquipment = g_rgiPlayerWeapon[pPlayer];
    new iWeapon = g_rgiWeapons[iEquipment];

    if (iWeapon) {
        give_item(pPlayer, WeaponEntityNames[iWeapon]);
        cs_set_user_bpammo(pPlayer, iWeapon, WeaponMaxBPAmmo[iWeapon]);
    }

    cs_set_user_armor(pPlayer, 100, CS_ARMOR_VESTHELM);
}

GiveHealth(pPlayer, iAmount) {
    static Float:flHealth;
    pev(pPlayer, pev_health, flHealth);
    flHealth = floatmin(flHealth + float(iAmount), 100.0);
    set_pev(pPlayer, pev_health, flHealth);
}

GiveArmor(pPlayer, iAmount) {
    static Float:flArmor;
    pev(pPlayer, pev_armorvalue, flArmor);
    flArmor = floatmin(flArmor + float(iAmount), 100.0);
    set_pev(pPlayer, pev_armorvalue, flArmor);
}

GiveAmmo(pPlayer, iAmount) {
    new rgiWeapons[32];
    new iWeaponsNum = 0;

    get_user_weapons(pPlayer, rgiWeapons, iWeaponsNum);

    for (new i = 0; i < iWeaponsNum; ++i) {
        new iWeapon = rgiWeapons[i];
        new iAmmoType = WeaponAmmo[iWeapon];

        if (iAmmoType >= 0) {
            for (new i = 0; i < iAmount; ++i) {
                give_item(pPlayer, AmmoEntityNames[iAmmoType]);
            }
        }
    }
}

ShowMenu(pPlayer) {
    menu_display(pPlayer, g_iWeaponMenu);
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler(pPlayer, iMenu, iItem) {
    if (iItem != MENU_EXIT) {
        g_rgiPlayerWeapon[pPlayer] = iItem;
        ExecuteForward(g_fwEquipmentChanged, _, pPlayer);
    }

    if (is_user_connected(pPlayer)) {
        menu_cancel(pPlayer);
    }

    return PLUGIN_HANDLED;
}

public MenuCallback(pPlayer, iMenu, iItem) {
    new iWeapon = g_rgiWeapons[iItem];

    static szText[128];
    new iEquipment = g_rgiPlayerWeapon[pPlayer];
    if (iItem == iEquipment) {
        format(szText, charsmax(szText), "\y%s", WeaponNames[iWeapon]);
    } else {
        format(szText, charsmax(szText), "%s", WeaponNames[iWeapon]);
    }

    menu_item_setname(iMenu, iItem, szText);

    return ITEM_ENABLED;
}
