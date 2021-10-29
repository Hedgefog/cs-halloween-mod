#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Skeleton Egg"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_skeleton_egg"

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{
    CE_Register(
        .szName = ENTITY_NAME,
        .vMins = Float:{-12.0, -12.0, -16.0},
        .vMaxs = Float:{12.0, 12.0, 16.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
}

public OnSpawn(ent)
{
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_movetype, MOVETYPE_BOUNCE);

    set_task(2.0, "Birth", ent);
}

public OnRemove(ent)
{
    remove_task(ent);
}

public Birth(ent)
{
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new skeletonEnt = CE_Create("hwn_npc_skeleton_small", vOrigin);
    if (skeletonEnt) {
        dllfunc(DLLFunc_Spawn, skeletonEnt);
    }

    CE_Kill(ent);

    if (UTIL_IsStuck(skeletonEnt)) {
        CE_Kill(skeletonEnt);
    }
}