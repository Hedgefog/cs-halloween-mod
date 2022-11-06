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
new const Float:SmokeSize[3] = {72.0, 72.0, 72.0};
new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new g_szSprSpellBall[] = "sprites/xsmoke1.spr";

new g_hSpell;
new g_hCeSpellball;
new g_hCeMysterySmoke;

public plugin_precache()
{
    precache_model(g_szSprSpellBall);
    precache_sound(g_szSndCast);

    g_hSpell = Hwn_Spell_Register("Mystery Smoke", Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Radius | Hwn_SpellFlag_Protection, "OnCast");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
    RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "OnThink", .Post = 1);

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);
    g_hCeMysterySmoke = CE_GetHandler("hwn_mystery_smoke");

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
    CE_RegisterHook(CEFunction_Remove, "hwn_mystery_smoke", "OnMagicSmokeRemove");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, EffectColor, SpellballSpeed, g_szSprSpellBall, _, 0.75, 10.0);

    if (!ent) {
        return PLUGIN_HANDLED;
    }

    set_pev(ent, pev_iuser1, g_hSpell);
    set_pev(ent, pev_team, UTIL_GetPlayerTeam(id));

    emit_sound(id, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

public OnTouch(ent, target)
{
    if (!pev_valid(ent)) {
        return;
    }

    if (g_hCeSpellball != CE_GetHandlerByEntity(ent)) {
        return;
    }

    if (pev(ent, pev_iuser1) != g_hSpell) {
        return;
    }

    if (target == pev(ent, pev_owner)) {
        return;
    }

    if (pev(ent, pev_deadflag) == DEAD_DEAD) {
        return;
    }

    if (pev(target, pev_solid) < SOLID_BBOX) {
        return;
    }

    CE_Kill(ent);
}

public OnThink(ent) {
    if (!pev_valid(ent)) {
        return;
    }

    if (g_hCeSpellball != CE_GetHandlerByEntity(ent)) {
        return;
    }

    if (pev(ent, pev_iuser1) != g_hSpell) {
        return;
    }

    if (pev(ent, pev_deadflag) == DEAD_DEAD) {
        return;
    }

    static Float:vecVelocity[3];
    pev(ent, pev_velocity, vecVelocity);

    if (!xs_vec_len(vecVelocity)) {
        CE_Kill(ent);
    }
}

public OnSpellballKilled(ent)
{
    new spellIdx = pev(ent, pev_iuser1);

    if (spellIdx != g_hSpell) {
        return;
    }

    Detonate(ent);
}

public OnMagicSmokeRemove(ent)
{
    remove_task(ent);
}

/*--------------------------------[ Methods ]--------------------------------*/

Detonate(ent)
{
    new team = pev(ent, pev_team);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new Float:fLifeTime = 0.0;

    static Float:vSize[3];
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, vSize);
    vSize[2] = SmokeSize[2];

    static Float:fStackOriginsSum[3];
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, fStackOriginsSum);

    new stackSize = 0;
    new Float:fStackTotalLifeTime = 0.0;

    // merge nearby smoke entities into the stack
    new target = 0;
    while ((target = UTIL_FindEntityNearby(target, vOrigin, 96.0)) > 0) {
        if (CE_GetHandlerByEntity(target) != g_hCeMysterySmoke) {
            continue;
        }

        if (pev(ent, pev_team) != team) {
            continue;
        }

        new targetStackSize = pev(target, pev_iuser4);

        static Float:vTargetOrigin[3];
        pev(target, pev_origin, vTargetOrigin);

        static Float:vTargetMins[3];
        pev(target, pev_mins, vTargetMins);

        static Float:vTargetMaxs[3];
        pev(target, pev_maxs, vTargetMaxs);

        for (new i = 0; i < 3; ++i) {
            if (i != 2) {
                vSize[i] += vTargetMaxs[i] - vTargetMins[i];
            }

            fStackOriginsSum[i] += (vTargetOrigin[i] * targetStackSize);
        }

        static Float:fTargetKillTime;
        pev(target, pev_fuser4, fTargetKillTime);

        fStackTotalLifeTime += (fTargetKillTime - get_gametime()) * targetStackSize;
        stackSize += targetStackSize;

        CE_Kill(target);
    }

    if (stackSize) {
        for (new i = 0; i < 3; ++i) {
            vOrigin[i] = (fStackOriginsSum[i] + vOrigin[i]) / (stackSize + 1);
        }

        fLifeTime = fStackTotalLifeTime / stackSize;

        // calculate extra lifetime based on new smoke energy
        new Float:fLifetimeToAdd = SmokeLifeTime / stackSize;

        // calculating remaining smoke "energy" 
        new Float:fStackEnergyRemainder = (fLifeTime + fLifetimeToAdd - SmokeLifeTime) / SmokeLifeTime;
        fLifeTime = floatmin(fLifeTime + fLifetimeToAdd, SmokeLifeTime);

        if (fStackEnergyRemainder > 0 && stackSize <= SmokeStackMaxSize) {
            for (new i = 0; i < 2; ++i) {
                vSize[i] += SmokeSize[i] * (fStackEnergyRemainder * stackSize);
            }
        } else {
            xs_vec_mul_scalar(SmokeSize, float(stackSize), vSize);
        }

        // recalculate stack size based
        stackSize = floatround((vSize[0] + vSize[1]) / (SmokeSize[0] + SmokeSize[1]), floatround_ceil);
    } else {
        stackSize++;
        fLifeTime = SmokeLifeTime;
        xs_vec_copy(SmokeSize, vSize);
    }

    new smokeEnt = CreateSmoke(vOrigin, vSize, fLifeTime, pev(ent, pev_team), pev(ent, pev_owner));
    set_pev(smokeEnt, pev_iuser4, stackSize);
}

CreateSmoke(const Float:vOrigin[3], const Float:vSize[3], Float:fLifeTime, team, owner)
{
    new ent = CE_Create("hwn_mystery_smoke", vOrigin);
    if (!ent) {
        return 0;
    }

    static Float:vMins[3];
    static Float:vMaxs[3];

    for (new i = 0; i < 3; ++i) {
        if (i != 2) {
            vMins[i] = -vSize[i] / 2;
            vMaxs[i] = vSize[i] / 2;
        } else {
            vMins[i] = 0.0;
            vMaxs[i] = vSize[2];
        }
    }

    set_pev(ent, pev_team, team);
    set_pev(ent, pev_owner, owner);
    set_pev(ent, pev_fuser4, get_gametime() + fLifeTime);
    dllfunc(DLLFunc_Spawn, ent);
    engfunc(EngFunc_SetSize, ent, vMins, vMaxs);

    set_task(fLifeTime, "TaskRemoveMagicSmoke", ent);

    return ent;
}

public TaskRemoveMagicSmoke(taskID)
{
    new ent = taskID;
    CE_Kill(ent);
}
