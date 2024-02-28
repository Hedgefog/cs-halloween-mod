#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Skeleton Egg"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_skeleton_egg"
#define ENTITY_NAME_BIG "hwn_skeleton_egg_big"

#define m_bBig "bBig"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register(ENTITY_NAME, CEPreset_Prop);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_Register(ENTITY_NAME_BIG, CEPreset_Prop);
    CE_RegisterHook(ENTITY_NAME_BIG, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME_BIG, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME_BIG, CEFunction_Think, "@Entity_Think");
}

@Entity_Init(this) {
    new bool:bBig = CE_GetHandlerByEntity(this) == CE_GetHandler(ENTITY_NAME_BIG);

    if (bBig) {
        CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, -32.0});
        CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 32.0});
    } else {
        CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, -16.0});
        CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 16.0});
    }

    CE_SetMember(this, m_bBig, bBig);
    CE_SetMember(this, CE_MEMBER_RESPAWNTIME, HWN_ITEM_RESPAWN_TIME);
}

@Entity_Spawned(this) {
    set_pev(this, pev_solid, SOLID_NOT);
    set_pev(this, pev_movetype, MOVETYPE_BOUNCE);
    set_pev(this, pev_nextthink, get_gametime() + 2.0);
}

@Entity_Think(this) {
    @Entity_Birth(this);
    CE_Kill(this);
}

@Entity_Birth(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pSkeleton = CE_Create(
        CE_GetMember(this, m_bBig) ? "hwn_npc_skeleton" : "hwn_npc_skeleton_small",
        vecOrigin
    );

    if (!pSkeleton) return;

    set_pev(pSkeleton, pev_team, pev(this, pev_team));
    set_pev(pSkeleton, pev_owner, pev(this, pev_owner));
    dllfunc(DLLFunc_Spawn, pSkeleton);

    if (UTIL_IsStuck(pSkeleton)) CE_Kill(pSkeleton);
}
