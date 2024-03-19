#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_custom_entities>
#include <api_navsystem>

#include <entity_base_npc_const>

#include <hwn>

#define PLUGIN "[Entity] Hwn Base NPC"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_base"

public plugin_precache() {
    CE_RegisterDerived(ENTITY_NAME, BASE_NPC_ENTITY_NAME, true);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterVirtualMethod(ENTITY_NAME, UpdateGoal, "@Entity_AIThink");
    CE_RegisterVirtualMethod(ENTITY_NAME, GetPathCost, "@Entity_GetPathCost", CE_MP_Cell, CE_MP_Cell);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
}

@Entity_Init(this) {
    CE_SetMember(this, CE_MEMBER_LIFETIME, HWN_NPC_LIFE_TIME);
    CE_SetMember(this, CE_MEMBER_RESPAWNTIME, HWN_NPC_RESPAWN_TIME);
    CE_SetMember(this, m_flAIThinkRate, Hwn_GetNpcUpdateRate());
}

@Entity_AIThink(this) {
    CE_CallBaseMethod();
    static Array:irgPath; irgPath = CE_GetMember(this, m_irgPath);

    if (!CE_HasMember(this, m_vecGoal) && !CE_HasMember(this, m_vecTarget) && !ArraySize(irgPath)) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        static Float:vecGoal[3]; CE_GetMemberVec(this, CE_MEMBER_ORIGIN, vecGoal);

        if (xs_vec_distance(vecOrigin, vecGoal) > 32.0) {
            CE_SetMemberVec(this, m_vecGoal, vecGoal);
        }
    }
}

Float:@Entity_GetPathCost(this, NavArea:nextArea, NavArea:prevArea) {
    static Float:vecTarget[3]; Nav_Area_GetCenter(nextArea, vecTarget);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    static iSpawnAreaTeam; iSpawnAreaTeam = Hwn_Gamemode_GetSpawnAreaTeam(vecTarget);
    if (iSpawnAreaTeam) {
        return iSpawnAreaTeam == Hwn_Gamemode_GetSpawnAreaTeam(vecOrigin) ? 100.0 : -1.0;
    }

    return CE_CallBaseMethod(nextArea, prevArea);
}
