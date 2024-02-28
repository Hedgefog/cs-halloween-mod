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

new const g_szModel[] = "models/hwn/props/vortex.mdl";

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    precache_model(g_szModel);

    CE_Register(ENTITY_NAME, CEPreset_Prop);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
}

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-256.0, -256.0, -32.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{256.0, 256.0, 32.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel);
}

@Entity_Spawned(this) {
    set_pev(this, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(this, pev_solid, SOLID_NOT);
    set_pev(this, pev_framerate, 0.25);
    set_pev(this, pev_rendermode, kRenderTransAdd);
    set_pev(this, pev_renderamt, 255.0);
}
