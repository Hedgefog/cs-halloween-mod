#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>

#define ENTITY_NAME "hwn_boss_target"

#define PLUGIN "[Custom Entity] Hwn Boss Target"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register(ENTITY_NAME, .vecMins = Float:{-48.0, -48.0, -48.0}, .vecMaxs = Float:{48.0, 48.0, 48.0});
    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
}

@Entity_Spawned(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    Hwn_Bosses_AddTarget(vecOrigin);
    CE_Remove(this);
}
