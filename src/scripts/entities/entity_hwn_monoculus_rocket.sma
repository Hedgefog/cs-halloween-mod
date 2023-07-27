#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Monoculus Rocket"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_monoculus_rocket"

#define EXPLOSION_RADIUS 128.0
#define EXPLOSION_DAMAGE 160.0
#define EXPLOSION_SPRITE_SIZE 80.0

new g_iSmokeModelIndex;
new g_iExplodeSmokeModelIndex;

new Float:g_flThinkDelay;

new g_iCeHandler;

new g_iExlplosionModelIndex;

new const g_szSndExplode[] = "hwn/misc/pumpkin_explode.wav";

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "HamHook_Base_Touch");
}

public plugin_precache() {
    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/props/monoculus_rocket.mdl"),
        .vMins = Float:{-8.0, -8.0, -8.0},
        .vMaxs = Float:{8.0, 8.0, 8.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");

    g_iSmokeModelIndex = precache_model("sprites/black_smoke1.spr");
    g_iExplodeSmokeModelIndex = precache_model("sprites/hwn/magic_smoke.spr");

    precache_sound(g_szSndExplode);

    g_iExlplosionModelIndex = precache_model("sprites/eexplo.spr");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded() {
    g_flThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(pEntity) {
    set_pev(pEntity, pev_solid, SOLID_TRIGGER);
    set_pev(pEntity, pev_movetype, MOVETYPE_FLY);

    set_pev(pEntity, pev_rendermode, kRenderNormal);
    set_pev(pEntity, pev_renderfx, kRenderFxGlowShell);
    set_pev(pEntity, pev_renderamt, 4.0);
    set_pev(pEntity, pev_rendercolor, {HWN_COLOR_PRIMARY_F});

    Task_Think(pEntity);
}

public OnRemove(pEntity) {
    remove_task(pEntity);
}

public OnKilled(pEntity) {
    ExplosionEffect(pEntity);

    new pOwner = pev(pEntity, pev_owner);
    if (!pev_valid(pOwner)) {
        pOwner = 0;
    }

    RocketRadiusDamage(pEntity, pOwner);
}

public HamHook_Base_Touch(pEntity, pTarget) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    CE_Kill(pEntity, pTarget);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Think(pEntity) {
    if (!pev_valid(pEntity)) {
        return;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    //Fix for smoke origin
    {
        static Float:vecSub[3];
        UTIL_GetDirectionVector(pEntity, vecSub, 32.0);
        vecSub[2] += 18.0;

        xs_vec_sub(vecOrigin, vecSub, vecOrigin);
    }

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(g_iSmokeModelIndex);
    write_byte(10);
    write_byte(90);
    message_end();

    set_task(g_flThinkDelay, "Task_Think", pEntity);
}

RocketRadiusDamage(pEntity, pOwner) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EXPLOSION_RADIUS * 2)) != 0) {
        if (pEntity == pTarget) {
            continue;
        }

        if (pev(pTarget, pev_deadflag) != DEAD_NO) {
            continue;
        }

        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        new Float:flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, EXPLOSION_RADIUS, EXPLOSION_DAMAGE, false, pTarget);

        ExecuteHamB(Ham_TakeDamage, pTarget, pEntity, pOwner, flDamage, DMG_ALWAYSGIB);
    }
}

ExplosionEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    vecOrigin[2] += 16.0;

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(g_iExlplosionModelIndex);
    write_byte(floatround(((EXPLOSION_RADIUS * 2) / EXPLOSION_SPRITE_SIZE) * 10));
    write_byte(24);
    write_byte(0);
    message_end();
    
    UTIL_Message_FireField(vecOrigin, 32, g_iExplodeSmokeModelIndex, 4, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 15);

    emit_sound(pEntity, CHAN_BODY, g_szSndExplode, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, UTIL_DelayToLifeTime(g_flThinkDelay), 0);
}