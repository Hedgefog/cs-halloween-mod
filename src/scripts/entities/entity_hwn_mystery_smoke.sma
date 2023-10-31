#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Mystery Smoke"
#define AUTHOR "Hedgehog Fog"

#define m_iTeam "iTeam"

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
    CE_Register(ENTITY_NAME, .vMins = Float:{-64.0, -64.0, 0.0}, .vMaxs = Float:{64.0, 64.0, 64.0});

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_KVD, ENTITY_NAME, "@Entity_KeyValue");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");
    CE_RegisterHook(CEFunction_Touch, ENTITY_NAME, "@Entity_Touch");

    g_iNullModelIndex = precache_model("sprites/white.spr");
    g_iTeamSmokeModelIndex[0] = precache_model("sprites/hwn/magic_smoke.spr");
    g_iTeamSmokeModelIndex[1] = precache_model("sprites/hwn/magic_smoke_red.spr");
    g_iTeamSmokeModelIndex[2] = precache_model("sprites/hwn/magic_smoke_blue.spr");
}

/*--------------------------------[ Hooks ]--------------------------------*/

@Entity_Spawn(this) {
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_FLY);
    set_pev(this, pev_effects, EF_NODRAW);
    set_pev(this, pev_modelindex, g_iNullModelIndex);
    set_pev(this, pev_fuser1, 0.0);
    set_pev(this, pev_team, CE_GetMember(this, m_iTeam));

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_KeyValue(this, const szKey[], const szValue[]) {
    if (equal(szKey, "team")) {
        CE_SetMember(this, m_iTeam, str_to_num(szValue));
    }
}

@Entity_Think(this) {
    static Float:flNextSmokeEmit;
    pev(this, pev_fuser1, flNextSmokeEmit);

    if (get_gametime() >= flNextSmokeEmit) {
        new Float:flLocalDensity = @Entity_EmitSmoke(this);
        new Float:flDelayRatio = 1.0 / floatclamp(flLocalDensity, SMOKE_EMIT_FREQUENCY, 1.0);
        new Float:flDelay = SMOKE_EMIT_FREQUENCY * flDelayRatio;
        set_pev(this, pev_fuser1, get_gametime() + flDelay);
    }

    set_pev(this, pev_nextthink, get_gametime() + Hwn_GetUpdateRate());
}

