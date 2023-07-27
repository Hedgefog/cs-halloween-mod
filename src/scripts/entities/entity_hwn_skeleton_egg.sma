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

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register(
        ENTITY_NAME,
        .vMins = Float:{-12.0, -12.0, -16.0},
        .vMaxs = Float:{12.0, 12.0, 16.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");

    CE_Register(
        ENTITY_NAME_BIG,
        .vMins = Float:{-12.0, -12.0, -32.0},
        .vMaxs = Float:{12.0, 12.0, 32.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_BIG, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_BIG, "OnRemove");
}

public OnSpawn(pEntity) {
    set_pev(pEntity, pev_solid, SOLID_NOT);
    set_pev(pEntity, pev_movetype, MOVETYPE_BOUNCE);

    set_task(2.0, "Birth", pEntity);
}

public OnRemove(pEntity) {
    remove_task(pEntity);
}

public Birth(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pSkeleton = CE_Create(
        IsBig(pEntity) ? "hwn_npc_skeleton" : "hwn_npc_skeleton_small",
        vecOrigin
    );

    if (pSkeleton) {
        set_pev(pSkeleton, pev_team, pev(pEntity, pev_team));
        set_pev(pSkeleton, pev_owner, pev(pEntity, pev_owner));
        dllfunc(DLLFunc_Spawn, pSkeleton);
    }

    CE_Kill(pEntity);

    if (UTIL_IsStuck(pSkeleton)) {
        CE_Kill(pSkeleton);
    }
}

bool:IsBig(pEntity) {
    return CE_GetHandlerByEntity(pEntity) == CE_GetHandler(ENTITY_NAME_BIG);
}
