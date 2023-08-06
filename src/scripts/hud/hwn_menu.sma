#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Menu"
#define AUTHOR "Hedgehog Fog"

new Array:g_irgItemTitle;
new Array:g_irgItemiPluginId;
new Array:g_irgItemFuncId;
new g_iItemsNum = 0;

public plugin_init() {
    register_dictionary("hwn.txt");
    register_dictionary("plmenu.txt");

    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    register_clcmd("hwn_menu", "Command_Menu");
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_Menu_Open", "Native_Open");
    register_native("Hwn_Menu_AddItem", "Native_AddItem");
}

public plugin_end() {
    if (g_iItemsNum) {
        ArrayDestroy(g_irgItemTitle);
        ArrayDestroy(g_irgItemiPluginId);
        ArrayDestroy(g_irgItemFuncId);
    }
}

public Native_Open(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    @Player_OpenMenu(pPlayer);
}

public Native_AddItem(iPluginId, iArgc) {
    new szTitle[32];
    get_string(1, szTitle, charsmax(szTitle));

    new szCallback[32];
    get_string(2, szCallback, charsmax(szCallback));

    return AddMenuItem(szTitle, iPluginId, get_func_id(szCallback, iPluginId));
}

public Command_Menu(pPlayer) {
    @Player_OpenMenu(pPlayer);
    return PLUGIN_HANDLED;
}

@Player_OpenMenu(pPlayer) {    
    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", pPlayer, "HWN_MENU_TITLE");

    new iMenu = menu_create(szMenuTitle, "MenuHandler");

    for (new i = 0; i < g_iItemsNum; ++i) {
        static szTitle[32];
        ArrayGetString(g_irgItemTitle, i, szTitle, charsmax(szTitle));
        menu_additem(iMenu, szTitle);
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);
    menu_display(pPlayer, iMenu);
}

AddMenuItem(const szTitle[], iPluginId, iFunctionId) {
    if (!g_iItemsNum) {
        g_irgItemTitle = ArrayCreate(32);
        g_irgItemiPluginId = ArrayCreate();
        g_irgItemFuncId = ArrayCreate();
    }

    new iId = g_iItemsNum;
    ArrayPushString(g_irgItemTitle, szTitle);
    ArrayPushCell(g_irgItemiPluginId, iPluginId);
    ArrayPushCell(g_irgItemFuncId, iFunctionId);

    g_iItemsNum++;

    return iId;
}

public MenuHandler(pPlayer, iMenu, item) {
    menu_destroy(iMenu);

    if (item != MENU_EXIT) {
        new iPluginId = ArrayGetCell(g_irgItemiPluginId, item);
        new iFunctionId = ArrayGetCell(g_irgItemFuncId, item);

        if (callfunc_begin_i(iFunctionId, iPluginId) == 1) {
            callfunc_push_int(pPlayer);
            callfunc_end();
        }
    }

    return PLUGIN_HANDLED;
}
