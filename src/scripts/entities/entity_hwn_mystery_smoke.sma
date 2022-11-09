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

#define ENTITY_NAME "hwn_mystery_smoke"

#define SMOKE_DENSITY 0.016
#define SMOKE_PARTICLES_LIFETIME 30
#define SMOKE_PARTICLE_WIDTH 128.0
#define SMOKE_EMIT_FREQUENCY 0.25

const Float:EffectPushForce = 100.0;

new g_sprTeamSmoke[3];
new g_sprNull;

new g_ceHandler;

new Float:g_fThinkDelay;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{
    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .vMins = Float:{-64.0, -64.0, 0.0},
        .vMaxs = Float:{64.0, 64.0, 64.0}
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_KVD, ENTITY_NAME, "OnKeyValue");

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
    RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "OnThink", .Post = 1);

    g_sprNull = precache_model("sprites/white.spr");
    g_sprTeamSmoke[0] = precache_model("sprites/hwn/magic_smoke.spr");
    g_sprTeamSmoke[1] = precache_model("sprites/hwn/magic_smoke_red.spr");
    g_sprTeamSmoke[2] = precache_model("sprites/hwn/magic_smoke_blue.spr");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded()
{
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
    set_pev(ent, pev_solid, SOLID_TRIGGER);
    set_pev(ent, pev_movetype, MOVETYPE_FLY);
    set_pev(ent, pev_effects, EF_NODRAW);
    set_pev(ent, pev_modelindex, g_sprNull);
    set_pev(ent, pev_fuser1, 0.0);

    set_pev(ent, pev_nextthink, get_gametime());
}

public OnKeyValue(ent, const szKey[], const szValue[])
{
    if (equal(szKey, "team")) {
        set_pev(ent, pev_message, str_to_num(szValue));
    }
}

public OnThink(ent)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    static Float:fNextSmokeEmit;
    pev(ent, pev_fuser1, fNextSmokeEmit);

    if (get_gametime() >= fNextSmokeEmit) {
        new Float:fLocalDensity = EmitSmoke(ent);
        new Float:fDelayRatio = 1.0 / floatclamp(fLocalDensity, SMOKE_EMIT_FREQUENCY, 1.0);
        new Float:fDelay = SMOKE_EMIT_FREQUENCY * fDelayRatio;
        set_pev(ent, pev_fuser1, get_gametime() + fDelay);
    }

    set_pev(ent, pev_nextthink, get_gametime() + g_fThinkDelay);
}

public OnTouch(ent, toucher)
{
    if (g_ceHandler == CE_GetHandlerByEntity(ent)) {
        PushToucher(ent, toucher);
    }
}

