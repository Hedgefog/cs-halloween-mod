#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "Halloween Mod"
#define AUTHOR "Hedgehog Fog"

new g_fwConfigLoaded;

new g_pFpsCvar;
new g_pNpcFpsCvar;
new g_pCvarVersion;

new Float:g_flUpdateRate = 0.01;
new Float:g_flNpcUpdateRate = 0.01;

public plugin_precache() {
    g_pCvarVersion = register_cvar("hwn_version", HWN_VERSION, FCVAR_SERVER);
    g_pFpsCvar = register_cvar("hwn_fps", "25");
    g_pNpcFpsCvar = register_cvar("hwn_npc_fps", "25");

    hook_cvar_change(g_pFpsCvar, "CvarHook_Fps");
    hook_cvar_change(g_pNpcFpsCvar, "CvarHook_NpcFps");
    hook_cvar_change(g_pCvarVersion, "CvarHook_Version");

    register_cvar("hwn_enable_particles", "1");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_fwConfigLoaded = CreateMultiForward("Hwn_Fw_ConfigLoaded", ET_IGNORE);
}

public plugin_cfg() {
    LoadConfig();

    g_flUpdateRate = UTIL_FpsToDelay(get_pcvar_num(g_pFpsCvar));
    g_flNpcUpdateRate = UTIL_FpsToDelay(get_pcvar_num(g_pNpcFpsCvar));
}

public plugin_natives() {
    register_library("hwn");

    register_native("Hwn_GetUpdateRate", "Native_GetUpdateRate");
    register_native("Hwn_GetNpcUpdateRate", "Native_GetNpcUpdateRate");
}

public Float:Native_GetUpdateRate(iPluginId, iArgc) {
    return g_flUpdateRate;
}

public Float:Native_GetNpcUpdateRate(iPluginId, iArgc) {
    return g_flNpcUpdateRate;
}

public CvarHook_Version() {
    set_pcvar_string(g_pCvarVersion, HWN_VERSION);
}

public CvarHook_Fps(pCvar) {
    g_flUpdateRate = UTIL_FpsToDelay(get_pcvar_num(pCvar));
}

public CvarHook_NpcFps(pCvar) {
    g_flNpcUpdateRate = UTIL_FpsToDelay(get_pcvar_num(pCvar));
}

LoadConfig() {
    new szConfigDir[32];
    get_configsdir(szConfigDir, charsmax(szConfigDir));

    server_cmd("exec %s/hwn.cfg", szConfigDir);
    server_exec();
    
    ExecuteForward(g_fwConfigLoaded);
}
