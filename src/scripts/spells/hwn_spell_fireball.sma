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

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 127, 47};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_fireball_impact.wav";

new g_sprSpellball;
new g_sprSpellballTrace;

new g_hSpell;

new g_hCeSpellball;

public plugin_precache()
{
    g_sprSpellball = precache_model("sprites/rjet1.spr");
    g_sprSpellballTrace = precache_model("sprites/xbeam4.spr");

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);

    g_hSpell = Hwn_Spell_Register("Fireball", "OnCast");
    Hwn_Wof_Spell_Register("Fire", "Invoke", "Revoke");

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, g_sprSpellball, EffectColor);

    if (!ent) {
        return PLUGIN_HANDLED;
    }

    set_pev(ent, pev_iuser1, g_hSpell);
    set_pev(ent, pev_movetype, MOVETYPE_FLYMISSILE);

    emit_sound(id, CHAN_BODY, g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

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

public Invoke(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    burn_player(id);
    DetonateEffect(id, vOrigin);
}

public Revoke(id)
{
    extinguish_player(id);
}

/*--------------------------------[ Methods ]--------------------------------*/

Detonate(ent)
{
    new owner = pev(ent, pev_owner);
    new team = UTIL_GetPlayerTeam(owner);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new Array:nearbyEntities = UTIL_FindEntityNearby(vOrigin, EffectRadius);
    new size = ArraySize(nearbyEntities);

    for (new i = 0; i < size; ++i) {
        new target = ArrayGetCell(nearbyEntities, i);

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

    ArrayDestroy(nearbyEntities);

    DetonateEffect(ent, vOrigin);
}

DetonateEffect(ent, const Float:vOrigin[3])
{
    UTIL_HwnSpellDetonateEffect(
      .modelindex = g_sprSpellballTrace,
      .vOrigin = vOrigin,
      .fRadius = EffectRadius,
      .color = EffectColor
    );

    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}