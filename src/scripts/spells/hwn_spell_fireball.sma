#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_advanced_pushing_system>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Fireball Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELL_NAME "Fireball"

const Float:FireballDamage = 60.0;
const FireballSpeed = 720;

const Float:EffectRadius = 64.0;
new const EffectColor[3] = {255, 127, 47};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_fireball_impact.wav";
new const g_szSprFireball[] = "sprites/xsmoke1.spr";

new g_iEffectModelIndex;
new g_iSpellHandler;

public plugin_precache() {
    g_iEffectModelIndex = precache_model("sprites/plasma.spr");
    precache_model(g_szSprFireball);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_iSpellHandler = Hwn_Spell_Register(
        SPELL_NAME,
        Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Radius,
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);
    CE_RegisterHook(CEFunction_Touch, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Touch");
    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Killed");
}

@Player_CastSpell(pPlayer) {
    new pSpellBall = UTIL_HwnSpawnPlayerSpellball(pPlayer, g_iSpellHandler, EffectColor, FireballSpeed, g_szSprFireball, _, 0.5, 10.0);
    @SpellBall_InitFireBall(pSpellBall);
    emit_sound(pPlayer, CHAN_STATIC, g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@SpellBall_Touch(this, pTarget) {
    if (@SpellBall_IsFireBall(this)) {
        @FireBall_Touch(this, pTarget);
    }
}

@SpellBall_Killed(this) {
    if (@SpellBall_IsFireBall(this)) {
        @FireBall_Detonate(this);
    }
}

@SpellBall_InitFireBall(this) {
    CE_SetMember(this, "iSpell", Hwn_Spell_GetHandler(SPELL_NAME));
    set_pev(this, pev_movetype, MOVETYPE_FLYMISSILE);
}

bool:@SpellBall_IsFireBall(this) {
    return CE_GetMember(this, "iSpell") == Hwn_Spell_GetHandler(SPELL_NAME);
}

@FireBall_Touch(this, pTarget) {
    if (pTarget == pev(this, pev_owner)) return;
    if (pev(pTarget, pev_solid) <= SOLID_TRIGGER) return;

    CE_Kill(this);
}

@FireBall_Detonate(this) {
    new pOwner = pev(this, pev_owner);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new Array:irgTargets = ArrayCreate();

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EffectRadius * 2)) != 0) {
        if (this == pTarget) continue;
        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) continue;
        if (!UTIL_CanTakeDamage(pTarget, pOwner)) continue;

        ArrayPushCell(irgTargets, pTarget);
    }

    new iTargetsNum = ArraySize(irgTargets);
    for (new i = 0; i < iTargetsNum; ++i) {
        new pTarget = ArrayGetCell(irgTargets, i);

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        new Float:flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, EffectRadius, FireballDamage);

        ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, flDamage, DMG_BURN);

        static Float:flDuration; flDuration = pOwner == pTarget ? 1.0 : 15.0;

        new pFire = CE_Create("fire", vecTargetOrigin);
        if (pFire) {
            dllfunc(DLLFunc_Spawn, pFire);
            set_pev(pFire, pev_owner, pOwner);
            set_pev(pFire, pev_aiment, pTarget);
            set_pev(pFire, pev_movetype, MOVETYPE_FOLLOW);
            CE_SetMember(pFire, CE_MEMBER_NEXTKILL, get_gametime() + flDuration);
            CE_SetMember(pFire, "bAllowSpread", false);
        }

        if (IS_PLAYER(pTarget) || UTIL_IsMonster(pTarget)) {
            if (IS_PLAYER(pTarget)) {
                set_ent_data_float(pTarget, "CBasePlayer", "m_flVelocityModifier", 1.0);
            }

            if (UTIL_GetWeight(pTarget) <= 1.0) {
                APS_PushFromOrigin(pTarget, 512.0, vecOrigin);
            }
        }
    }

    ArrayDestroy(irgTargets);

    @FireBall_DetonateEffect(this);
}

@FireBall_DetonateEffect(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectModelIndex, 0, 3, 32, 255, EffectColor, 100, 0);
    emit_sound(this, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
