#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Entity] Hwn Blinkball"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_blinkball"

new const g_szDetonateSound[] = "hwn/spells/spell_teleport.wav";
new const g_szEffectModel[] = "sprites/enter1.spr";

const Float:ProjectileExplodeDamage = 500.0;
const Float:ProjectileExplodeRadius = 48.0;
new const Float:ProjectileColorF[3] = {0.0, 0.0, 255.0};
new const ProjectileColor[3] = {0, 0, 255};

public plugin_precache() {
    precache_sound(g_szDetonateSound);
    precache_model(g_szEffectModel);
    
    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_magicball");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");

    CE_RegisterMethod(ENTITY_NAME, "Detonate", "@Entity_Detonate", CE_MP_Cell);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
}

@Entity_Spawned(this) {
    set_pev(this, pev_rendercolor, ProjectileColorF);

    CE_CallMethod(this, "SpawnEffect", g_szEffectModel, ProjectileColorF, 255.0, 0.75, 10.0);
}

@Entity_Detonate(this, pDetonator) {
    new pOwner = pev(this, pev_owner);

    if (!pOwner) return;
    if (!is_user_alive(pOwner)) return;

    static Float:vecOwnerOrigin[3]; pev(pOwner, pev_origin, vecOwnerOrigin);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    if (get_distance_f(vecOwnerOrigin, vecOrigin) > ProjectileExplodeRadius) {
        new iHull = (pev(this, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
        UTIL_FindPlaceToTeleport(pOwner, vecOrigin, vecOrigin, iHull, IGNORE_MONSTERS);
        engfunc(EngFunc_SetOrigin, pOwner, vecOrigin);
    }

    UTIL_ScreenFade(pOwner, {0, 0, 255}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
    @Entity_DetonateEffect(pOwner);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, ProjectileExplodeRadius)) > 0) {
        if (pOwner == pTarget) continue;
        if (pev(pTarget, pev_deadflag) != DEAD_NO) continue;
        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) continue;
        ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, ProjectileExplodeDamage, DMG_ALWAYSGIB);
    }

    if (UTIL_IsStuck(pOwner)) {
        ExecuteHamB(Ham_TakeDamage, pOwner, 0, 0, ProjectileExplodeDamage, DMG_ALWAYSGIB);
    }

    CE_CallBaseMethod(pDetonator);
}

@Entity_DetonateEffect(this) {
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    UTIL_Message_Dlight(vecOrigin, 32, ProjectileColor, 5, 64);
    UTIL_Message_ParticleBurst(vecOrigin, 32, 210, 1);
    emit_sound(this, CHAN_STATIC , g_szDetonateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) return HAM_IGNORED;

    new pTarget = -1;
    while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "classname", ENTITY_NAME)) != 0) {
        set_pev(pTarget, pev_owner, 0);
    }

    return HAM_HANDLED;
}
