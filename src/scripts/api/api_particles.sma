#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <reapi>
#include <xs>

#include <api_particles>

#define PLUGIN "[API] Particles"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define TASKID_SUM_TARGET_TICK 1000
#define TASKID_SUM_REMOVE_TARGET 2000
#define TASKID_SUM_REMOVE_PARTICLE 3000

const Float:MaxVisibleDistance = 2048.0;

new Trie:g_itParticles;
new Array:g_irgParticlePluginId;
new Array:g_irgParticleFuncId;
new Array:g_irgParticleSprites;
new Array:g_irgParticleLifeTime;
new Array:g_irgParticleScale;
new Array:g_irgParticleRenderMode;
new Array:g_irgParticleRenderAmt;
new Array:g_irgParticleSpawnsNum;
new g_iParticlesNum = 0;

new g_iszTargetClassname;
new g_iszParticleClassname;

public plugin_precache() {
    g_iszTargetClassname = engfunc(EngFunc_AllocString, "info_target");
    g_iszParticleClassname = engfunc(EngFunc_AllocString, "env_sprite");

    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack", 0);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

}

public plugin_end() {
    if (g_iParticlesNum) {
        TrieDestroy(g_itParticles);
        ArrayDestroy(g_irgParticlePluginId);
        ArrayDestroy(g_irgParticleFuncId);
        ArrayDestroy(g_irgParticleSprites);
        ArrayDestroy(g_irgParticleLifeTime);
        ArrayDestroy(g_irgParticleScale);
        ArrayDestroy(g_irgParticleRenderMode);
        ArrayDestroy(g_irgParticleRenderAmt);
        ArrayDestroy(g_irgParticleSpawnsNum);
    }
}

public plugin_natives() {
    register_library("api_particles");
    register_native("Particles_Register", "Native_Register");
    register_native("Particles_Spawn", "Native_Spawn");
    register_native("Particles_Remove", "Native_Remove");
}

public Native_Register(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new szTransformCallback[32];
    get_string(2, szTransformCallback, charsmax(szTransformCallback));
    new iFunctionId = get_func_id(szTransformCallback, iPluginId);

    new rgiSprites[API_PARTICLES_MAX_SPRITES];
    get_array(3, rgiSprites, sizeof(rgiSprites));

    new Float:flLifeTime = get_param_f(4);
    new Float:flScale = get_param_f(5);
    new iRenderMode = get_param(6);
    new Float:flRenderAmt = get_param_f(7);
    new iSpawnsNum = get_param(8);

    RegisterParticle(szName, iPluginId, iFunctionId, rgiSprites, flLifeTime, flScale, iRenderMode, flRenderAmt, iSpawnsNum);
}

public Native_Spawn(iPluginId, iArgc) {
    new szName[32];
    get_string(1, szName, charsmax(szName));

    new Float:vecOrigin[3];
    get_array_f(2, vecOrigin, sizeof(vecOrigin));

    new Float:flPlayTime = get_param_f(3);

    return SpawnParticles(szName, vecOrigin, flPlayTime);
}

public Native_Remove(iPluginId, iArgc) {
    new pEntity = get_param(1);
    RemoveParticles(pEntity);
}

public FMHook_AddToFullPack(es, e, pEntity, pHost, hostflags, player, pSet) {
    if (!IS_PLAYER(pHost)) {
        return FMRES_IGNORED;
    }

    if (!is_user_connected(pHost)) {
        return FMRES_IGNORED;
    }

    if (!pev_valid(pEntity)) {
        return FMRES_IGNORED;
    }

    static szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    if (equal(szClassName, "_particle")) {
        new pOwner = pev(pEntity, pev_owner);

        if (!pOwner || !pev_valid(pOwner)) {
            return FMRES_IGNORED;
        }

        if (pev(pOwner, pev_iuser3) & BIT(pHost & 31)) {
            return FMRES_IGNORED;
        }

        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

RegisterParticle(const szName[], iPluginId, iFunctionId, const rgiSprites[API_PARTICLES_MAX_SPRITES], Float:flLifeTime, Float:flScale, iRenderMode, Float:flRenderAmt, iSpawnsNum) {
    if (!g_iParticlesNum) {
        g_itParticles = TrieCreate();
        g_irgParticlePluginId = ArrayCreate();
        g_irgParticleFuncId = ArrayCreate();
        g_irgParticleSprites = ArrayCreate(API_PARTICLES_MAX_SPRITES);
        g_irgParticleLifeTime = ArrayCreate();
        g_irgParticleScale = ArrayCreate();
        g_irgParticleRenderMode = ArrayCreate();
        g_irgParticleRenderAmt = ArrayCreate();
        g_irgParticleSpawnsNum = ArrayCreate();
    }

    new iId = g_iParticlesNum;

    TrieSetCell(g_itParticles, szName, iId);
    ArrayPushCell(g_irgParticlePluginId, iPluginId);
    ArrayPushCell(g_irgParticleFuncId, iFunctionId);
    ArrayPushCell(g_irgParticleLifeTime, flLifeTime);
    ArrayPushCell(g_irgParticleScale, flScale);
    ArrayPushCell(g_irgParticleRenderMode, iRenderMode);
    ArrayPushCell(g_irgParticleRenderAmt, flRenderAmt);
    ArrayPushCell(g_irgParticleSpawnsNum, iSpawnsNum);
    ArrayPushArray(g_irgParticleSprites, rgiSprites);

    g_iParticlesNum++;

    return iId;
}

SpawnParticles(const szName[], const Float:vecOrigin[3], Float:flPlayTime) {
    if (!g_iParticlesNum) {
        return 0;
    }

    static iId;
    if (!TrieGetCell(g_itParticles, szName, iId)) {
        return 0;
    }

    new pEntity = engfunc(EngFunc_CreateNamedEntity, g_iszTargetClassname);
    engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);
    dllfunc(DLLFunc_Spawn, pEntity);

    set_pev(pEntity, pev_iuser1, iId);
    set_pev(pEntity, pev_iuser2, 0);
    set_pev(pEntity, pev_iuser3, 0);

    set_task(0.04, "Task_TargetTick", pEntity+TASKID_SUM_TARGET_TICK, _, _, "b");

    if (flPlayTime > 0.0) {
        set_task(flPlayTime, "Task_RemoveTarget", pEntity+TASKID_SUM_REMOVE_TARGET);
    }

    return pEntity;
}

RemoveParticles(pEntity) {
    remove_task(pEntity+TASKID_SUM_TARGET_TICK);
    set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) | FL_KILLME);
    dllfunc(DLLFunc_Think, pEntity);
}

