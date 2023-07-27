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

new g_pCvarEnabled;
new g_pCvarPrice;
new g_pCvarPriceThrowable;
new g_pCvarPriceApplicable;
new g_pCvarPriceAbility;
new g_pCvarPriceHeal;
new g_pCvarPriceDamage;
new g_pCvarPriceRadius;
new g_pCvarPriceProtection;
new g_pCvarPriceMultRare;

new g_fwOpen;
new g_fwBuySpell;

public plugin_precache() {
    register_dictionary("hwn.txt");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarEnabled = register_cvar("hwn_spellshop", "1");

    g_pCvarPrice = register_cvar("hwn_spellshop_spell_price", "500");
    g_pCvarPriceMultRare = register_cvar("hwn_spellshop_spell_price_mult_rare", "1.5");
    g_pCvarPriceThrowable = register_cvar("hwn_spellshop_spell_price_throwable", "300");
    g_pCvarPriceApplicable = register_cvar("hwn_spellshop_spell_price_applicable", "150");
    g_pCvarPriceAbility = register_cvar("hwn_spellshop_spell_price_ability", "550");
    g_pCvarPriceHeal = register_cvar("hwn_spellshop_spell_price_heal", "600");
    g_pCvarPriceDamage = register_cvar("hwn_spellshop_spell_price_damage", "800");
    g_pCvarPriceRadius = register_cvar("hwn_spellshop_spell_price_radius", "650");
    g_pCvarPriceProtection = register_cvar("hwn_spellshop_spell_price_protection", "750");

    g_fwOpen = CreateMultiForward("Hwn_SpellShop_Fw_Open", ET_STOP, FP_CELL);
    g_fwBuySpell = CreateMultiForward("Hwn_SpellShop_Fw_BuySpell", ET_STOP, FP_CELL, FP_CELL);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_SpellShop_Open", "Native_Open");
    register_native("Hwn_SpellShop_BuySpell", "Native_BuySpell");
    register_native("Hwn_SpellShop_CanBuySpell", "Native_CanBuySpell");
    register_native("Hwn_SpellShop_GetSpellPrice", "Native_GetSpellPrice");
}

/*--------------------------------[ Natives ]--------------------------------*/

public bool:Native_Open(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    return Open(pPlayer);
}

public bool:Native_BuySpell(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSpell = get_param(2);

    return BuySpell(pPlayer, iSpell);
}

public bool:Native_CanBuySpell(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new iSpell = get_param(2);

    return CanBuySpell(pPlayer, iSpell);
}

public Native_GetSpellPrice(iPluginId, iArgc) {
    new iSpell = get_param(1);

    return GetSpellPrice(iSpell);
}

/*--------------------------------[ Methods ]--------------------------------*/

GetSpellPrice(iSpell) {
    new iPrice = get_pcvar_num(g_pCvarPrice);

    new Hwn_SpellFlags:spellFlags = Hwn_Spell_GetFlags(iSpell);

    if (spellFlags & Hwn_SpellFlag_Throwable) {
        iPrice += get_pcvar_num(g_pCvarPriceThrowable);
    }

    if (spellFlags & Hwn_SpellFlag_Applicable) {
        iPrice += get_pcvar_num(g_pCvarPriceApplicable);
    }

    if (spellFlags & Hwn_SpellFlag_Ability) {
        iPrice += get_pcvar_num(g_pCvarPriceAbility);
    }

    if (spellFlags & Hwn_SpellFlag_Heal) {
        iPrice += get_pcvar_num(g_pCvarPriceHeal);
    }

    if (spellFlags & Hwn_SpellFlag_Damage) {
        iPrice += get_pcvar_num(g_pCvarPriceDamage);
    }

    if (spellFlags & Hwn_SpellFlag_Radius) {
        iPrice += get_pcvar_num(g_pCvarPriceRadius);
    }

    if (spellFlags & Hwn_SpellFlag_Protection) {
        iPrice += get_pcvar_num(g_pCvarPriceProtection);
    }

    if (spellFlags & Hwn_SpellFlag_Rare) {
        iPrice = floatround(iPrice * get_pcvar_float(g_pCvarPriceMultRare));
    }

    return iPrice;
}

