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

#define ENTITY_NAME "hwn_projectile_egg"

#define m_szTargetClassname "szTargetClassname"

public plugin_precache() {
    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_base");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitPhysics, "@Entity_InitPhysics");

    CE_RegisterMethod(ENTITY_NAME, "Detonate", "@Entity_Detonate", CE_MP_Cell);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Init(this) {
    CE_SetMember(this, CE_MEMBER_RESPAWNTIME, HWN_ITEM_RESPAWN_TIME);
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-8.0, -8.0, -8.0}, false);
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{8.0, 8.0, 8.0}, false);
    CE_SetMemberString(this, m_szTargetClassname, NULL_STRING, false);
    CE_SetMember(this, CE_MEMBER_LIFETIME, 2.0);
}

@Entity_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_NOT);
    set_pev(this, pev_movetype, MOVETYPE_BOUNCE);
}

@Entity_Detonate(this, pDetonator) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static szClassname[CE_MAX_NAME_LENGTH]; CE_GetMemberString(this, m_szTargetClassname, szClassname, charsmax(szClassname));

    if (equal(szClassname, NULL_STRING)) return;

    new pEntity = CE_Create(szClassname, vecOrigin);
    if (!pEntity) return;

    set_pev(pEntity, pev_team, pev(this, pev_team));
    set_pev(pEntity, pev_owner, pev(this, pev_owner));
    dllfunc(DLLFunc_Spawn, pEntity);

    if (UTIL_IsStuck(pEntity)) CE_Kill(pEntity);

    CE_CallBaseMethod(pDetonator);
}