UpdateVisibleFlag(pEntity) {   
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new playerVisibleFlags = 0;
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_connected(pPlayer)) {
            continue;
        }

        if (!is_in_viewcone(pPlayer, vecOrigin, 1)) {
            continue;
        }

        static Float:vecPlayerOrigin[3];
        pev(pPlayer, pev_origin, vecPlayerOrigin);
        vecPlayerOrigin[2] += 16.0;

        if (get_distance_f(vecOrigin, vecPlayerOrigin) > MaxVisibleDistance) {
            continue;
        }

        engfunc(EngFunc_TraceLine, vecPlayerOrigin, vecOrigin, IGNORE_MONSTERS, pPlayer, 0);

        static Float:flFraction;
        get_tr2(0, TR_flFraction, flFraction);

        if (flFraction == 1.0) {
            playerVisibleFlags |= BIT(pPlayer & 31);
        }
    }

    set_pev(pEntity, pev_iuser3, playerVisibleFlags);
}

public Task_RemoveTarget(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_REMOVE_TARGET;
    RemoveParticles(pEntity);
}

public Task_TargetTick(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_TARGET_TICK;
    new iId = pev(pEntity, pev_iuser1);
    new iTick = pev(pEntity, pev_iuser2);

    new iPluginId = ArrayGetCell(g_irgParticlePluginId, iId);
    new iFunctionId = ArrayGetCell(g_irgParticleFuncId, iId);
    new Float:flLifeTime = ArrayGetCell(g_irgParticleLifeTime, iId);
    new Float:flScale = ArrayGetCell(g_irgParticleScale, iId);
    new renderMode = ArrayGetCell(g_irgParticleRenderMode, iId);
    new Float:flRenderAmt = ArrayGetCell(g_irgParticleRenderAmt, iId);
    new iSpawnsNum = ArrayGetCell(g_irgParticleSpawnsNum, iId);

    static sprites[API_PARTICLES_MAX_SPRITES];
    ArrayGetArray(g_irgParticleSprites, iId, sprites);

    static Float:vecOrigin[3];
    static Float:vecVelocity[3];

    for (new i = 0; i < iSpawnsNum; ++i)
    {
        pev(pEntity, pev_origin, vecOrigin);
        xs_vec_set(vecVelocity, 0.0, 0.0, 0.0);

        if (callfunc_begin_i(iFunctionId, iPluginId) == 1) {
            callfunc_push_array(_:vecOrigin, 3);
            callfunc_push_array(_:vecVelocity, 3);
            callfunc_push_int(pEntity);
            callfunc_push_int(iTick);
            callfunc_end();
        }

        static pParticle;
        {
            pParticle = engfunc(EngFunc_CreateNamedEntity, g_iszParticleClassname);
            engfunc(EngFunc_SetOrigin, pParticle, vecOrigin);
            set_pev(pParticle, pev_classname, "_particle");
            set_pev(pParticle, pev_velocity, vecVelocity);
            set_pev(pParticle, pev_modelindex, sprites[random(strlen(sprites))]);
            set_pev(pParticle, pev_solid, SOLID_TRIGGER);
            set_pev(pParticle, pev_movetype, MOVETYPE_NOCLIP);
            set_pev(pParticle, pev_rendermode, renderMode);
            set_pev(pParticle, pev_renderamt, flRenderAmt);
            set_pev(pParticle, pev_scale, flScale);
            set_pev(pParticle, pev_owner, pEntity);

            set_task(flLifeTime, "Task_RemoveParticle", pParticle+TASKID_SUM_REMOVE_PARTICLE);
        }
    }

    UpdateVisibleFlag(pEntity);

    set_pev(pEntity, pev_iuser2, iTick + 1);
}

public Task_RemoveParticle(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_REMOVE_PARTICLE;
    set_pev(pEntity, pev_flags, pev(pEntity, pev_flags) | FL_KILLME);
    dllfunc(DLLFunc_Think, pEntity);
}
