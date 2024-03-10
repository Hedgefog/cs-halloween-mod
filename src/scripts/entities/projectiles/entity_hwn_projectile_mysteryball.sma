#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Entity] Hwn Mystery Ball"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_mysteryball"

new const g_szDetonateSound[] = "hwn/spells/spell_teleport.wav";
new const g_szEffectModel[] = "sprites/xsmoke1.spr";

const Float:SmokeLifeTime = 30.0;
const SmokeStackMaxSize = 8;
new const Float:SmokeSize[3] = {96.0, 96.0, 64.0};
new const Float:EffectColorF[3] = {HWN_COLOR_PRIMARY_F};

public plugin_precache() {
    precache_sound(g_szDetonateSound);
    precache_model(g_szEffectModel);
    
    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_magicball");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");

    CE_RegisterMethod(ENTITY_NAME, "Detonate", "@Entity_Detonate", CE_MP_Cell);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Spawned(this) {
    set_pev(this, pev_rendercolor, EffectColorF);

    CE_CallMethod(this, "SpawnEffect", g_szEffectModel, EffectColorF, 255.0, 0.75, 10.0);
}

@Entity_Detonate(this, pDetonator) {
    static iTeam; iTeam = pev(this, pev_team);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecSize[3]; xs_vec_set(vecSize, 0.0, 0.0, SmokeSize[2]);
    static Float:flStackOriginsSum[3]; xs_vec_copy(Float:{0.0, 0.0, 0.0}, flStackOriginsSum);

    new Float:flLifeTime = 0.0;
    new iStackSize = 0;
    new Float:flStackTotalLifeTime = 0.0;

    // Merge nearby smoke entities into the stack
    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, 96.0)) > 0) {
        if (CE_GetHandlerByEntity(pTarget) != CE_GetHandler("hwn_mystery_smoke")) continue;
        if (pev(pTarget, pev_team) != iTeam) continue;

        static iTargetStackSize; iTargetStackSize = CE_GetMember(pTarget, "iStackSize");
        static Float:vecTargetOrigin[3]; pev(pTarget, pev_origin, vecTargetOrigin);
        static Float:vecTargetMins[3]; pev(pTarget, pev_mins, vecTargetMins);
        static Float:vecTargetMaxs[3]; pev(pTarget, pev_maxs, vecTargetMaxs);

        for (new i = 0; i < 3; ++i) {
            if (i != 2) {
                vecSize[i] += vecTargetMaxs[i] - vecTargetMins[i];
            }

            flStackOriginsSum[i] += (vecTargetOrigin[i] * iTargetStackSize);
        }

        static Float:flNextKill; flNextKill = CE_GetMember(pTarget, CE_MEMBER_NEXTKILL);
        flStackTotalLifeTime += (flNextKill - get_gametime()) * iTargetStackSize;
        iStackSize += iTargetStackSize;

        CE_Kill(pTarget);
    }

    if (iStackSize) {
        for (new i = 0; i < 3; ++i) {
            vecOrigin[i] = (flStackOriginsSum[i] + vecOrigin[i]) / (iStackSize + 1);
        }

        flLifeTime = flStackTotalLifeTime / iStackSize;

        // calculate extra lifetime based on new smoke energy
        static Float:flLifetimeToAdd; flLifetimeToAdd = SmokeLifeTime / iStackSize;

        // calculating remaining smoke "energy" 
        static Float:flStackEnergyRemainder; flStackEnergyRemainder = (flLifeTime + flLifetimeToAdd - SmokeLifeTime) / SmokeLifeTime;
        flLifeTime = floatmin(flLifeTime + flLifetimeToAdd, SmokeLifeTime);

        if (flStackEnergyRemainder > 0 && iStackSize <= SmokeStackMaxSize) {
            for (new i = 0; i < 2; ++i) {
                vecSize[i] += SmokeSize[i] * (flStackEnergyRemainder * iStackSize);
            }
        } else {
            xs_vec_mul_scalar(SmokeSize, float(iStackSize), vecSize);
        }

        // recalculate stack size based
        iStackSize = floatround((vecSize[0] + vecSize[1]) / (SmokeSize[0] + SmokeSize[1]), floatround_ceil);
    } else {
        iStackSize++;
        flLifeTime = SmokeLifeTime;
        xs_vec_copy(SmokeSize, vecSize);
    }

    new pSmoke = CreateMysterySmoke(vecOrigin, vecSize, flLifeTime, pev(this, pev_team), pev(this, pev_owner));
    CE_SetMember(pSmoke, "iStackSize", iStackSize);

    CE_CallBaseMethod(pDetonator);
}

CreateMysterySmoke(const Float:vecOrigin[3], const Float:vecSize[3], Float:flLifeTime, iTeam, pOwner) {
    new pEntity = CE_Create("hwn_mystery_smoke", vecOrigin);
    if (!pEntity) return 0;

    static Float:vecMins[3];
    static Float:vecMaxs[3];

    for (new i = 0; i < 3; ++i) {
        if (i != 2) {
            vecMins[i] = -vecSize[i] / 2;
            vecMaxs[i] = vecSize[i] / 2;
        } else {
            vecMins[i] = 0.0;
            vecMaxs[i] = vecSize[2];
        }
    }

    dllfunc(DLLFunc_Spawn, pEntity);
    set_pev(pEntity, pev_team, iTeam);
    set_pev(pEntity, pev_owner, pOwner);
    engfunc(EngFunc_SetSize, pEntity, vecMins, vecMaxs);

    CE_SetMember(pEntity, CE_MEMBER_NEXTKILL, get_gametime() + flLifeTime);

    return pEntity;
}
