#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Entity] Projectile"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_base"

#define TouchDetonate "TouchDetonate"
#define TouchKill "TouchKill"
#define Detonate "Detonate"
#define Launch "Launch"
#define LaunchTo "LaunchTo"

public plugin_precache() {
    CE_Register(ENTITY_NAME);

    CE_RegisterHook(ENTITY_NAME, CEFunction_Touch, "@Entity_Touch");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Kill, "@Entity_Kill");

    CE_RegisterVirtualMethod(ENTITY_NAME, TouchDetonate, "@Entity_TouchDetonate", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, TouchKill, "@Entity_TouchKill", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, Detonate, "@Entity_Detonate", CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, Launch, "@Entity_Launch", CE_MP_FloatArray, 3);
    CE_RegisterVirtualMethod(ENTITY_NAME, LaunchTo, "@Entity_LaunchTo", CE_MP_FloatArray, 3, CE_MP_Float);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Kill(this, pKiller) {
    CE_CallMethod(this, TouchKill, pKiller);
}

@Entity_Touch(this, pToucher) {
    if (pToucher == pev(this, pev_owner)) return;
    if (pev(this, pev_deadflag) == DEAD_DEAD) return;
    if (pev(pToucher, pev_solid) <= SOLID_TRIGGER) return;

    CE_CallMethod(this, TouchDetonate, pToucher);
}

@Entity_TouchDetonate(this, pDetonator) {
    CE_Kill(this, pDetonator);
}

@Entity_TouchKill(this, pDetonator) {
    CE_CallMethod(this, Detonate, pDetonator);
}

@Entity_Detonate(this, pDetonator) {}

@Entity_Launch(this, const Float:vecVelocity[3]) {
    static Float:vecAngles[3]; vector_to_angle(vecVelocity, vecAngles);
    set_pev(this, pev_angles, vecAngles);    

    set_pev(this, pev_velocity, vecVelocity);
}

@Entity_LaunchTo(this, const Float:vecTarget[3], Float:flSpeed) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static Float:vecVelocity[3];
    xs_vec_sub(vecTarget, vecOrigin, vecVelocity);
    xs_vec_normalize(vecVelocity, vecVelocity);
    xs_vec_mul_scalar(vecVelocity, flSpeed, vecVelocity);

    CE_CallMethod(this, Launch, vecVelocity);
}
