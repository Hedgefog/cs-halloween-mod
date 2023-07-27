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

const Float:FireballDamage = 60.0;
const FireballSpeed = 720;

const Float:EffectRadius = 64.0;
new const EffectColor[3] = {255, 127, 47};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_fireball_impact.wav";
new const g_szSprFireball[] = "sprites/xsmoke1.spr";

new g_iEffectModelIndex;

new g_hSpell;
new g_hCeSpellball;

public plugin_precache() {
    g_iEffectModelIndex = precache_model("sprites/plasma.spr");
    precache_model(g_szSprFireball);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register(
        "Fireball",
        Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Radius,
        "Cast"
    );

    Hwn_Wof_Spell_Register("Fire", "Invoke", "Revoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "HamHook_Base_Touch_Post", .Post = 1);

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_Touch_Post(pEntity, pTarget) {
    if (!pev_valid(pEntity)) {
        return;
    }

    if (g_hCeSpellball != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    if (pev(pEntity, pev_iuser1) != g_hSpell) {
        return;
    }

    if (pTarget == pev(pEntity, pev_owner)) {
        return;
    }

    CE_Kill(pEntity);
}

public OnSpellballKilled(pEntity) {
    new iSpell = pev(pEntity, pev_iuser1);

    if (iSpell != g_hSpell) {
        return;
    }

    Detonate(pEntity);
}

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(pPlayer) {
    new pEntity = UTIL_HwnSpawnPlayerSpellball(pPlayer, EffectColor, FireballSpeed, g_szSprFireball, _, 0.5, 10.0);
    if (!pEntity) {
        return PLUGIN_HANDLED;
    }

    set_pev(pEntity, pev_iuser1, g_hSpell);
    set_pev(pEntity, pev_movetype, MOVETYPE_FLYMISSILE);

    emit_sound(pPlayer, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

public Invoke(pPlayer, Float:flTime) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    burn_player(pPlayer, 0);
    DetonateEffect(pPlayer);
}

public Revoke(pPlayer, Float:flTime) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    extinguish_player(pPlayer);
}

Detonate(pEntity) {
    new pOwner = pev(pEntity, pev_owner);
    new iTeam = get_member(pOwner, m_iTeam);

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EffectRadius * 2)) != 0) {
        if (pEntity == pTarget) {
            continue;
        }

        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        if (pTarget != pOwner && UTIL_IsTeammate(pTarget, iTeam)) {
            continue;
        }

        if (pTarget != pOwner && IS_PLAYER(pTarget)) {
            burn_player(pTarget, pOwner, 15);
        }

        if (IS_PLAYER(pTarget) || pev(pTarget, pev_flags) & FL_MONSTER) {
            UTIL_PushFromOrigin(vecOrigin, pTarget, 512.0);
        }

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        new Float:flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, EffectRadius, FireballDamage);

        ExecuteHamB(Ham_TakeDamage, pTarget, pEntity, pOwner, flDamage, DMG_BURN);
    }

    DetonateEffect(pEntity);
}

DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectModelIndex, 0, 3, 32, 255, EffectColor, 100, 0);
    emit_sound(pEntity, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}