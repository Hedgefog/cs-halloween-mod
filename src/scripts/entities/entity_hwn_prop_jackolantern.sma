#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Prop Jack'O'Lantern"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_prop_jackolantern"

new const g_szModel[] = "models/hwn/props/jackolantern.mdl";

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    precache_model(g_szModel);

    CE_Register(ENTITY_NAME, CEPreset_Prop);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");
}

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -16.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 16.0, 48.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel);
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

    static Float:flRate; flRate = Hwn_GetUpdateRate();
    static iLifeTime; iLifeTime = min(floatround(flRate * 10), 1);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 16.0;

    UTIL_Message_Dlight(vecOrigin, iRadius, {64, 52, 4}, iLifeTime + 1, 0);

    set_pev(this, pev_nextthink, get_gametime() + flRate);
}
