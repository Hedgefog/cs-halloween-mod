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

new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new g_szSprSpellBall[] = "sprites/xsmoke1.spr";

new g_hSpell;
new g_hCeSpellball;

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
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new spawnedEnt = CE_Create("hwn_mystery_smoke", vOrigin);

    if (!spawnedEnt) {
        return;
    }

    set_pev(spawnedEnt, pev_team, pev(ent, pev_team));
    set_pev(spawnedEnt, pev_owner, pev(ent, pev_owner));

    dllfunc(DLLFunc_Spawn, spawnedEnt);

    set_task(30.0, "TaskRemoveMagicSmoke", spawnedEnt);
}

public TaskRemoveMagicSmoke(taskID)
{
    new ent = taskID;
    CE_Kill(ent);
}
