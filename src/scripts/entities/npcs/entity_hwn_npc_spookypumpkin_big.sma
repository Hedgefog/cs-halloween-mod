#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>

#include <entity_base_npc_const>

#define PLUGIN "[Custom Entity] Hwn NPC Spooky Pumpkin Big"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_spookypumpkin_big"

const Float:NPC_Health = 200.0;
const Float:NPC_Speed = 250.0;
const Float:NPC_Damage = 40.0;
const Float:NPC_AttackRange = 48.0;
const Float:NPC_AttackDelay = 0.35;

new const g_szModel[] = "models/hwn/npc/spookypumpkin_big.mdl";

public plugin_precache() {
    precache_model(g_szModel);

    CE_RegisterDerived(ENTITY_NAME, "hwn_npc_spookypumpkin");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -16.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 16.0, 32.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMember(this, m_flAttackRange, NPC_AttackRange);
    CE_SetMember(this, m_flAttackDelay, NPC_AttackDelay);
}

@Entity_Spawned(this) {
    CE_SetMember(this, m_flDamage, NPC_Damage);

    set_pev(this, pev_health, NPC_Health);
    set_pev(this, pev_maxspeed, NPC_Speed);
}