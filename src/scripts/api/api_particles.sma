#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>

#include <api_particles>

#define PLUGIN "[API] Particles"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define IsPlayer(%1) (1 <= %1 <= 32)

#define TASKID_SUM_TARGET_TICK 1000
#define TASKID_SUM_REMOVE_TARGET 2000
#define TASKID_SUM_REMOVE_PARTICLE 3000

new Trie:g_particles;
new Array:g_particlePluginID;
new Array:g_particleFuncID;
new Array:g_particleSprites;
new Array:g_particleLifeTime;
new Array:g_particleScale;
new Array:g_particleRenderMode;
new Array:g_particleRenderAmt;
new Array:g_particleSpawnCount;
new g_particleCount = 0;

new g_ptrTargetClassname;
new g_ptrParticleClassname;

new g_maxPlayers;

public plugin_precache()
{
    g_ptrTargetClassname = engfunc(EngFunc_AllocString, "info_target");
    g_ptrParticleClassname = engfunc(EngFunc_AllocString, "env_sprite");

    register_forward(FM_AddToFullPack, "OnAddToFullPack", 0);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    g_maxPlayers = get_maxplayers();
}

public plugin_end()
{
    if (g_particleCount) {
        TrieDestroy(g_particles);
        ArrayDestroy(g_particlePluginID);
        ArrayDestroy(g_particleFuncID);
        ArrayDestroy(g_particleSprites);
        ArrayDestroy(g_particleLifeTime);
        ArrayDestroy(g_particleScale);
        ArrayDestroy(g_particleRenderMode);
        ArrayDestroy(g_particleRenderAmt);
        ArrayDestroy(g_particleSpawnCount);
    }
}

public plugin_natives()
{
    register_library("api_particles");
    register_native("Particles_Register", "Native_Register");
    register_native("Particles_Spawn", "Native_Spawn");
    register_native("Particles_Remove", "Native_Remove");
}

public Native_Register(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new szTransformCallback[32];
    get_string(2, szTransformCallback, charsmax(szTransformCallback));
    new funcID = get_func_id(szTransformCallback, pluginID);

    new sprites[API_PARTICLES_MAX_SPRITES];
    get_array(3, sprites, sizeof(sprites));

    new Float:fLifeTime = get_param_f(4);
    new Float:fScale = get_param_f(5);
    new renderMode = get_param(6);
    new Float:fRenderAmt = get_param_f(7);
    new spawnCount = get_param(8);

    RegisterParticle(szName, pluginID, funcID, sprites, fLifeTime, fScale, renderMode, fRenderAmt, spawnCount);
}

public Native_Spawn(pluginID, argc)
{
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new Float:vOrigin[3];
    get_array_f(2, vOrigin, sizeof(vOrigin));

    new Float:fPlayTime = get_param_f(3);

    return SpawnParticles(szName, vOrigin, fPlayTime);
}

public Native_Remove(pluginID, argc)
{
    new ent = get_param(1);
    RemoveParticles(ent);
}