bool:CanBuySpell(pPlayer, iSpell) {
    if (!is_user_alive(pPlayer)) {
        return false;
    }

    new iPrice = GetSpellPrice(iSpell);

    if (cs_get_user_money(pPlayer) < iPrice) {
        return false;
    }

    return true;
}

bool:BuySpell(pPlayer, iSpell) {
    if (!CanBuySpell(pPlayer, iSpell)) {
        return false;
    }

    new iResult = 0;
    ExecuteForward(g_fwBuySpell, iResult, pPlayer, iSpell);
    if (iResult != PLUGIN_CONTINUE) {
        return false;
    }

    new iPrice = GetSpellPrice(iSpell);
    new iSpellAmount = 0;
    new iPlayerSpell = Hwn_Spell_GetPlayerSpell(pPlayer, iSpellAmount);

    iSpellAmount = iSpell == iPlayerSpell ? iSpellAmount + 1 : 1;

    if (iSpell != iPlayerSpell) {
        DropPlayerSpell(pPlayer);
    }

    new iMoney = cs_get_user_money(pPlayer);
    cs_set_user_money(pPlayer, iMoney - iPrice);
    Hwn_Spell_SetPlayerSpell(pPlayer, iSpell, iSpellAmount);

    return true;
}

DropPlayerSpell(pPlayer) {
    new iSpellAmount = 0;
    new iSpell = Hwn_Spell_GetPlayerSpell(pPlayer, iSpellAmount);

    if (iSpell == -1) {
        return;
    }

    static Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    new pEntity = CE_Create("hwn_item_spellbook", vecOrigin);
    set_pev(pEntity, pev_iuser1, iSpell);
    set_pev(pEntity, pev_iuser2, iSpellAmount);

    if (pEntity) {
        dllfunc(DLLFunc_Spawn, pEntity);
    }

    static Float:vecVelocity[3];
    UTIL_GetDirectionVector(pPlayer, vecVelocity, 250.0);
    set_pev(pEntity, pev_velocity, vecVelocity);
}

bool:Open(pPlayer)  {
    if (!is_user_alive(pPlayer)) {
        return false;
    }

    if (!get_pcvar_num(g_pCvarEnabled)) {
        client_print(pPlayer, print_center, "%L", pPlayer, "HWN_SPELLSHOP_DISABLED");
        return false;
    }

    new iResult = 0;
    ExecuteForward(g_fwOpen, iResult, pPlayer);
    if (iResult != PLUGIN_CONTINUE) {
        return false;
    }

    new iMenu = CreateMenu(pPlayer);
    menu_display(pPlayer, iMenu);

    return true;
}

CreateMenu(pPlayer) {
    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L\RCost", pPlayer, "HWN_SPELLSHOP_MENU_TITLE");

    new iCallback = menu_makecallback("MenuCallback");
    new iMenu = menu_create(szMenuTitle, "MenuHandler");

    new iNum = Hwn_Spell_GetCount();
    for (new iSpell = 0; iSpell < iNum; ++iSpell) {
        static szSpellName[128];
        Hwn_Spell_GetDictionaryKey(iSpell, szSpellName, charsmax(szSpellName));

        new iPrice = GetSpellPrice(iSpell);
      
        static szText[128];
        format(szText, charsmax(szText), "%L\R\y$%d", pPlayer, szSpellName, iPrice);

        menu_additem(iMenu, szText, .callback = iCallback);
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    return iMenu;
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler(pPlayer, iMenu, item, page) {
    if (item != MENU_EXIT) {
        new iSpell = item * (page + 1);
        BuySpell(pPlayer, iSpell);
    }

    menu_destroy(iMenu);

    return PLUGIN_HANDLED;
}

public MenuCallback(pPlayer, iMenu, item) {
    new iSpell = item;
    return CanBuySpell(pPlayer, iSpell) ? ITEM_ENABLED : ITEM_DISABLED;
}
