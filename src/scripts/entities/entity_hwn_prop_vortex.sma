#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Prop Vortex"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_prop_vortex"

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{    
    CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/props/vortex.mdl"),
        .vMins = Float:{-256.0, -256.0, -32.0},
        .vMaxs = Float:{256.0, 256.0, 32.0},
        .preset = CEPreset_Prop
    );
    
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
}

public OnSpawn(ent)
{
    set_pev(ent, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_framerate, 0.25);
    set_pev(ent, pev_rendermode, kRenderTransAdd);
    set_pev(ent, pev_renderamt, 255.0);
}