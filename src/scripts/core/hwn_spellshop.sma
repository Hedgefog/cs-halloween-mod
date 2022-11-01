#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <cstrike>
#include <xs>

#include <hwn>
#include <hwn_utils>
#include <api_custom_entities>

#define PLUGIN "[Hwn] Spell Shop"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

new g_cvarEnabled;
new g_cvarPrice;
new g_cvarPriceThrowable;
new g_cvarPriceApplicable;
new g_cvarPriceAbility;
new g_cvarPriceHeal;
new g_cvarPriceDamage;
new g_cvarPriceRadius;
new g_cvarPriceProtection;
new g_cvarPriceMultRare;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_cvarEnabled = register_cvar("hwn_spellshop", "1");

    g_cvarPrice = register_cvar("hwn_spellshop_spell_price", "500");
    g_cvarPriceMultRare = register_cvar("hwn_spellshop_spell_price_mult_rare", "1.5");
    g_cvarPriceThrowable = register_cvar("hwn_spellshop_spell_price_throwable", "300");
    g_cvarPriceApplicable = register_cvar("hwn_spellshop_spell_price_applicable", "150");
    g_cvarPriceAbility = register_cvar("hwn_spellshop_spell_price_ability", "550");
    g_cvarPriceHeal = register_cvar("hwn_spellshop_spell_price_heal", "600");
    g_cvarPriceDamage = register_cvar("hwn_spellshop_spell_price_damage", "800");
    g_cvarPriceRadius = register_cvar("hwn_spellshop_spell_price_radius", "650");
    g_cvarPriceProtection = register_cvar("hwn_spellshop_spell_price_protection", "750");
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_SpellShop_Open", "Native_Open");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Open(pluginID, argc)
{
    new id = get_param(1);
    Open(id);
}

/*--------------------------------[ Methods ]--------------------------------*/

GetSpellPrice(spell) {
    new price = get_pcvar_num(g_cvarPrice);

    new Hwn_SpellFlags:spellFlags = Hwn_Spell_GetFlags(spell);

    if (spellFlags & Hwn_SpellFlag_Throwable) {
        price += get_pcvar_num(g_cvarPriceThrowable);
    }

    if (spellFlags & Hwn_SpellFlag_Applicable) {
        price += get_pcvar_num(g_cvarPriceApplicable);
    }

    if (spellFlags & Hwn_SpellFlag_Ability) {
        price += get_pcvar_num(g_cvarPriceAbility);
    }

    if (spellFlags & Hwn_SpellFlag_Heal) {
        price += get_pcvar_num(g_cvarPriceHeal);
    }

    if (spellFlags & Hwn_SpellFlag_Damage) {
        price += get_pcvar_num(g_cvarPriceDamage);
    }

    if (spellFlags & Hwn_SpellFlag_Radius) {
        price += get_pcvar_num(g_cvarPriceRadius);
    }

    if (spellFlags & Hwn_SpellFlag_Protection) {
        price += get_pcvar_num(g_cvarPriceProtection);
    }

    if (spellFlags & Hwn_SpellFlag_Rare) {
        price = floatround(price * get_pcvar_float(g_cvarPriceMultRare));
    }

    return price;
}

bool:CanBuySpell(id, spell) {
    new price = GetSpellPrice(spell);

    if (!Hwn_Gamemode_IsPlayerOnSpawn(id)) {
        return false;
    }

    if (cs_get_user_money(id) < price) {
        return false;
    }

    return true;
}

DropPlayerSpell(id) {
    new spellAmount = 0;
    new spell = Hwn_Spell_GetPlayerSpell(id, spellAmount);

    if (spell == -1) {
        return;
    }

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    new ent = CE_Create("hwn_item_spellbook", vOrigin);
    set_pev(ent, pev_iuser1, spell);
    set_pev(ent, pev_iuser2, spellAmount);

    if (ent) {
        dllfunc(DLLFunc_Spawn, ent);
    }

    static Float:vVelocity[3];
    UTIL_GetDirectionVector(id, vVelocity, 250.0);
    set_pev(ent, pev_velocity, vVelocity);
}

Open(id) 
{
    if (!get_pcvar_num(g_cvarEnabled)) {
        client_print(id, print_center, "Spell shop is disabled on this server!");
        return;
    }

    if (!Hwn_Gamemode_IsPlayerOnSpawn(id)) {
        client_print(id, print_center, "Spell shop is only available at the spawn!");
        return;
    }

    new menu = CreateMenu(id);
    menu_display(id, menu);
}

CreateMenu(id)
{
    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L\RCost", id, "HWN_SPELLSHOP_MENU_TITLE");

    new callback = menu_makecallback("MenuCallback");
    new menu = menu_create(szMenuTitle, "MenuHandler");

    new count = Hwn_Spell_GetCount();
    for (new spell = 0; spell < count; ++spell) {
        static szSpellName[128];
        Hwn_Spell_GetDictionaryKey(spell, szSpellName, charsmax(szSpellName));

        new price = GetSpellPrice(spell);
      
        static szText[32];
        format(szText, charsmax(szText), "%L\R\y$%d", id, szSpellName, price);

        menu_additem(menu, szText, .callback = callback);
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);

    return menu;
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler(id, menu, item, page)
{
    if (item != MENU_EXIT)
    {
        new spell = item * (page + 1);
        if (!CanBuySpell(id, spell)) {
            return PLUGIN_HANDLED;
        }

        new price = GetSpellPrice(spell);
        new spellAmount = 0;
        new currentSpell = Hwn_Spell_GetPlayerSpell(id, spellAmount);

        spellAmount = spell == currentSpell ? spellAmount + 1 : 1;

        if (spell != currentSpell) {
            DropPlayerSpell(id);
        }

        new money = cs_get_user_money(id);
        cs_set_user_money(id, money - price);
        Hwn_Spell_SetPlayerSpell(id, spell, spellAmount);
    }

    menu_destroy(menu);

    return PLUGIN_HANDLED;
}

public MenuCallback(id, menu, item)
{
    new spell = item;
    return CanBuySpell(id, spell) ? ITEM_ENABLED : ITEM_DISABLED;
}
