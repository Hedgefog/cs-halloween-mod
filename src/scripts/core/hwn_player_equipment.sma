#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <json>

#include <cellstruct>

#include <hwn>

#define PLUGIN "[Hwn] Player Equipment"
#define AUTHOR "Hedgehog Fog"

#define EQUIPMENT_DOCUMENT_VERSION 1

enum Equipment {
    Equipment_Title[32],
    Equipment_MaxHealth,
    Equipment_Health,
    Equipment_Armor,
    Equipment_ArmorType,
    Array:Equipment_Items
}

new g_fwEquipmentChanged;

new g_szMenuTitle[32];
new g_iEquipmentMenu;
new Array:g_rgsEquipments;

new g_rgiPlayerEquipment[MAX_PLAYERS + 1];

public plugin_precache() {
    g_rgsEquipments = ArrayCreate();

    LoadEquipment();
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_fwEquipmentChanged = CreateMultiForward("Hwn_PEquipment_Event_Changed", ET_IGNORE, FP_CELL);

    format(g_szMenuTitle, charsmax(g_szMenuTitle), "%L", LANG_SERVER, "HWN_EQUIPMENT_MENU_TITLE");

    g_iEquipmentMenu = CreateMenu();
}

public plugin_end() {
    for (new iEquipment = 0; iEquipment < ArraySize(g_rgsEquipments); ++iEquipment) {
        new Struct:sEquipment = ArrayGetCell(g_rgsEquipments, iEquipment);
        @Equipment_Destroy(sEquipment);
    }

    ArrayDestroy(g_rgsEquipments);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_PEquipment_Equip", "Native_Equip");
    register_native("Hwn_PEquipment_GiveHealth", "Native_GiveHealth");
    register_native("Hwn_PEquipment_GiveArmor", "Native_GiveArmor");
    register_native("Hwn_PEquipment_GiveAmmo", "Native_GiveAmmo");
    register_native("Hwn_PEquipment_ShowMenu", "Native_ShowMenu");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_ShowMenu(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    @Player_OpenEquipmentMenu(pPlayer);
}

public Native_Equip(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    @Player_Equip(pPlayer);
}

public Native_GiveHealth(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);

    @Player_GiveHealth(pPlayer, iAmount);
}

public Native_GiveArmor(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);

    @Player_GiveArmor(pPlayer, iAmount);
}

public Native_GiveAmmo(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iAmount = get_param(2);

    @Player_GiveAmmo(pPlayer, iAmount);
}

Struct:@Equipment_Create() {
    new Struct:this = StructCreate(Equipment);

    new Array:irgItems = ArrayCreate(32, 4);
    StructSetCell(this, Equipment_Items, irgItems);

    return this;
}

@Equipment_Destroy(&Struct:this) {
    new Array:irgItems = StructGetCell(this, Equipment_Items);
    ArrayDestroy(irgItems);

    StructDestroy(this);
}

@Player_Equip(this) {
    if (!is_user_alive(this)) return;

    strip_user_weapons(this);

    new iEquipment = g_rgiPlayerEquipment[this];
    new Struct:sEquipment = ArrayGetCell(g_rgsEquipments, iEquipment);

    new Array:irgItems = StructGetCell(sEquipment, Equipment_Items);
    new iItemsNum = ArraySize(irgItems);

    for (new i = 0; i < iItemsNum; ++i) {
        static szItem[32];
        ArrayGetString(irgItems, i, szItem, charsmax(szItem));
        give_item(this, szItem);

        new iWeaponId = get_weaponid(szItem);
        if (iWeaponId) {
            new iMaxRounds = cs_get_weapon_info(iWeaponId, CS_WEAPONINFO_MAX_ROUNDS);
            if (iMaxRounds) cs_set_user_bpammo(this, iWeaponId, iMaxRounds);
        }
    }

    static iMaxHealth; iMaxHealth = StructGetCell(sEquipment, Equipment_MaxHealth);
    set_pev(this, pev_max_health, float(iMaxHealth));

    static iHealth; iHealth = StructGetCell(sEquipment, Equipment_Health);
    set_pev(this, pev_health, float(iHealth));
    
    static iArmor; iArmor = StructGetCell(sEquipment, Equipment_Armor);
    static CsArmorType:iArmorType; iArmorType = StructGetCell(sEquipment, Equipment_ArmorType);
    cs_set_user_armor(this, iArmor, iArmorType);
}

@Player_GiveHealth(this, iAmount) {
    static Float:flMaxHealth; pev(this, pev_max_health, flMaxHealth);

    static Float:flHealth; pev(this, pev_health, flHealth);
    flHealth = floatmin(flHealth + float(iAmount), flMaxHealth);
    set_pev(this, pev_health, flHealth);
}

