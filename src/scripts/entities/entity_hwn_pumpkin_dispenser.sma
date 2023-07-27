#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_rounds>
#include <api_custom_entities>

#define PLUGIN "[Custom Entity] Hwn Pumpkin Dispenser"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_DROP 0

#define ENTITY_NAME "hwn_pumpkin_dispenser"
#define LOOT_ENTITY_CLASSNAME "hwn_item_pumpkin"

#define DROP_ACCURACY 0.128

new Array:g_dispensers;
new Array:g_dispenserDelay;
new Array:g_dispenserImpulse;

new g_pLast;
new Float:g_flLastDelay;
new Float:g_flLastImpulse;

new g_iDispensersNum = 0;

public plugin_precache() {
    CE_Register(
        ENTITY_NAME
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_KVD, ENTITY_NAME, "OnKeyValue");
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

public plugin_end() {
    if (!g_iDispensersNum) {
        return;
    }

    ArrayDestroy(g_dispensers);
    ArrayDestroy(g_dispenserDelay);
    ArrayDestroy(g_dispenserImpulse);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Round_Fw_RoundStart() {
    if (!g_iDispensersNum) {
        return;
    }

    for (new i = 0; i < g_iDispensersNum; ++i) {
        new pEntity = ArrayGetCell(g_dispensers, i);
        new iIdx = pev(pEntity, pev_iuser1);
        new Float:flDelay = ArrayGetCell(g_dispenserDelay, iIdx);

        remove_task(pEntity+TASKID_SUM_DROP);

        if (flDelay > 0.0) {
            set_task(flDelay, "Task_Drop", pEntity+TASKID_SUM_DROP, _, _, "b");
        } else {
            Drop(pEntity);
        }
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(pEntity) {
    if (pev(pEntity, pev_iuser1)) {
        return;
    }

    if (!g_iDispensersNum) {
        g_dispensers = ArrayCreate();
        g_dispenserDelay = ArrayCreate();
        g_dispenserImpulse = ArrayCreate();
    }

    new index = g_iDispensersNum;
    ArrayPushCell(g_dispensers, pEntity);
    if (g_pLast == pEntity) {
        ArrayPushCell(g_dispenserDelay, g_flLastDelay);
        ArrayPushCell(g_dispenserImpulse, g_flLastImpulse);
    } else {
        ArrayPushCell(g_dispenserDelay, 0);
        ArrayPushCell(g_dispenserImpulse, 0);
    }

    set_pev(pEntity, pev_iuser1, index);

    g_iDispensersNum++;
}

public OnKeyValue(pEntity, const szKey[], const szValue[]) {
    //Reset props
    if (pEntity != g_pLast) {
        g_pLast = pEntity;
        g_flLastDelay = 0.0;
        g_flLastImpulse = 0.0;
    }

    if (equal(szKey, "impulse")) {
        g_flLastImpulse = str_to_float(szValue);
    } else if (equal(szKey, "delay")) {
        g_flLastDelay = str_to_float(szValue);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

Drop(pEntity) {
    new idx = pev(pEntity, pev_iuser1);

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pSpawned = CE_Create(LOOT_ENTITY_CLASSNAME, vecOrigin);
    if (!pSpawned) {
        return;
    }

    new Float:flImpulse = ArrayGetCell(g_dispenserImpulse, idx);
    if (flImpulse > 0.0) {
        static Float:vecVelocity[3];

        if (~pev(pEntity, pev_spawnflags) & (1<<1)) {
            vecVelocity[0] = random_float(-1.0, 1.0);
            vecVelocity[1] = random_float(-1.0, 1.0);

            xs_vec_normalize(vecVelocity, vecVelocity);
            xs_vec_mul_scalar(vecVelocity, flImpulse, vecVelocity);
        } else {
            pev(pEntity, pev_angles, vecVelocity);
            angle_vector(vecVelocity, ANGLEVECTOR_FORWARD, vecVelocity);
            xs_vec_mul_scalar(vecVelocity, flImpulse, vecVelocity);
        }

        new Float:flAbsErr = flImpulse * DROP_ACCURACY;
        for (new i = 0; i < 2; ++i) {
            vecVelocity[i] += random_float(-flAbsErr, flAbsErr);
        }

        set_pev(pSpawned, pev_velocity, vecVelocity);
    }

    dllfunc(DLLFunc_Spawn, pSpawned);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Drop(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_DROP;
    Drop(pEntity);
}