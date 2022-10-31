#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Blink Spell"
#define AUTHOR "Hedgehog Fog"

const Float:SpellballDamage = 500.0;
const SpellballSpeed = 600;

const Float:EffectRadius = 48.0;
new const EffectColor[3] = {0, 0, 255};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_teleport.wav";

new g_szSprSpellBall[] = "sprites/enter1.spr";

new g_hSpell;
new g_hCeSpellball;

public plugin_precache()
{
    precache_model(g_szSprSpellBall);
    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register("Blink", Hwn_SpellFlag_Throwable, "OnCast");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
    RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "OnThink", .Post = 1);
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, EffectColor, SpellballSpeed, g_szSprSpellBall, _, 0.75, 10.0);

    if (!ent) {
        return PLUGIN_HANDLED;
    }

    set_pev(ent, pev_iuser1, g_hSpell);

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

public OnPlayerSpawn(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    new target = -1;
    while ((target = engfunc(EngFunc_FindEntityByString, target, "classname", SPELLBALL_ENTITY_CLASSNAME)) != 0) {
        if (pev(target, pev_iuser1) != g_hSpell) {
            continue;
        }

        set_pev(target, pev_owner, 0);
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

/*--------------------------------[ Methods ]--------------------------------*/

Detonate(ent)
{
    new owner = pev(ent, pev_owner);

    if (!owner) {
        return;
    }

    if (!is_user_alive(owner)) {
        return;
    }

    static Float:vOwnerOrigin[3];
    pev(owner, pev_origin, vOwnerOrigin);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    if (get_distance_f(vOwnerOrigin, vOrigin) > EffectRadius) {
        new hull = (pev(ent, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
        UTIL_FindPlaceToTeleport(owner, vOrigin, vOrigin, hull, IGNORE_MONSTERS);
        engfunc(EngFunc_SetOrigin, owner, vOrigin);
    }

    UTIL_ScreenFade(owner, {0, 0, 255}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
    BlinkEffect(owner);

    new target;
    while ((target = UTIL_FindEntityNearby(target, vOrigin, EffectRadius)) > 0) {
        if (owner == target) {
            continue;
        }

        if (pev(target, pev_deadflag) != DEAD_NO) {
            continue;
        }

        if (pev(target, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        ExecuteHamB(Ham_TakeDamage, target, ent, owner, SpellballDamage, DMG_ALWAYSGIB);
    }

    if (UTIL_IsStuck(owner)) {
        ExecuteHamB(Ham_TakeDamage, owner, 0, 0, SpellballDamage, DMG_ALWAYSGIB);
    }
}

BlinkEffect(ent)
{
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    emit_sound(ent, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    UTIL_Message_Dlight(vOrigin, 32, EffectColor, 5, 64);
    UTIL_Message_ParticleBurst(vOrigin, 32, 210, 1);
}