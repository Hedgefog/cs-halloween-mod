#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <reapi>

#include <api_rounds>
#include <menu_player_cosmetic>

#include <hwn>

#define PLUGIN "[Hwn] Controlls"
#define AUTHOR "Hedgehog Fog"

new g_iPlayerTeamMenuOverrideFlags;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_dictionary("hwn.txt");

    register_clcmd("chooseteam", "Command_ChooseTeam");
    register_clcmd("drop", "Command_Drop");
    register_clcmd("buyequip", "Command_SpellsShop");
    register_clcmd("hwn_spells_shop_menu", "Command_SpellsShop");

    register_impulse(100, "OnImpulse_100");

    new szCosmeticMenuTitle[32];
    format(szCosmeticMenuTitle, charsmax(szCosmeticMenuTitle), "%L", LANG_SERVER, "HWN_COSMETIC_MENU_TITLE");
    Hwn_Menu_AddItem(szCosmeticMenuTitle, "MenuItemCosmeticCallback");

    new szChooseTeamText[32];
    format(szChooseTeamText, charsmax(szChooseTeamText), "%L", LANG_SERVER, "TEAM_MENU");
    Hwn_Menu_AddItem(szChooseTeamText, "ChooseTeam");
}

public client_putinserver(pPlayer) {
    g_iPlayerTeamMenuOverrideFlags |= BIT(pPlayer & 31);
}

public Command_ChooseTeam(pPlayer) {
    if (g_iPlayerTeamMenuOverrideFlags & BIT(pPlayer & 31)) {
        Hwn_Menu_Open(pPlayer);
        return PLUGIN_HANDLED;
    }

    g_iPlayerTeamMenuOverrideFlags |= BIT(pPlayer & 31);
    return PLUGIN_CONTINUE;
}

public Command_Drop(pPlayer) {
    new Hwn_GamemodeFlags:iFlags = Hwn_Gamemode_GetFlags();
    if (!(iFlags & Hwn_GamemodeFlag_SpecialEquip)) {
        return PLUGIN_CONTINUE;
    }

    Hwn_PEquipment_ShowMenu(pPlayer);

    return PLUGIN_HANDLED;
}

public Command_SpellsShop(pPlayer) {
    new Hwn_GamemodeFlags:iFlags = Hwn_Gamemode_GetFlags();
    if (!(iFlags & Hwn_GamemodeFlag_SpellShop)) {
        return PLUGIN_CONTINUE;
    }

    Hwn_SpellShop_Open(pPlayer);

    return PLUGIN_HANDLED;
}

public OnImpulse_100(pPlayer) {
    if (!Round_IsRoundStarted()) {
        return PLUGIN_HANDLED;
    }

    Hwn_Spell_CastPlayerSpell(pPlayer);

    return PLUGIN_HANDLED;
}

public ChooseTeam(pPlayer) {
    g_iPlayerTeamMenuOverrideFlags &= ~BIT(pPlayer & 31);
    client_cmd(pPlayer, "chooseteam");
}

public MenuItemCosmeticCallback(pPlayer) {
    PCosmetic_Menu_Open(pPlayer);
}
