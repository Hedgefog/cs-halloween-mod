#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <hwn>

#define PLUGIN "[Hwn] Game Name"
#define AUTHOR "Hedgehog Fog"

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    register_forward(FM_GetGameDescription, "OnGetGameDescription");
}

public OnGetGameDescription()
{
    static szGameName[32];
    format(szGameName, charsmax(szGameName), "%s %s", HWN_TITLE, HWN_VERSION);
    forward_return(FMV_STRING, szGameName);
    return FMRES_SUPERCEDE;
}