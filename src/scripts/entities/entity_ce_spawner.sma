#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#define PLUGIN "[Custom Entity] Spawner"
#define VERSION "1.1.2"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_SPAWN_ENTITY 0

#define ENTITY_NAME "ce_spawner"

new Array:g_spawners;
new Array:g_spawnerCE;
new Array:g_spawnerDelay;
new Array:g_spawnerImpulse;

new g_lastEnt;
new g_szLastCE[32];
new Float:g_fLastDelay;
new Float:g_fLastImpulse;

new g_spawnerCount = 0;

public plugin_precache()
{
    CE_Register(
        .szName = ENTITY_NAME
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_KVD, ENTITY_NAME, "OnKeyValue");
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_logevent("OnRoundStart", 2, "1=Round_Start");
}

public plugin_end()
{
    if (!g_spawnerCount) {
        return;
    }

    ArrayDestroy(g_spawners);
    ArrayDestroy(g_spawnerCE);
    ArrayDestroy(g_spawnerDelay);
    ArrayDestroy(g_spawnerImpulse);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
    if (pev(ent, pev_iuser1)) {
        return;
    }

    if (!g_spawnerCount) {
        g_spawners = ArrayCreate();
        g_spawnerCE = ArrayCreate(32);
        g_spawnerDelay = ArrayCreate();
        g_spawnerImpulse = ArrayCreate();
    }

    new index = g_spawnerCount;
    ArrayPushCell(g_spawners, ent);
    if (g_lastEnt == ent) {
        ArrayPushString(g_spawnerCE, g_szLastCE);
        ArrayPushCell(g_spawnerDelay, g_fLastDelay);
        ArrayPushCell(g_spawnerImpulse, g_fLastImpulse);
    } else {
        ArrayPushCell(g_spawnerCE, 0);
        ArrayPushCell(g_spawnerDelay, 0);
        ArrayPushCell(g_spawnerImpulse, 0);
    }

    set_pev(ent, pev_iuser1, index);

    g_spawnerCount++;
}

public OnRoundStart()
{
    if (!g_spawnerCount) {
        return;
    }

    for (new i = 0; i < g_spawnerCount; ++i) {
        new ent = ArrayGetCell(g_spawners, i);
        new idx = pev(ent, pev_iuser1);
        new Float:fDelay = ArrayGetCell(g_spawnerDelay, idx);

        remove_task(ent+TASKID_SUM_SPAWN_ENTITY);

        if (fDelay > 0.0) {
            set_task(fDelay, "TaskSpawnEntity", ent+TASKID_SUM_SPAWN_ENTITY, _, _, "b");
        }

        SpawnTarget(ent);
    }
}

public OnKeyValue(ent, const szKey[], const szValue[])
{
    //Reset props
    if (ent != g_lastEnt) {
        g_lastEnt = ent;
        g_szLastCE[0] = '^0';
        g_fLastDelay = 0.0;
        g_fLastImpulse = 0.0;
    }

    if (equal(szKey, "ce_name")) {
        copy(g_szLastCE, charsmax(g_szLastCE), szValue);
    } else if (equal(szKey, "impulse")) {
        g_fLastImpulse = str_to_float(szValue);
    } else if (equal(szKey, "delay")) {
        g_fLastDelay = str_to_float(szValue);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

SpawnTarget(ent)
{
    new idx = pev(ent, pev_iuser1);
    new bool:checkStucks = !(pev(ent, pev_spawnflags) & (1<<0));

    static szClassname[32];
    ArrayGetString(g_spawnerCE, idx, szClassname, charsmax(szClassname));

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vMins[3];
    static Float:vMaxs[3];
    CE_GetSize(szClassname, vMins, vMaxs);

    if (checkStucks && CanStuck(vOrigin, vMins, vMaxs)) {
        return;
    }

    new spawnedEnt = CE_Create(szClassname, vOrigin);
    if (!spawnedEnt) {
        return;
    }

    new Float:fImpulse = ArrayGetCell(g_spawnerImpulse, idx);

    if (fImpulse > 0.0) {
        static Float:vVelocity[3];
        vVelocity[0] = random_float(-fImpulse, fImpulse);
        vVelocity[1] = random_float(-fImpulse, fImpulse);
        vVelocity[2] = random_float(0.0, fImpulse/8);

        set_pev(spawnedEnt, pev_velocity, vVelocity);
    }

    static Float:vAngles[3];
    pev(ent, pev_angles, vAngles);
    set_pev(spawnedEnt, pev_angles, vAngles);

    dllfunc(DLLFunc_Spawn, spawnedEnt);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskSpawnEntity(taskID)
{
    new ent = taskID - TASKID_SUM_SPAWN_ENTITY;
    SpawnTarget(ent);
}

/*--------------------------------[ Stocks ]--------------------------------*/

stock CanStuck(const Float:vOrigin[3], const Float:vMins[3], const Float:vMaxs[3])
{
    new Float:vStart[3];
    xs_vec_copy(vOrigin, vStart);

    new Float:vEnd[3];
    xs_vec_copy(vOrigin, vEnd);

    for (new i = 0; i < 3; ++i) {
        if (i > 0) {
            vStart[i-1] = vOrigin[i-1];
            vEnd[i-1]    = vOrigin[i-1];
        }

        vStart[i] += vMins[i];
        vEnd[i] += vMaxs[i];

        engfunc(EngFunc_TraceLine, vStart, vEnd, DONT_IGNORE_MONSTERS, 0, 0);

        static Float:fFraction;
        get_tr2(0, TR_flFraction, fFraction);

        if (
            fFraction != 1.0
            || get_tr2(0, TR_StartSolid)
            || get_tr2(0, TR_AllSolid)
            || !get_tr2(0, TR_InOpen)
        )
        {
            return true;
        }
    }

    return false;
}