public OnAddToFullPack(es, e, ent, host, hostflags, player, pSet)
{
    if (!IsPlayer(host)) {
        return FMRES_IGNORED;
    }

    if (!is_user_connected(host)) {
        return FMRES_IGNORED;
    }

    if (!pev_valid(ent)) {
        return FMRES_IGNORED;
    }

    static szClassname[32];
    pev(ent, pev_classname, szClassname, charsmax(szClassname));

    if (equal(szClassname, "_particle")) {
        new owner = pev(ent, pev_owner);

        if (!owner || !pev_valid(owner)) {
            return FMRES_IGNORED;
        }

        if (pev(owner, pev_iuser3) & (1<<(host&31))) {
            return FMRES_IGNORED;
        }

        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

RegisterParticle(const szName[], pluginID, funcID, const sprites[API_PARTICLES_MAX_SPRITES], Float:fLifeTime, Float:fScale, renderMode, Float:fRenderAmt, spawnCount)
{
    if (!g_particleCount) {
        g_particles = TrieCreate();
        g_particlePluginID = ArrayCreate();
        g_particleFuncID = ArrayCreate();
        g_particleSprites = ArrayCreate(API_PARTICLES_MAX_SPRITES);
        g_particleLifeTime = ArrayCreate();
        g_particleScale = ArrayCreate();
        g_particleRenderMode = ArrayCreate();
        g_particleRenderAmt = ArrayCreate();
        g_particleSpawnCount = ArrayCreate();
    }

    new index = g_particleCount;

    TrieSetCell(g_particles, szName, index);
    ArrayPushCell(g_particlePluginID, pluginID);
    ArrayPushCell(g_particleFuncID, funcID);
    ArrayPushCell(g_particleLifeTime, fLifeTime);
    ArrayPushCell(g_particleScale, fScale);
    ArrayPushCell(g_particleRenderMode, renderMode);
    ArrayPushCell(g_particleRenderAmt, fRenderAmt);
    ArrayPushCell(g_particleSpawnCount, spawnCount);
    ArrayPushArray(g_particleSprites, sprites);

    g_particleCount++;

    return index;
}

SpawnParticles(const szName[], const Float:vOrigin[3], Float:fPlayTime)
{
    if (!g_particleCount) {
        return 0;
    }

    new index;
    if (!TrieGetCell(g_particles, szName, index)) {
        return 0;
    }

    new ent = engfunc(EngFunc_CreateNamedEntity, g_ptrTargetClassname);
    engfunc(EngFunc_SetOrigin, ent, vOrigin);
    dllfunc(DLLFunc_Spawn, ent);

    set_pev(ent, pev_iuser1, index);
    set_pev(ent, pev_iuser2, 0);
    set_pev(ent, pev_iuser3, 0);

    set_task(0.04, "TaskTargetTick", ent+TASKID_SUM_TARGET_TICK, _, _, "b");

    if (fPlayTime > 0.0) {
        set_task(fPlayTime, "TaskRemoveTarget", ent+TASKID_SUM_REMOVE_TARGET);
    }

    return ent;
}

RemoveParticles(ent)
{
    remove_task(ent+TASKID_SUM_TARGET_TICK);
    set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
    dllfunc(DLLFunc_Think, ent);
}

UpdateVisibleFlag(ent)
{   
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new playerVisibleFlags = 0;
    for (new id = 1; id <= g_maxPlayers; ++id) {
        if (!is_user_connected(id)) {
            continue;
        }

        if (!is_in_viewcone(id, vOrigin, 1)) {
            continue;
        }

        static Float:vPlayerOrigin[3];
        pev(id, pev_origin, vPlayerOrigin);
        vPlayerOrigin[2] += 16.0;

        engfunc(EngFunc_TraceLine, vPlayerOrigin, vOrigin, IGNORE_MONSTERS, id, 0);

        static Float:fFraction;
        get_tr2(0, TR_flFraction, fFraction);

        if (fFraction == 1.0) {
            playerVisibleFlags |= (1<<(id&31));
        }
    }

    set_pev(ent, pev_iuser3, playerVisibleFlags);
}

public TaskRemoveTarget(taskID)
{
    new ent = taskID - TASKID_SUM_REMOVE_TARGET;
    RemoveParticles(ent);
}

public TaskTargetTick(taskID)
{
    new ent = taskID - TASKID_SUM_TARGET_TICK;
    new index = pev(ent, pev_iuser1);
    new tickIndex = pev(ent, pev_iuser2);

    new pluginID = ArrayGetCell(g_particlePluginID, index);
    new funcID = ArrayGetCell(g_particleFuncID, index);
    new Float:fLifeTime = ArrayGetCell(g_particleLifeTime, index);
    new Float:fScale = ArrayGetCell(g_particleScale, index);
    new renderMode = ArrayGetCell(g_particleRenderMode, index);
    new Float:fRenderAmt = ArrayGetCell(g_particleRenderAmt, index);
    new spawnCount = ArrayGetCell(g_particleSpawnCount, index);

    static sprites[API_PARTICLES_MAX_SPRITES];
    ArrayGetArray(g_particleSprites, index, sprites);

    static Float:vOrigin[3];
    static Float:vVelocity[3];

    for (new i = 0; i < spawnCount; ++i)
    {
        pev(ent, pev_origin, vOrigin);
        xs_vec_set(vVelocity, 0.0, 0.0, 0.0);

        if (callfunc_begin_i(funcID, pluginID) == 1) {
            callfunc_push_array(_:vOrigin, 3);
            callfunc_push_array(_:vVelocity, 3);
            callfunc_push_int(ent);
            callfunc_push_int(tickIndex);
            callfunc_end();
        }

        static particleEnt;
        {
            particleEnt = engfunc(EngFunc_CreateNamedEntity, g_ptrParticleClassname);
            engfunc(EngFunc_SetOrigin, particleEnt, vOrigin);
            set_pev(particleEnt, pev_classname, "_particle");
            set_pev(particleEnt, pev_velocity, vVelocity);
            set_pev(particleEnt, pev_modelindex, sprites[random(strlen(sprites))]);
            set_pev(particleEnt, pev_solid, SOLID_TRIGGER);
            set_pev(particleEnt, pev_movetype, MOVETYPE_NOCLIP);
            set_pev(particleEnt, pev_rendermode, renderMode);
            set_pev(particleEnt, pev_renderamt, fRenderAmt);
            set_pev(particleEnt, pev_scale, fScale);
            set_pev(particleEnt, pev_owner, ent);

            set_task(fLifeTime, "TaskRemoveParticle", particleEnt+TASKID_SUM_REMOVE_PARTICLE);
        }
    }

    UpdateVisibleFlag(ent);

    set_pev(ent, pev_iuser2, tickIndex + 1);
}

public TaskRemoveParticle(taskID)
{
    new ent = taskID - TASKID_SUM_REMOVE_PARTICLE;
    set_pev(ent, pev_flags, pev(ent, pev_flags) | FL_KILLME);
    dllfunc(DLLFunc_Think, ent);
}