@Player_GiveArmor(this, iAmount) {
    static Float:flArmor;
    pev(this, pev_armorvalue, flArmor);
    flArmor = floatmin(flArmor + float(iAmount), 100.0);
    set_pev(this, pev_armorvalue, flArmor);
}

@Player_GiveAmmo(this, iAmount) {
    new rgiWeapons[32];
    new iWeaponsNum = 0;
    get_user_weapons(this, rgiWeapons, iWeaponsNum);

    for (new i = 0; i < iWeaponsNum; ++i) {
        new iWeaponId = rgiWeapons[i];
        new iMaxRounds = cs_get_weapon_info(iWeaponId, CS_WEAPONINFO_MAX_ROUNDS);
        new iClipSize = cs_get_weapon_info(iWeaponId, CS_WEAPONINFO_BUY_CLIP_SIZE);
        
        if (!iMaxRounds) continue;

        new iAmount = cs_get_user_bpammo(this, iWeaponId);
        iAmount = min(iAmount + iClipSize, iMaxRounds);
        cs_set_user_bpammo(this, iWeaponId, iAmount);
    }
}

@Player_OpenEquipmentMenu(this) {
    menu_display(this, g_iEquipmentMenu);
}

LoadEquipment() {
    new szConfigsDir[MAX_RESOURCE_PATH_LENGTH];
    get_configsdir(szConfigsDir, charsmax(szConfigsDir));
   
    new szFilePath[MAX_RESOURCE_PATH_LENGTH];
    format(szFilePath, charsmax(szFilePath), "%s/hwn/equipment.json", szConfigsDir, szFilePath);

    new JSON:jsonDoc = json_parse(szFilePath, true);

    new iVersion = json_object_get_number(jsonDoc, "_version");
    if (iVersion > EQUIPMENT_DOCUMENT_VERSION) {
        log_amx("Cannot load equipment from ^"%s^". Equipment version should be less than or equal to %d.", szFilePath, EQUIPMENT_DOCUMENT_VERSION);
        return;
    }

    new JSON:jsonItems = json_object_get_value(jsonDoc, "items");

    for (new iEquipment = 0; iEquipment < json_array_get_count(jsonItems); ++iEquipment) {
        new JSON:jsonEquipment = json_array_get_value(jsonItems, iEquipment);

        new Struct:sEquipment = @Equipment_Create();

        new szTitle[32];
        json_object_get_string(jsonEquipment, "title", szTitle, charsmax(szTitle));
        StructSetString(sEquipment, Equipment_Title, szTitle);

        StructSetCell(sEquipment, Equipment_MaxHealth, json_object_get_number(jsonEquipment, "maxhealth"));
        StructSetCell(sEquipment, Equipment_Health, json_object_get_number(jsonEquipment, "health"));
        StructSetCell(sEquipment, Equipment_Armor, json_object_get_number(jsonEquipment, "armor"));
        StructSetCell(sEquipment, Equipment_ArmorType, json_object_get_number(jsonEquipment, "armortype"));

        new JSON:jsonItems = json_object_get_value(jsonEquipment, "items");

        new Array:irgItems = StructGetCell(sEquipment, Equipment_Items);
        for (new i = 0; i < json_array_get_count(jsonItems); ++i) {
            new szItem[32]; json_array_get_string(jsonItems, i, szItem, charsmax(szItem));
            ArrayPushString(irgItems, szItem);
        }

        log_amx("[Hwn Player Equipment] Equipment ^"%s^" loaded.", szTitle);

        ArrayPushCell(g_rgsEquipments, sEquipment);
    }

    json_free(jsonDoc);
}

CreateMenu() {
    new iMenu = menu_create(g_szMenuTitle, "MenuHandler_Equipment");

    new iCallback = menu_makecallback("MenuCallback_Equipment");

    for (new iEquipment = 0; iEquipment < ArraySize(g_rgsEquipments); ++iEquipment) {
        menu_additem(iMenu, "", "", _, iCallback);
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);
    
    return iMenu;
}

public MenuHandler_Equipment(pPlayer, iMenu, iItem) {
    if (iItem != MENU_EXIT) {
        g_rgiPlayerEquipment[pPlayer] = iItem;
        ExecuteForward(g_fwEquipmentChanged, _, pPlayer);
    }

    if (is_user_connected(pPlayer)) menu_cancel(pPlayer);

    return PLUGIN_HANDLED;
}

public MenuCallback_Equipment(pPlayer, iMenu, iItem) {
    static Struct:sEquipment; sEquipment = ArrayGetCell(g_rgsEquipments, iItem);

    static szName[32];
    StructGetString(sEquipment, Equipment_Title, szName, charsmax(szName));
    format(szName, charsmax(szName), "%s%s", g_rgiPlayerEquipment[pPlayer] == iItem ? "\y" : "", szName);
    
    menu_item_setname(iMenu, iItem, szName);

    return ITEM_ENABLED;
}
