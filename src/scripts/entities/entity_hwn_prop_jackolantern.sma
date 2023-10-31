#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <reapi>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Prop Jack'O'Lantern"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_prop_jackolantern"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/props/jackolantern.mdl",
        .vecMins = Float:{-16.0, -16.0, 0.0},
        .vecMaxs = Float:{16.0, 16.0, 48.0},
        .iPreset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");
}

@Entity_Spawned(this) {
    set_pev(this, pev_body, random(2));

    engfunc(EngFunc_DropToFloor, this);

    if (~pev(this, pev_spawnflags) & BIT(0)) {
        set_pev(this, pev_nextthink, get_gametime());
    }
}

@Entity_Think(this) {
    static const iRadius = 8;

    new Float:flRate = Hwn_GetUpdateRate();
    new iLifeTime = min(floatround(flRate * 10), 1);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 16.0;

    UTIL_Message_Dlight(vecOrigin, iRadius, {64, 52, 4}, iLifeTime + 1, 0);

    set_pev(this, pev_nextthink, get_gametime() + flRate);
}
