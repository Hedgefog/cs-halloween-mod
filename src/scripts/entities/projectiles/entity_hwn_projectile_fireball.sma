#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_advanced_pushing>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Entity] Hwn Fireball"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_fireball"

const Float:ProjectileExplodeDamage = 60.0;
const Float:ProjectileExplodeRadius = 64.0;
new const Float:ProjectileColorF[3] = {255.0, 127.0, 47.0};
new const ProjectileColor[3] = {255, 127, 47};

new const g_szBeamModel[] = "sprites/xsmoke1.spr";
new const g_szEffectModel[] = "sprites/xsmoke1.spr";
new const g_szDetonateSound[] = "hwn/spells/spell_fireball_impact.wav";

public plugin_precache() {
    precache_model(g_szEffectModel);
    precache_model(g_szBeamModel);

    precache_sound(g_szDetonateSound);

    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_magicball");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");

    CE_RegisterMethod(ENTITY_NAME, "Detonate", "@Entity_Detonate", CE_MP_Cell);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Spawned(this) {
    CE_CallMethod(this, "SpawnEffect", g_szEffectModel, ProjectileColorF, 255.0, 0.5, 10.0);
}

@Entity_Detonate(this, pDetonator) {
    new pOwner = pev(this, pev_owner);
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    new Array:irgTargets = ArrayCreate();

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, ProjectileExplodeRadius * 2)) != 0) {
        if (this == pTarget) continue;
        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) continue;
        if (!UTIL_CanTakeDamage(pTarget, pOwner)) continue;

        ArrayPushCell(irgTargets, pTarget);
    }

    new iTargetsNum = ArraySize(irgTargets);
    for (new i = 0; i < iTargetsNum; ++i) {
        new pTarget = ArrayGetCell(irgTargets, i);

        static Float:vecTargetOrigin[3]; pev(pTarget, pev_origin, vecTargetOrigin);
        static Float:flDuration; flDuration = pOwner == pTarget ? 1.0 : 15.0;
        static Float:flDamage; flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, ProjectileExplodeRadius, ProjectileExplodeDamage);

        ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, flDamage, DMG_BURN);

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

    @Entity_DetonateEffect(this);

    CE_CallBaseMethod(pDetonator);
}

@Entity_DetonateEffect(this) {
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    UTIL_Message_BeamCylinder(vecOrigin, ProjectileExplodeRadius * 3, engfunc(EngFunc_ModelIndex, g_szBeamModel), 0, 3, 32, 255, ProjectileColor, 100, 0);
    emit_sound(this, CHAN_BODY, g_szDetonateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
