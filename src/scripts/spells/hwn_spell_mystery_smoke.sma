#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Mystery Smoke Spell"
#define AUTHOR "Hedgehog Fog"

const SpellballSpeed = 720;
const Float:SmokeLifeTime = 30.0;
const SmokeStackMaxSize = 8;
new const Float:SmokeSize[3] = {96.0, 96.0, 64.0};
new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new g_szSprSpellBall[] = "sprites/xsmoke1.spr";

new g_iSpell;
new g_iCeMysteryHandler;

public plugin_precache() {
    precache_model(g_szSprSpellBall);
    precache_sound(g_szSndCast);

    g_iSpell = Hwn_Spell_Register("Mystery Smoke", Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Radius | Hwn_SpellFlag_Protection, "@Player_CastSpell");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_iCeMysteryHandler = CE_GetHandler("hwn_mystery_smoke");

    CE_RegisterHook(CEFunction_Kill, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Kill");
    CE_RegisterHook(CEFunction_Touch, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Touch");
    CE_RegisterHook(CEFunction_Think, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Think");
}

@Player_CastSpell(pPlayer) {
    new pEntity = UTIL_HwnSpawnPlayerSpellball(pPlayer, g_iSpell, EffectColor, SpellballSpeed, g_szSprSpellBall, _, 0.75, 10.0);
    if (!pEntity) {
        return PLUGIN_HANDLED;
    }

    CE_SetMember(pEntity, "iSpell", g_iSpell);
    set_pev(pEntity, pev_team, get_member(pPlayer, m_iTeam));

    emit_sound(pPlayer, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

@SpellBall_Kill(this) {
    if (CE_GetMember(this, "iSpell") != g_iSpell) {
        return;
    }

    @Entity_Detonate(this);
}

@SpellBall_Touch(this, pToucher) {
    if (CE_GetMember(this, "iSpell") != g_iSpell) {
        return;
    }

    if (pToucher == pev(this, pev_owner)) {
        return;
    }

    if (pev(this, pev_deadflag) == DEAD_DEAD) {
        return;
    }

    if (pev(pToucher, pev_solid) < SOLID_BBOX) {
        return;
    }

    CE_Kill(this);
}

@SpellBall_Think(this) {
    if (CE_GetMember(this, "iSpell") != g_iSpell) {
        return;
    }

    if (pev(this, pev_deadflag) == DEAD_DEAD) {
        return;
    }

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    if (!xs_vec_len(vecVelocity)) {
        CE_Kill(this);
    }
}

@Entity_Detonate(this) {
    new iTeam = pev(this, pev_team);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new Float:flLifeTime = 0.0;

    static Float:vecSize[3];
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecSize);
    vecSize[2] = SmokeSize[2];

    static Float:flStackOriginsSum[3];
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, flStackOriginsSum);

    new iStackSize = 0;
    new Float:flStackTotalLifeTime = 0.0;

    // merge nearby smoke entities into the stack
    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, 96.0)) > 0) {
        if (CE_GetHandlerByEntity(pTarget) != g_iCeMysteryHandler) {
            continue;
        }

        if (pev(pTarget, pev_team) != iTeam) {
            continue;
        }

        new iTargetStackSize = CE_GetMember(pTarget, "iStackSize");

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        static Float:vecTargetMins[3];
        pev(pTarget, pev_mins, vecTargetMins);

        static Float:vecTargetMaxs[3];
        pev(pTarget, pev_maxs, vecTargetMaxs);

        for (new i = 0; i < 3; ++i) {
            if (i != 2) {
                vecSize[i] += vecTargetMaxs[i] - vecTargetMins[i];
            }

            flStackOriginsSum[i] += (vecTargetOrigin[i] * iTargetStackSize);
        }

        static Float:flTargetKillTime;
        pev(pTarget, pev_fuser4, flTargetKillTime);

        flStackTotalLifeTime += (flTargetKillTime - get_gametime()) * iTargetStackSize;
        iStackSize += iTargetStackSize;

        CE_Kill(pTarget);
    }

    if (iStackSize) {
        for (new i = 0; i < 3; ++i) {
            vecOrigin[i] = (flStackOriginsSum[i] + vecOrigin[i]) / (iStackSize + 1);
        }

        flLifeTime = flStackTotalLifeTime / iStackSize;

        // calculate extra lifetime based on new smoke energy
        new Float:flLifetimeToAdd = SmokeLifeTime / iStackSize;

        // calculating remaining smoke "energy" 
        new Float:flStackEnergyRemainder = (flLifeTime + flLifetimeToAdd - SmokeLifeTime) / SmokeLifeTime;
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

    new pSmoke = CreateSmoke(vecOrigin, vecSize, flLifeTime, pev(this, pev_team), pev(this, pev_owner));
    CE_SetMember(pSmoke, "iStackSize", iStackSize);
}

CreateSmoke(const Float:vecOrigin[3], const Float:vecSize[3], Float:flLifeTime, iTeam, pOwner) {
    new pEntity = CE_Create("hwn_mystery_smoke", vecOrigin);
    if (!pEntity) {
        return 0;
    }

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
    set_pev(pEntity, pev_fuser4, get_gametime() + flLifeTime);
    engfunc(EngFunc_SetSize, pEntity, vecMins, vecMaxs);

    CE_SetMember(pEntity, CE_MEMBER_NEXTKILL, get_gametime() + flLifeTime);

    return pEntity;
}