@Entity_Touch(this, pToucher) {
    if (!IS_PLAYER(pToucher) && !UTIL_IsMonster(pToucher)) {
        return;
    }

    new iTeam = pev(this, pev_team);
    if (UTIL_IsTeammate(pToucher, iTeam)) {
        return;
    }

    static Float:vecToucherOrigin[3];
    pev(pToucher, pev_origin, vecToucherOrigin);

    static Float:vecAbsMin[3];
    pev(this, pev_absmin, vecAbsMin);

    static Float:vecAbsMax[3];
    pev(this, pev_absmax, vecAbsMax);

    static Float:vecToucherAbsMin[3];
    pev(pToucher, pev_absmin, vecToucherAbsMin);

    static Float:vecToucherAbsMax[3];
    pev(pToucher, pev_absmax, vecToucherAbsMax);

    // find and check intersection point
    for (new iAxis = 0; iAxis < 3; ++iAxis) {
        if (vecToucherOrigin[iAxis] < vecAbsMin[iAxis]) {
            vecToucherOrigin[iAxis] = vecToucherAbsMax[iAxis];
        } else if (vecToucherOrigin[iAxis] > vecAbsMax[iAxis]) {
            vecToucherOrigin[iAxis] = vecToucherAbsMin[iAxis];
        }

        if (vecAbsMin[iAxis] >= vecToucherOrigin[iAxis]) {
            return;
        }

        if (vecAbsMax[iAxis] <= vecToucherOrigin[iAxis]) {
            return;
        }
    }

    new pTrace = create_tr2();

    static Float:vecOffset[3];
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecOffset);

    new iClosestAxis = -1;

    for (new iAxis = 0; iAxis < 3; ++iAxis) {
        // calculates the pToucher's offset relative to the current iAxis
        static Float:flSideOffsets[2];
        flSideOffsets[0] = vecAbsMin[iAxis] - vecToucherOrigin[iAxis];
        flSideOffsets[1] = vecAbsMax[iAxis] - vecToucherOrigin[iAxis];

        if (iAxis == 2 && iClosestAxis != -1) {
            break;
        }

        for (new side = 0; side < 2; ++side) {
            // check exit from current side
            static Float:vecTarget[3];
            xs_vec_copy(vecToucherOrigin, vecTarget);
            vecTarget[iAxis] += flSideOffsets[side];
            engfunc(EngFunc_TraceMonsterHull, pToucher, vecToucherOrigin, vecTarget, IGNORE_MONSTERS | IGNORE_GLASS, pToucher, pTrace);

            static Float:flFraction;
            get_tr2(pTrace, TR_flFraction, flFraction);

            // no exit, cannot push this way
            if (flFraction != 1.0) {
                flSideOffsets[side] = 0.0;
            }

            if (iAxis != 2) {
                // save minimum offset, but ignore zero offsets
                if (!vecOffset[iAxis] || (flSideOffsets[side] && floatabs(flSideOffsets[side]) < floatabs(vecOffset[iAxis]))) {
                    vecOffset[iAxis] = flSideOffsets[side];
                }
            } else {
                // priority on bottom side
                if (flSideOffsets[0]) {
                    vecOffset[iAxis] = flSideOffsets[0];
                }
            }

            // find closest iAxis to push
            if (vecOffset[iAxis]) {
                if (iClosestAxis == -1 || floatabs(vecOffset[iAxis]) < floatabs(vecOffset[iClosestAxis])) {
                    iClosestAxis = iAxis;
                }
            }
        }
    }

    free_tr2(pTrace);

    // push player by closest iAxis
    if (iClosestAxis != -1) {
        static Float:vecSize[3];
        xs_vec_sub(vecAbsMax, vecAbsMin, vecSize);

        new iPushDir = vecOffset[iClosestAxis] > 0.0 ? 1 : -1;
        new Float:flDepthRatio = floatabs(vecOffset[iClosestAxis]) / (vecSize[iClosestAxis] / 2);

        static Float:vecVelocity[3];
        pev(pToucher, pev_velocity, vecVelocity);

        if (flDepthRatio > 0.8) {
            vecVelocity[iClosestAxis] = EffectPushForce * iPushDir;
        } else {
            vecVelocity[iClosestAxis] += EffectPushForce * flDepthRatio * iPushDir;
        }

        set_pev(pToucher, pev_velocity, vecVelocity);

        if (IS_PLAYER(pToucher)) {
            // fix for player on ladder
            if (pev(pToucher, pev_movetype) == MOVETYPE_FLY) {
                set_pev(pToucher, pev_movetype, MOVETYPE_WALK);
            }

            set_pev(pToucher, pev_flags, pev(pToucher, pev_flags) | FL_ONTRAIN);
        }
    }
}

Float:@Entity_EmitSmoke(this) {
    static Float:vecAbsMin[3];
    pev(this, pev_absmin, vecAbsMin);

    static Float:vecAbsMax[3];
    pev(this, pev_absmax, vecAbsMax);

    static Float:vecSize[3];
    xs_vec_sub(vecAbsMax, vecAbsMin, vecSize);

    static Float:vecOrigin[3];
    for (new iAxis = 0; iAxis < 2; ++iAxis) {
        vecOrigin[iAxis] = vecAbsMin[iAxis] + (vecSize[iAxis] / 2);
    }

    new Float:flSpreadRadius = vecSize[0] < vecSize[1] ? (vecSize[0] / 2) : (vecSize[1] / 2);
    new Float:flDiff = floatabs(vecSize[0] - vecSize[1]);

    if (vecSize[0] > vecSize[1]) {
        vecOrigin[0] += random_float(-flDiff / 2, flDiff / 2);
    } else if (vecSize[1] > vecSize[0]) {
        vecOrigin[1] += random_float(-flDiff / 2, flDiff / 2);
    }

    vecOrigin[2] = vecAbsMin[2] + 4.0;

    flSpreadRadius = floatmax(flSpreadRadius - (SMOKE_PARTICLE_WIDTH / 4), 0.0);

    new iTeam = pev(this, pev_team);
    new iSmokeTeam = max(iTeam < sizeof(g_iTeamSmokeModelIndex) ? iTeam : 0, 0);
    new iModelIndex = g_iTeamSmokeModelIndex[iSmokeTeam];
    
    // calculate density based on box perimeter
    // using square area creates extreme thick smoke for large areas
    // the main goal is to make smoke looks thick enough for players outside the smoke
    new Float:flLocalDensity = ((2 * vecSize[0]) + (2 * vecSize[1])) * SMOKE_DENSITY * SMOKE_EMIT_FREQUENCY;
    new particlesNum = max(floatround(flLocalDensity), 1);

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
