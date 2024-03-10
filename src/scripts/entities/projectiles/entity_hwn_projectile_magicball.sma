#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Entity] Hwn Magic Ball"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_magicball"

#define m_pEffect "pEffect"

new g_iSmokeModelIndex;
new g_iNullModelIndex;

public plugin_precache() {
    g_iSmokeModelIndex = precache_model("sprites/black_smoke1.spr");
    g_iNullModelIndex = precache_model("sprites/white.spr");

    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_base");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_RegisterVirtualMethod(ENTITY_NAME, "StopKill", "@Entity_StopKill");
    CE_RegisterVirtualMethod(ENTITY_NAME, "SpawnEffect", "@Entity_SpawnEffect", CE_MP_String, CE_MP_FloatArray, 3, CE_MP_Float, CE_MP_Float, CE_MP_Float);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-8.0, -8.0, -8.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{8.0, 8.0, 8.0});
    CE_SetMember(this, CE_MEMBER_LIFETIME, HWN_NPC_LIFE_TIME);
}

@Entity_Spawned(this) {
    set_pev(this, pev_gravity, 0.20);
    set_pev(this, pev_health, 1.0);
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_TOSS);
    set_pev(this, pev_rendermode, kRenderTransTexture);
    set_pev(this, pev_renderamt, 0.0);
    set_pev(this, pev_modelindex, g_iNullModelIndex);
    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Remove(this) {
    new pEffect = CE_GetMember(this, m_pEffect);
    if (pEffect) {
        engfunc(EngFunc_RemoveEntity, pEffect);
    }
}

@Entity_Think(this) {
    if (pev(this, pev_deadflag) == DEAD_DEAD) return;

    static Float:flRate; flRate = Hwn_GetUpdateRate();
    static iLifeTime; iLifeTime = max(floatround(flRate * 10), 1);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static rgiColor[3]; pev(this, pev_rendercolor, rgiColor);
    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
    static Float:flSpeed; flSpeed = xs_vec_len(vecVelocity);

    for (new i = 0; i < 3; ++i) rgiColor[i] = floatround(Float:rgiColor[i]);

    UTIL_Message_Dlight(vecOrigin, 16, rgiColor, iLifeTime, 0);

    // Fix for smoke origin
    static Float:vecOffset[3];
    xs_vec_normalize(vecVelocity, vecOffset);
    xs_vec_mul_scalar(vecOffset, flSpeed / 16.0, vecOffset); // origin prediction
    vecOffset[2] += 20.0;

    xs_vec_sub(vecOrigin, vecOffset, vecOrigin);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(g_iSmokeModelIndex);
    write_byte(10);
    write_byte(90);
    message_end();

    UTIL_Message_Dlight(vecOrigin, 16, rgiColor, iLifeTime, 0);

    set_pev(this, pev_nextthink, get_gametime() + flRate);

    if (!flSpeed) CE_CallMethod(this, "StopKill");
}

@Entity_SpawnEffect(this, const szSprite[], const Float:flColor[3], Float:flAmt, Float:flScale, Float:flFramerate) {
    static iszClassName;
    if (!iszClassName) {
        iszClassName = engfunc(EngFunc_AllocString, "env_sprite");
    }

    new pEffect = engfunc(EngFunc_CreateNamedEntity, iszClassName);
    set_pev(pEffect, pev_solid, SOLID_NOT);
    set_pev(pEffect, pev_movetype, MOVETYPE_NONE);
    set_pev(pEffect, pev_rendermode, kRenderTransAdd);
    engfunc(EngFunc_SetModel, pEffect, szSprite);
    set_pev(pEffect, pev_renderamt, flAmt);
    set_pev(pEffect, pev_rendercolor, flColor);
    set_pev(pEffect, pev_scale, flScale);
    set_pev(pEffect, pev_animtime, get_gametime());
    set_pev(pEffect, pev_framerate, flFramerate);
    set_pev(pEffect, pev_spawnflags, SF_SPRITE_STARTON);

    dllfunc(DLLFunc_Spawn, pEffect);

    set_pev(pEffect, pev_aiment, this);
    set_pev(pEffect, pev_movetype, MOVETYPE_FOLLOW);

    CE_SetMember(this, m_pEffect, pEffect);

    return pEffect;
}

@Entity_StopKill(this) {
    CE_Kill(this);
}
