#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>

#include <menu_player_cosmetic>

#include <hwn>

#define PLUGIN "[Hwn] Controlls"
#define AUTHOR "Hedgehog Fog"

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_dictionary("hwn.txt");

    register_impulse(100, "OnImpulse_100");

    new szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", LANG_SERVER, "HWN_COSMETIC_MENU_TITLE");
    Hwn_Menu_AddItem(szMenuTitle, "MenuItemCosmeticCallback");
}

public OnImpulse_100(id)
{
    if (!Hwn_Gamemode_IsRoundStarted()) {
        return PLUGIN_HANDLED;
    }

    Hwn_Spell_CastPlayerSpell(id);

    return PLUGIN_HANDLED;
}

public MenuItemCosmeticCallback(id)
{
    PCosmetic_Menu_Open(id);
}