PushToucher(ent, toucher)
{
    if (!UTIL_IsPlayer(toucher) && !UTIL_IsMonster(toucher)) {
        return;
    }

    new team = pev(ent, pev_team);
    if (UTIL_IsTeammate(toucher, team)) {
        return;
    }

    static Float:vToucherOrigin[3];
    pev(toucher, pev_origin, vToucherOrigin);

    static Float:vAbsMin[3];
    pev(ent, pev_absmin, vAbsMin);

    static Float:vAbsMax[3];
    pev(ent, pev_absmax, vAbsMax);

    static Float:vToucherAbsMin[3];
    pev(toucher, pev_absmin, vToucherAbsMin);

    static Float:vToucherAbsMax[3];
    pev(toucher, pev_absmax, vToucherAbsMax);

    // find and check intersection point
    for (new axis = 0; axis < 3; ++axis) {
        if (vToucherOrigin[axis] < vAbsMin[axis]) {
            vToucherOrigin[axis] = vToucherAbsMax[axis];
        } else if (vToucherOrigin[axis] > vAbsMax[axis]) {
            vToucherOrigin[axis] = vToucherAbsMin[axis];
        }

        if (vAbsMin[axis] >= vToucherOrigin[axis]) {
            return;
        }

        if (vAbsMax[axis] <= vToucherOrigin[axis]) {
            return;
        }
    }

    new trace = create_tr2();

    static Float:vOffset[3];
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, vOffset);

    new closestAxis = -1;

    for (new axis = 0; axis < 3; ++axis) {
        // calculates the toucher's offset relative to the current axis
        static Float:fSideOffsets[2];
        fSideOffsets[0] = vAbsMin[axis] - vToucherOrigin[axis];
        fSideOffsets[1] = vAbsMax[axis] - vToucherOrigin[axis];

        if (axis == 2 && closestAxis != -1) {
            break;
        }

        for (new side = 0; side < 2; ++side) {
            // check exit from current side
            static Float:vTarget[3];
            xs_vec_copy(vToucherOrigin, vTarget);
            vTarget[axis] += fSideOffsets[side];
            engfunc(EngFunc_TraceMonsterHull, toucher, vToucherOrigin, vTarget, IGNORE_MONSTERS | IGNORE_GLASS, toucher, trace);

            static Float:fFraction;
            get_tr2(trace, TR_flFraction, fFraction);

            // no exit, cannot push this way
            if (fFraction != 1.0) {
                fSideOffsets[side] = 0.0;
            }

            if (axis != 2) {
                // save minimum offset, but ignore zero offsets
                if (!vOffset[axis] || (fSideOffsets[side] && floatabs(fSideOffsets[side]) < floatabs(vOffset[axis]))) {
                    vOffset[axis] = fSideOffsets[side];
                }
            } else {
                // priority on bottom side
                if (fSideOffsets[0]) {
                    vOffset[axis] = fSideOffsets[0];
                }
            }

            // find closest axis to push
            if (vOffset[axis]) {
                if (closestAxis == -1 || floatabs(vOffset[axis]) < floatabs(vOffset[closestAxis])) {
                    closestAxis = axis;
                }
            }
        }
    }

    free_tr2(trace);

    // push player by closest axis
    if (closestAxis != -1) {
        static Float:vSize[3];
        xs_vec_sub(vAbsMax, vAbsMin, vSize);

        new pushDir = vOffset[closestAxis] > 0.0 ? 1 : -1;
        new Float:fDepthRatio = floatabs(vOffset[closestAxis]) / (vSize[closestAxis] / 2);

        static Float:vVelocity[3];
        pev(toucher, pev_velocity, vVelocity);

        if (fDepthRatio > 0.8) {
            vVelocity[closestAxis] = EffectPushForce * pushDir;
        } else {
            vVelocity[closestAxis] += EffectPushForce * fDepthRatio * pushDir;
        }

        set_pev(toucher, pev_velocity, vVelocity);

        if (UTIL_IsPlayer(toucher)) {
            // fix for player on ladder
            if (pev(toucher, pev_movetype) == MOVETYPE_FLY) {
                set_pev(toucher, pev_movetype, MOVETYPE_WALK);
            }

            set_pev(toucher, pev_flags, pev(toucher, pev_flags) | FL_ONTRAIN);
        }
    }
}

Float:EmitSmoke(ent)
{
    static Float:vAbsMin[3];
    pev(ent, pev_absmin, vAbsMin);

    static Float:vAbsMax[3];
    pev(ent, pev_absmax, vAbsMax);

    static Float:vSize[3];
    xs_vec_sub(vAbsMax, vAbsMin, vSize);

    static Float:vOrigin[3];
    for (new axis = 0; axis < 2; ++axis) {
        vOrigin[axis] = vAbsMin[axis] + (vSize[axis] / 2);
    }

    new Float:fSpreadRadius = vSize[0] < vSize[1] ? (vSize[0] / 2) : (vSize[1] / 2);
    new Float:fDiff = floatabs(vSize[0] - vSize[1]);

    if (vSize[0] > vSize[1]) {
        vOrigin[0] += random_float(-fDiff / 2, fDiff / 2);
    } else if (vSize[1] > vSize[0]) {
        vOrigin[1] += random_float(-fDiff / 2, fDiff / 2);
    }

    vOrigin[2] = vAbsMin[2] + 4.0;

    fSpreadRadius = floatmax(fSpreadRadius - (SMOKE_PARTICLE_WIDTH / 4), 0.0);

    new team = pev(ent, pev_team);
    new teamSmokeIndex = max(0, team < sizeof(g_sprTeamSmoke) ? team : 0);
    new modelIndex = g_sprTeamSmoke[teamSmokeIndex];
    
    // calculate density based on box perimeter
    // using square area creates extreme thick smoke for large areas
    // the main goal is to make smoke looks thick enough for players outside the smoke
    new Float:fLocalDensity = ((2 * vSize[0]) + (2 * vSize[1])) * SMOKE_DENSITY * SMOKE_EMIT_FREQUENCY;
    new particlesNum = max(floatround(fLocalDensity), 1);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_FIREFIELD);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_short(floatround(fSpreadRadius));
    write_short(modelIndex);
    write_byte(particlesNum);
    write_byte(TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA | TEFIRE_FLAG_PLANAR);
    write_byte(SMOKE_PARTICLES_LIFETIME);
    message_end();

    return fLocalDensity;
}
