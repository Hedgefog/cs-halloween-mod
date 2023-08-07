#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <api_custom_entities>

#include <hwn>
#include <hwn_gifts>

#define PLUGIN "[Custom Entity] Hwn Gift Target"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_gift_target"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register(ENTITY_NAME);
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
}

@Entity_Spawn(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    Hwn_Gifts_AddTarget(vecOrigin);
    CE_Remove(this);
}
