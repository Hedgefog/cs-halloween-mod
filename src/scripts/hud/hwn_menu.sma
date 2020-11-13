#include <amxmodx>

#include <hwn>

#define PLUGIN "[Hwn] Menu"
#define AUTHOR "Hedgehog Fog"

new Array:g_itemTitle;
new Array:g_itemPluginID;
new Array:g_itemFuncID;
new g_itemCount = 0;

new bool:g_update = false;

new g_chooseTeamOverride;
new g_menu;

static g_szMenuTitle[32];

public plugin_init()
{
    register_dictionary("hwn.txt");
    register_dictionary("plmenu.txt");

    new pluginID = register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    register_clcmd("chooseteam", "OnClCmd_ChooseTeam");
    register_clcmd("hwn_menu", "OnClCmd_Menu");

    format(g_szMenuTitle, charsmax(g_szMenuTitle), "%L", LANG_SERVER, "HWN_MENU_TITLE");

    {
        new szChooseTeamText[32];
        format(szChooseTeamText, charsmax(szChooseTeamText), "%L", LANG_SERVER, "TEAM_MENU");
        AddItem(szChooseTeamText, pluginID, get_func_id("ChooseTeam", pluginID));
    }
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Menu_AddItem", "Native_AddItem");
}

public plugin_end()
{
    if (g_itemCount) {
        ArrayDestroy(g_itemTitle);
        ArrayDestroy(g_itemPluginID);
        ArrayDestroy(g_itemFuncID);
    }
}

public client_putinserver(id)
{
    g_chooseTeamOverride |= (1<<(id&31));
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_AddItem(pluginID, argc)
{
    new szTitle[32];
    get_string(1, szTitle, charsmax(szTitle));

    new szCallback[32];
    get_string(2, szCallback, charsmax(szCallback));

    return AddItem(szTitle, pluginID, get_func_id(szCallback, pluginID));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnClCmd_ChooseTeam(id)
{
    if (g_chooseTeamOverride & (1<<(id&31))) {
        ShowMenu(id);
        return PLUGIN_HANDLED;
    }

    g_chooseTeamOverride |= (1<<(id&31));
    return PLUGIN_CONTINUE;
}

public OnClCmd_Menu(id)
{
    ShowMenu(id);
    return PLUGIN_HANDLED;
}

/*--------------------------------[ Methods ]--------------------------------*/

public ChooseTeam(id)
{
    g_chooseTeamOverride &= ~(1<<(id&31));
    client_cmd(id, "chooseteam");
}

CreateMenu()
{
    g_menu = menu_create(g_szMenuTitle, "MenuHandler");

    for (new i = 0; i < g_itemCount; ++i) {
        static szTitle[32];
        ArrayGetString(g_itemTitle, i, szTitle, charsmax(szTitle));

        menu_additem(g_menu, szTitle);
    }

    menu_setprop(g_menu, MPROP_EXIT, MEXIT_ALL);

    g_update = false;
}

AddItem(const szTitle[], pluginID, funcID)
{
    if (!g_itemCount) {
        g_itemTitle = ArrayCreate(32);
        g_itemPluginID = ArrayCreate();
        g_itemFuncID = ArrayCreate();
    }

    new index = g_itemCount;
    ArrayPushString(g_itemTitle, szTitle);
    ArrayPushCell(g_itemPluginID, pluginID);
    ArrayPushCell(g_itemFuncID, funcID);

    g_itemCount++;

    g_update = true;

    return index;
}

ShowMenu(id)
{
    if (g_update)
    {
        if (g_menu) {
            menu_destroy(g_menu);
        }

        CreateMenu();
    }

    menu_display(id, g_menu);
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler(id, menu, item)
{
    if (is_user_connected(id)) {
        menu_cancel(id);
    }

    if (item != MENU_EXIT)
    {
        new pluginID = ArrayGetCell(g_itemPluginID, item);
        new funcID = ArrayGetCell(g_itemFuncID, item);

        if (callfunc_begin_i(funcID, pluginID) == 1) {
            callfunc_push_int(id);
            callfunc_end();
        }
    }

    return PLUGIN_HANDLED;
}