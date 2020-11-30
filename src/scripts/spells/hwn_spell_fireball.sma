#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_player_burn>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Fireball Spell"
#define AUTHOR "Hedgehog Fog"

const Float:FireballDamage = 30.0;
const FireballSpeed = 720;

const Float:EffectRadius = 64.0;
new const EffectColor[3] = {255, 127, 47};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_fireball_impact.wav";
new const g_szSprFireball[] = "sprites/xsmoke1.spr";

new g_sprEffect;

new g_hSpell;
new g_hWofSpell;
new g_hCeSpellball;

public plugin_precache()
{
    g_sprEffect = precache_model("sprites/plasma.spr");
    precache_model(g_szSprFireball);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register(
        "Fireball",
        Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Radius,
        "Cast"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Fire", "Invoke");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    if (g_hWofSpell == spellIdx) {
        Hwn_Wof_Abort();
    }
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
    new ent = UTIL_HwnSpawnPlayerSpellball(id, EffectColor, FireballSpeed, g_szSprFireball, _, 0.5, 10.0);
    if (!ent) {
        return PLUGIN_HANDLED;
    }

    set_pev(ent, pev_iuser1, g_hSpell);
    set_pev(ent, pev_movetype, MOVETYPE_FLYMISSILE);

    emit_sound(id, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

public Invoke(id, Float:fTime)
{
    if (!is_user_alive(id)) {
        return;
    }

    burn_player(id, 0, floatround(fTime));
    DetonateEffect(id);
}

Detonate(ent)
{
    new owner = pev(ent, pev_owner);
    new team = UTIL_GetPlayerTeam(owner);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new target;
    while ((target = UTIL_FindEntityNearby(target, vOrigin, EffectRadius * 2)) != 0) {
        if (ent == target) {
            continue;
        }

        if (pev(target, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        if (target == owner) {
            continue;
        }

        static Float:vTargetOrigin[3];
        pev(target, pev_origin, vTargetOrigin);

        new Float:fDamage = UTIL_CalculateRadiusDamage(vOrigin, vTargetOrigin, EffectRadius, FireballDamage);

        if (UTIL_IsPlayer(target)) {
            if (team == UTIL_GetPlayerTeam(target)) {
                continue;
            }

            static Float:vDirection[3];
            xs_vec_sub(vOrigin, vTargetOrigin, vDirection);
            xs_vec_normalize(vDirection, vDirection);
            xs_vec_mul_scalar(vDirection, -512.0, vDirection);

            static Float:vTargetVelocity[3];
            pev(target, pev_velocity, vTargetVelocity);
            xs_vec_add(vTargetVelocity, vDirection, vTargetVelocity);
            set_pev(target, pev_velocity, vTargetVelocity);

            UTIL_CS_DamagePlayer(target, fDamage, DMG_BURN, owner, 0);
            burn_player(target, owner, 15);
        } else {
            ExecuteHamB(Ham_TakeDamage, target, 0, owner, fDamage, DMG_BURN);
        }
    }

    DetonateEffect(ent);
}

DetonateEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_BeamCylinder(vOrigin, EffectRadius * 3, g_sprEffect, 0, 3, 32, 255, EffectColor, 100, 0);
    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}