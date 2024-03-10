#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_custom_entities>

#define PLUGIN "[Custom Entity] Hwn Pumpkin Dispenser"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define m_flImpulse "flImpulse"
#define m_flDelay "flDelay"

#define ENTITY_NAME "hwn_pumpkin_dispenser"
#define LOOT_ENTITY_CLASSNAME "hwn_item_pumpkin"

#define DROP_ACCURACY 0.128

public plugin_precache() {
    CE_Register(ENTITY_NAME);

    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_RegisterKeyMemberBinding(ENTITY_NAME, "impulse", m_flImpulse, CEMemberType_Float);
    CE_RegisterKeyMemberBinding(ENTITY_NAME, "delay", m_flDelay, CEMemberType_Float);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

@Entity_Spawned(this) {
    if (!CE_HasMember(this, m_flImpulse)) {
        CE_SetMember(this, m_flImpulse, 0.0);
    }

    if (!CE_HasMember(this, m_flDelay)) {
        CE_SetMember(this, m_flDelay, 1.0);
    }

    set_pev(this, pev_nextthink, get_gametime() + Float:CE_GetMember(this, m_flDelay));
}

@Entity_Think(this) {
    @Entity_Drop(this);
    set_pev(this, pev_nextthink, get_gametime() + Float:CE_GetMember(this, m_flDelay));
}

@Entity_Drop(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pPumpkin = CE_Create(LOOT_ENTITY_CLASSNAME, vecOrigin);
    if (!pPumpkin) return;

    new Float:flImpulse = CE_GetMember(this, m_flImpulse);
    if (flImpulse > 0.0) {
        static Float:vecVelocity[3];

        if (~pev(this, pev_spawnflags) & (1<<1)) {
            vecVelocity[0] = random_float(-1.0, 1.0);
            vecVelocity[1] = random_float(-1.0, 1.0);

            xs_vec_normalize(vecVelocity, vecVelocity);
            xs_vec_mul_scalar(vecVelocity, flImpulse, vecVelocity);
        } else {
            pev(this, pev_angles, vecVelocity);

            angle_vector(vecVelocity, ANGLEVECTOR_FORWARD, vecVelocity);
            xs_vec_mul_scalar(vecVelocity, flImpulse, vecVelocity);
        }

        new Float:flAbsErr = flImpulse * DROP_ACCURACY;
        for (new i = 0; i < 2; ++i) {
            vecVelocity[i] += random_float(-flAbsErr, flAbsErr);
        }

        set_pev(pPumpkin, pev_velocity, vecVelocity);
    }

    dllfunc(DLLFunc_Spawn, pPumpkin);
}
