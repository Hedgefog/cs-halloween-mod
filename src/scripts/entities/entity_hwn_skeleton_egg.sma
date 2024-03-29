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
#define ENTITY_NAME_BIG "hwn_skeleton_egg_big"

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

    CE_Register(
        .szName = ENTITY_NAME_BIG,
        .vMins = Float:{-12.0, -12.0, -32.0},
        .vMaxs = Float:{12.0, 12.0, 32.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_BIG, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_BIG, "OnRemove");
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

    new skeletonEnt = CE_Create(
        IsBig(ent) ? "hwn_npc_skeleton" : "hwn_npc_skeleton_small",
        vOrigin
    );

    if (skeletonEnt) {
        set_pev(skeletonEnt, pev_team, pev(ent, pev_team));
        set_pev(skeletonEnt, pev_owner, pev(ent, pev_owner));
        dllfunc(DLLFunc_Spawn, skeletonEnt);
    }

    CE_Kill(ent);

    if (UTIL_IsStuck(skeletonEnt)) {
        CE_Kill(skeletonEnt);
    }
}

bool:IsBig(ent) {
    return CE_GetHandlerByEntity(ent) == CE_GetHandler(ENTITY_NAME_BIG);
}
