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

#define SPELL_NAME "Mystery Smoke"

const SpellballSpeed = 720;

const Float:SmokeLifeTime = 30.0;
const SmokeStackMaxSize = 8;
new const Float:SmokeSize[3] = {96.0, 96.0, 64.0};

new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new g_szSprSpellBall[] = "sprites/xsmoke1.spr";

new g_iSpell;
new CE:g_iCeMysteryHandler;

public plugin_precache() {
    precache_model(g_szSprSpellBall);
    precache_sound(g_szSndCast);

    g_iSpell = Hwn_Spell_Register(SPELL_NAME, Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Radius | Hwn_SpellFlag_Protection, "@Player_CastSpell");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_iCeMysteryHandler = CE_GetHandler("hwn_mystery_smoke");

    CE_RegisterHook(SPELLBALL_ENTITY_CLASSNAME, CEFunction_Kill, "@SpellBall_Kill");
    CE_RegisterHook(SPELLBALL_ENTITY_CLASSNAME, CEFunction_Touch, "@SpellBall_Touch");
    CE_RegisterHook(SPELLBALL_ENTITY_CLASSNAME, CEFunction_Think, "@SpellBall_Think");
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_CastSpell(pPlayer) {
    new pEntity = UTIL_HwnSpawnPlayerSpellball(pPlayer, g_iSpell, EffectColor, SpellballSpeed, g_szSprSpellBall, _, 0.75, 10.0);
    if (!pEntity) return PLUGIN_HANDLED;

    CE_SetMember(pEntity, "iSpell", g_iSpell);
    set_pev(pEntity, pev_team, get_member(pPlayer, m_iTeam));

    emit_sound(pPlayer, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

@SpellBall_Kill(this) {
    if (@SpellBall_IsMysterySmokeBall(this)) @MysterySmokeBall_Kill(this);
}

@SpellBall_Touch(this, pTarget) {
    if (@SpellBall_IsMysterySmokeBall(this)) @MysterySmokeBall_Touch(this, pTarget);
}

@SpellBall_Think(this) {
    if (@SpellBall_IsMysterySmokeBall(this)) @MysterySmokeBall_Think(this);
}

@SpellBall_IsMysterySmokeBall(this) {
    return CE_GetMember(this, "iSpell") == g_iSpell;
}

@MysterySmokeBall_Kill(this) {
    @Entity_Detonate(this);
}

@MysterySmokeBall_Touch(this, pTarget) {
    if (pTarget == pev(this, pev_owner)) return;
    if (pev(this, pev_deadflag) == DEAD_DEAD) return;
    if (pev(pTarget, pev_solid) < SOLID_BBOX) return;

    CE_Kill(this);
}

@MysterySmokeBall_Think(this) {
    if (pev(this, pev_deadflag) == DEAD_DEAD) return;

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    if (!xs_vec_len(vecVelocity)) CE_Kill(this);
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

    // Merge nearby smoke entities into the stack
    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, 96.0)) > 0) {
        if (CE_GetHandlerByEntity(pTarget) != g_iCeMysteryHandler) continue;
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
}

/*--------------------------------[ Functions ]--------------------------------*/

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
