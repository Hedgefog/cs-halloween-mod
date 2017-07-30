#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "Halloween Mod"
#define AUTHOR "Hedgehog Fog"

public plugin_init()
{
	register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{
	register_cvar("hwn_fps", "25");
	register_cvar("hwn_npc_fps", "25");
	register_cvar("hwn_enable_particles", "1");

	LoadConfig();
}

public plugin_natives()
{
	register_library("hwn");
}

LoadConfig()
{
	new szConfigDir[32];
	get_configsdir(szConfigDir, charsmax(szConfigDir));
	
	server_cmd("exec %s/hwn.cfg", szConfigDir);
	server_exec();
}