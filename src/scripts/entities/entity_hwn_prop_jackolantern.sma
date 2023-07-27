#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Prop Jack'O'Lantern"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_prop_jackolantern"

new Float:g_flThinkDelay;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/props/jackolantern.mdl"),
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 48.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
}

public Hwn_Fw_ConfigLoaded() {
    g_flThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

public OnSpawn(pEntity) {
    set_pev(pEntity, pev_body, random(2));
    engfunc(EngFunc_DropToFloor, pEntity);
    dllfunc(DLLFunc_Think, pEntity);

    if (~pev(pEntity, pev_spawnflags) & (1<<0)) {
        Task_Think(pEntity);
    }
}

public OnRemove(pEntity) {
    remove_task(pEntity);
}

public Task_Think(pEntity) {
    if (!pev_valid(pEntity)) {
        return;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    vecOrigin[2] += 16.0;

    UTIL_Message_Dlight(vecOrigin, 8, {64, 52, 4}, UTIL_DelayToLifeTime(g_flThinkDelay), 0);

    set_task(g_flThinkDelay, "Task_Think", pEntity);
}
