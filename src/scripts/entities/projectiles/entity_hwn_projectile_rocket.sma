#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Entity] Hwn Monoculus Rocket"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_rocket"

#define EXPLOSION_RADIUS 128.0
#define EXPLOSION_DAMAGE 160.0
#define EXPLOSION_SPRITE_SIZE 80.0

new const g_szModel[] = "models/hwn/props/monoculus_rocket.mdl";
new const g_szSndExplode[] = "hwn/misc/pumpkin_explode.wav";

new g_iSmokeModelIndex;
new g_iExplodeSmokeModelIndex;
new g_iExlplosionModelIndex;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    precache_sound(g_szSndExplode);

    precache_model(g_szModel);
    g_iSmokeModelIndex = precache_model("sprites/black_smoke1.spr");
    g_iExplodeSmokeModelIndex = precache_model("sprites/hwn/magic_smoke.spr");
    g_iExlplosionModelIndex = precache_model("sprites/eexplo.spr");

    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_base");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitPhysics, "@Entity_InitPhysics");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitSize, "@Entity_InitSize");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_RegisterMethod(ENTITY_NAME, "Detonate", "@Entity_Detonate", CE_MP_Cell);
}

@Entity_Init(this) {
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
}

@Entity_Spawned(this) {
    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, {HWN_COLOR_PRIMARY_F});

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_FLY);
}

@Entity_InitSize(this) {
    engfunc(EngFunc_SetSize, this, Float:{-8.0, -8.0, -8.0}, Float:{8.0, 8.0, 8.0});
}

@Entity_Detonate(this, pDetonator) {
    @Entity_ExplosionEffect(this);
    @Entity_RadiusDamage(this);

    CE_CallBaseMethod(pDetonator);
}

@Entity_Think(this) {
    static Float:vecOffset[3];
    UTIL_GetDirectionVector(this, vecOffset, 32.0);
    vecOffset[2] += 18.0;

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
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

    set_pev(this, pev_nextthink, get_gametime() + Hwn_GetUpdateRate());
}

@Entity_RadiusDamage(this) {
    new pOwner = pev(this, pev_owner);

    if (!pev_valid(pOwner)) {
        pOwner = 0;
    }

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EXPLOSION_RADIUS * 2)) != 0) {
        if (this == pTarget) continue;
        if (pev(pTarget, pev_deadflag) != DEAD_NO) continue;
        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) continue;

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        new Float:flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, EXPLOSION_RADIUS, EXPLOSION_DAMAGE, false, pTarget);
        ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, flDamage, DMG_ALWAYSGIB);
    }
}

@Entity_ExplosionEffect(this) {
    new Float:flRate = Hwn_GetUpdateRate();
    new iLifeTime = min(floatround(flRate * 10), 1);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
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
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, iLifeTime, 0);

    emit_sound(this, CHAN_BODY, g_szSndExplode, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}