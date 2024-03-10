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

#define PLUGIN "[Entity] Hwn Projectile Egg"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_skeletonball"

#define m_szTargetClassname "szTargetClassname"

#define SKELETON_EGG_COUNT 5

new const Float:EffectColorF[3] = {HWN_COLOR_SECONDARY_F};

new const g_szGibsModel[] = "models/bonegibs.mdl";
new const g_szEffectModel[] = "sprites/xsmoke1.spr";
new const g_szDetonateSound[] = "hwn/spells/spell_skeletons_horde_rise.wav";

public plugin_precache() {
    precache_model(g_szGibsModel);
    precache_model(g_szEffectModel);
    
    precache_sound(g_szDetonateSound);

    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_magicball");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");

    CE_RegisterMethod(ENTITY_NAME, "Detonate", "@Entity_Detonate", CE_MP_Cell);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Spawned(this) {
    CE_CallMethod(this, "SpawnEffect", g_szEffectModel, EffectColorF, 255.0, 0.75, 10.0);
}

@Entity_Detonate(this, pDetonator) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_FindPlaceToTeleport(this, vecOrigin, vecOrigin, HULL_HUMAN);

    @Entity_SpawnEggs(this);
    @Entity_DetonateEffect(this);

    CE_CallBaseMethod(pDetonator);
}

@Entity_DetonateEffect(this) {
    static Float:vecVelocity[3]; UTIL_RandomVector(-128.0, 128.0, vecVelocity);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    UTIL_Message_Dlight(vecOrigin, 36, {HWN_COLOR_SECONDARY}, 30, 12);
    UTIL_Message_BreakModel(vecOrigin, Float:{16.0, 16.0, 16.0}, vecVelocity, 30, engfunc(EngFunc_ModelIndex, g_szGibsModel), 20, 25, 0);
    emit_sound(this, CHAN_BODY , g_szDetonateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_SpawnEggs(this) {
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 32.0;

    new pOwner = pev(this, pev_owner);
    new iTeam = get_ent_data(pOwner, "CBasePlayer", "m_iTeam");

    for (new i = 0; i < SKELETON_EGG_COUNT; ++i) {
        new pEgg = CE_Create("hwn_projectile_egg", vecOrigin);
        if (!pEgg) break;

        set_pev(pEgg, pev_team, iTeam);
        set_pev(pEgg, pev_owner, pev(this, pev_owner));
        CE_SetMemberString(pEgg, "szTargetClassname", "hwn_npc_skeleton");
        CE_SetMemberVec(pEgg, CE_MEMBER_MINS, Float:{-8.0, -8.0, -16.0});
        CE_SetMemberVec(pEgg, CE_MEMBER_MAXS, Float:{8.0, 8.0, 16.0});
        dllfunc(DLLFunc_Spawn, pEgg);

        static Float:vecNewOrigin[3]; UTIL_FindPlaceToTeleport(pEgg, vecOrigin, vecNewOrigin, HULL_HUMAN);
        set_pev(pEgg, pev_origin, vecNewOrigin);

        static Float:vecVelocity[3]; xs_vec_set(vecVelocity, random_float(-96.0, 96.0), random_float(-96.0, 96.0), 128.0);
        CE_CallMethod(pEgg, "Launch", vecVelocity);
    }
}
