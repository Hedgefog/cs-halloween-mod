#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Gift Target"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_gift_target"

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{
    CE_Register(
        .szName = ENTITY_NAME
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
}

public OnSpawn(ent)
{
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    Hwn_Gifts_AddTarget(vOrigin);
    CE_Remove(ent);
}
