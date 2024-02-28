#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_custom_entities>
#include <api_advanced_pushing>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Mystery Smoke"
#define AUTHOR "Hedgehog Fog"

#define m_iTeam "iTeam"
#define m_flNextSmokeEmit "flNextSmokeEmit"

#define ENTITY_NAME "hwn_mystery_smoke"

#define SMOKE_DENSITY 0.016
#define SMOKE_PARTICLES_LIFETIME 30
#define SMOKE_PARTICLE_WIDTH 128.0
#define SMOKE_EMIT_FREQUENCY 0.25

const Float:EffectPushForce = 100.0;

new g_iTeamSmokeModelIndex[3];
new g_iNullModelIndex;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register(ENTITY_NAME);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitSize, "@Entity_InitSize");
    CE_RegisterHook(ENTITY_NAME, CEFunction_KeyValue, "@Entity_KeyValue");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Touch, "@Entity_Touch");

    g_iNullModelIndex = precache_model("sprites/white.spr");
    g_iTeamSmokeModelIndex[0] = precache_model("sprites/hwn/magic_smoke.spr");
    g_iTeamSmokeModelIndex[1] = precache_model("sprites/hwn/magic_smoke_red.spr");
    g_iTeamSmokeModelIndex[2] = precache_model("sprites/hwn/magic_smoke_blue.spr");
}

/*--------------------------------[ Hooks ]--------------------------------*/

@Entity_Spawned(this) {
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_FLY);
    set_pev(this, pev_effects, EF_NODRAW);
    set_pev(this, pev_modelindex, g_iNullModelIndex);
    set_pev(this, pev_team, CE_GetMember(this, m_iTeam));

    CE_SetMember(this, m_flNextSmokeEmit, 0.0);

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_InitSize(this) {
    static szModel[32];
    CE_GetMemberString(this, CE_MEMBER_MODEL, szModel, charsmax(szModel));

    if (equal(szModel, NULL_STRING) || szModel[0] != '*') {
        engfunc(EngFunc_SetSize, this, Float:{-64.0, -64.0, 0.0}, Float:{64.0, 64.0, 64.0});
    }
}

@Entity_KeyValue(this, const szKey[], const szValue[]) {
    if (equal(szKey, "team")) {
        CE_SetMember(this, m_iTeam, str_to_num(szValue));
    }
}

@Entity_Think(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    static Float:flNextSmokeEmit; flNextSmokeEmit = CE_GetMember(this, m_flNextSmokeEmit); 
    if (flNextSmokeEmit < flGameTime) {
        static Float:flLocalDensity; flLocalDensity = @Entity_EmitSmoke(this);
        static Float:flDelayRatio; flDelayRatio = 1.0 / floatclamp(flLocalDensity, SMOKE_EMIT_FREQUENCY, 1.0);
        static Float:flDelay; flDelay = SMOKE_EMIT_FREQUENCY * flDelayRatio;

        CE_SetMember(this, m_flNextSmokeEmit, flGameTime + flDelay);
    }

    set_pev(this, pev_nextthink, flGameTime + Hwn_GetUpdateRate());
}

@Entity_Touch(this, pToucher) {
    if (!IS_PLAYER(pToucher) && !UTIL_IsMonster(pToucher)) return;

    new iTeam = pev(this, pev_team);
    if (UTIL_IsTeammate(pToucher, iTeam)) return;

    static Float:vecAbsMin[3];
    pev(this, pev_absmin, vecAbsMin);

    static Float:vecAbsMax[3];
    pev(this, pev_absmax, vecAbsMax);

    APS_PushFromBBox(pToucher, EffectPushForce, vecAbsMin, vecAbsMax, _, _, _, 0.8, APS_Flag_AddForce | APS_Flag_AddForceInfluenceMode | APS_Flag_OverlapMode);
}

Float:@Entity_EmitSmoke(this) {
    static Float:vecAbsMin[3]; pev(this, pev_absmin, vecAbsMin);
    static Float:vecAbsMax[3]; pev(this, pev_absmax, vecAbsMax);
    static Float:vecSize[3]; xs_vec_sub(vecAbsMax, vecAbsMin, vecSize);

    static Float:vecOrigin[3];
    for (new iAxis = 0; iAxis < 2; ++iAxis) {
        vecOrigin[iAxis] = vecAbsMin[iAxis] + (vecSize[iAxis] / 2);
    }

    static Float:flSpreadRadius; flSpreadRadius = vecSize[0] < vecSize[1] ? (vecSize[0] / 2) : (vecSize[1] / 2);
    static Float:flDiff; flDiff = floatabs(vecSize[0] - vecSize[1]);

    if (vecSize[0] > vecSize[1]) {
        vecOrigin[0] += random_float(-flDiff / 2, flDiff / 2);
    } else if (vecSize[1] > vecSize[0]) {
        vecOrigin[1] += random_float(-flDiff / 2, flDiff / 2);
    }

    vecOrigin[2] = vecAbsMin[2] + 4.0;

    flSpreadRadius = floatmax(flSpreadRadius - (SMOKE_PARTICLE_WIDTH / 4), 0.0);

    static iTeam; iTeam = pev(this, pev_team);
    static iSmokeTeam; iSmokeTeam = max(iTeam < sizeof(g_iTeamSmokeModelIndex) ? iTeam : 0, 0);
    static iModelIndex; iModelIndex = g_iTeamSmokeModelIndex[iSmokeTeam];
    
    // calculate density based on box perimeter
    // using square area creates extreme thick smoke for large areas
    // the main goal is to make smoke looks thick enough for players outside the smoke
    static Float:flLocalDensity; flLocalDensity = ((2 * vecSize[0]) + (2 * vecSize[1])) * SMOKE_DENSITY * SMOKE_EMIT_FREQUENCY;
    static particlesNum; particlesNum = max(floatround(flLocalDensity), 1);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_FIREFIELD);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(floatround(flSpreadRadius));
    write_short(iModelIndex);
    write_byte(particlesNum);
    write_byte(TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA | TEFIRE_FLAG_PLANAR);
    write_byte(SMOKE_PARTICLES_LIFETIME);
    message_end();

    return flLocalDensity;
}
