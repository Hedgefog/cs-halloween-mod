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
	
	register_impulse(100, "OnImpulse_100");
	
	Hwn_Menu_AddItem("Cosmetic Inventory", "MenuItemCosmeticCallback");
}

public OnImpulse_100(id)
{
	Hwn_Spell_CastPlayerSpell(id);	
	return PLUGIN_HANDLED;
}

public MenuItemCosmeticCallback(id)
{
	PCosmetic_Menu_Open(id);
}