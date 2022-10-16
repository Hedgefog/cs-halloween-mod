#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Skeletons Horde Spell"
#define AUTHOR "Hedgehog Fog"

#define SKELETON_EGG_ENTITY_NAME "hwn_skeleton_egg_big"
#define SKELETON_EGG_COUNT 5

const SpellballSpeed = 720;

new const EffectColor[3] = {HWN_COLOR_SECONDARY};

new const g_szSndCast[] = "hwn/spells/spell_skeletons_horde_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_skeletons_horde_rise.wav";
new const g_szSprSpellBall[] = "sprites/xsmoke1.spr";

new g_mdlGibs;

new g_hSpell;
new g_hCeSpellball;

public plugin_precache()
{
    g_mdlGibs = precache_model("models/bonegibs.mdl");
    precache_model(g_szSprSpellBall);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register(
        "Skeletons Horde",
        Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Radius | Hwn_SpellFlag_Rare,
        "Cast"
    );
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Hooks ]--------------------------------*/

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

    CE_Kill(ent);
}

public OnSpellballKilled(ent)
{
    new spellIdx = pev(ent, pev_iuser1);

    if (spellIdx != g_hSpell) {
        return;
    }

    Detonate(ent);
}

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, EffectColor, SpellballSpeed, g_szSprSpellBall, _, 0.5, 10.0);
    if (!ent) {
        return PLUGIN_HANDLED;
    }

    set_pev(ent, pev_iuser1, g_hSpell);

    emit_sound(id, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

Detonate(ent)
{
    new owner = pev(ent, pev_owner);
    new team = UTIL_GetPlayerTeam(owner);

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 32.0;

    UTIL_FindPlaceToTeleport(ent, vOrigin, vOrigin, HULL_HUMAN);

    for (new i = 0; i < SKELETON_EGG_COUNT; ++i) {
        new eggEnt = CE_Create(SKELETON_EGG_ENTITY_NAME, vOrigin);

        if (!eggEnt) {
            continue;
        }

        set_pev(eggEnt, pev_origin, vOrigin);
        set_pev(eggEnt, pev_team, team);
        dllfunc(DLLFunc_Spawn, eggEnt);
        set_pev(eggEnt, pev_owner, owner);

        new Float:vVelocity[3];
        xs_vec_set(vVelocity, random_float(-96.0, 96.0), random_float(-96.0, 96.0), 128.0);
        set_pev(eggEnt, pev_velocity, vVelocity);
    }

    DetonateEffect(ent);
}

DetonateEffect(ent)
{
    new Float:vVelocity[3];
    UTIL_RandomVector(-128.0, 128.0, vVelocity);

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    UTIL_Message_Dlight(vOrigin, 16, {HWN_COLOR_SECONDARY}, 10, 32);

    UTIL_Message_BreakModel(vOrigin, Float:{16.0, 16.0, 16.0}, vVelocity, 10, g_mdlGibs, 20, 25, 0);

    emit_sound(ent, CHAN_BODY , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
