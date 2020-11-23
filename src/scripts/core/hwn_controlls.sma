#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>

#include <menu_player_cosmetic>

#include <hwn>

#define PLUGIN "[Hwn] Controlls"
#define AUTHOR "Hedgehog Fog"

new g_chooseTeamOverride;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_dictionary("hwn.txt");

    register_clcmd("chooseteam", "OnClCmd_ChooseTeam");
    register_impulse(100, "OnImpulse_100");

    new szChooseTeamText[32];
    format(szChooseTeamText, charsmax(szChooseTeamText), "%L", LANG_SERVER, "TEAM_MENU");
    Hwn_Menu_AddItem(szChooseTeamText, "ChooseTeam");

    new szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", LANG_SERVER, "HWN_COSMETIC_MENU_TITLE");
    Hwn_Menu_AddItem(szMenuTitle, "MenuItemCosmeticCallback");
}

public client_putinserver(id)
{
    g_chooseTeamOverride |= (1<<(id&31));
}

public OnClCmd_ChooseTeam(id)
{
    if (g_chooseTeamOverride & (1<<(id&31))) {
        Hwn_Menu_Open(id);
        return PLUGIN_HANDLED;
    }

    g_chooseTeamOverride |= (1<<(id&31));
    return PLUGIN_CONTINUE;
}

public OnImpulse_100(id)
{
    if (!Hwn_Gamemode_IsRoundStarted()) {
        return PLUGIN_HANDLED;
    }

    Hwn_Spell_CastPlayerSpell(id);

    return PLUGIN_HANDLED;
}

public ChooseTeam(id)
{
    g_chooseTeamOverride &= ~(1<<(id&31));
    client_cmd(id, "chooseteam");
}

public MenuItemCosmeticCallback(id)
{
    PCosmetic_Menu_Open(id);
}
