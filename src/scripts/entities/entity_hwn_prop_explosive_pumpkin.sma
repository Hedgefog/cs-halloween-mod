#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Prop Explosive Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_prop_explosive_pumpkin"

#define EXPLOSION_RADIUS 128.0
#define EXPLOSION_DAMAGE 250.0
#define EXPLOSION_SPRITE_SIZE 80.0

new g_iGibsModelIndex;
new g_iExlplosionModelIndex;
new g_iExplodeSmokeModelIndex;

new const g_szModel[] = "models/hwn/props/pumpkin_explode_v2.mdl";
new const g_szSndExplode[] = "hwn/misc/pumpkin_explode.wav";

public plugin_precache() {
    precache_model(g_szModel);
    precache_sound(g_szSndExplode);

    g_iExlplosionModelIndex = precache_model("sprites/eexplo.spr");
    g_iExplodeSmokeModelIndex = precache_model("sprites/hwn/pumpkin_smoke.spr");
    g_iGibsModelIndex = precache_model("models/hwn/props/pumpkin_explode_jib_v2.mdl");
    
    CE_Register(ENTITY_NAME, CEPreset_Prop);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Init(this) {
    CE_SetMember(this, CE_MEMBER_RESPAWNTIME, HWN_NPC_RESPAWN_TIME);
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -16.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 16.0, 32.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel);
}

@Entity_Spawned(this) {
    set_pev(this, pev_takedamage, DAMAGE_AIM);
    set_pev(this, pev_health, 1.0);
    engfunc(EngFunc_DropToFloor, this);
}

@Entity_Killed(this, pAttacker) {
    @Entity_ExplosionEffect(this);
    @Entity_RadiusDamage(this, pAttacker);
}

@Entity_RadiusDamage(this, pOwner) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EXPLOSION_RADIUS * 2)) > 0) {
        if (this == pTarget) continue;
        if (pev(pTarget, pev_deadflag) != DEAD_NO) continue;
        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) continue;

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        new Float:flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, EXPLOSION_RADIUS, EXPLOSION_DAMAGE);

        ExecuteHamB(Ham_TakeDamage, pTarget, this, pTarget == pOwner ? 0 : pOwner, flDamage, DMG_ALWAYSGIB);
    }
}

@Entity_ExplosionEffect(this) {
    new Float:vecOrigin[3];
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

    UTIL_Message_FireField(vecOrigin, 32, g_iExplodeSmokeModelIndex, 4, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);

    new Float:vecVelocity[3]; UTIL_RandomVector(-128.0, 128.0, vecVelocity);
    UTIL_Message_BreakModel(vecOrigin, Float:{16.0, 16.0, 16.0}, vecVelocity, 32, g_iGibsModelIndex, 4, 25, 0);

    emit_sound(this, CHAN_BODY, g_szSndExplode, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
