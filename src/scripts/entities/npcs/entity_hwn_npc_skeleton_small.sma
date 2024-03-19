#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>

#include <entity_base_npc_const>

#define PLUGIN "[Custom Entity] Hwn NPC Skeleton Small"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_skeleton_small"

const Float:NPC_Health = 50.0;
const Float:NPC_Speed = 250.0;
const Float:NPC_Damage = 12.0;
const Float:NPC_AttackRange = 48.0;
const Float:NPC_AttackDelay = 0.35;

new const g_szSndLaugh[][] = {
    "hwn/npc/skeleton/skelly_small_01.wav",
    "hwn/npc/skeleton/skelly_small_02.wav",
    "hwn/npc/skeleton/skelly_small_03.wav",
    "hwn/npc/skeleton/skelly_small_04.wav",
    "hwn/npc/skeleton/skelly_small_05.wav"
};

new const g_szModel[] = "models/hwn/npc/skeleton_small_v3.mdl";

public plugin_precache() {
    precache_model(g_szModel);

    for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
        precache_sound(g_szSndLaugh[i]);
    }

    CE_RegisterDerived(ENTITY_NAME, "hwn_npc_skeleton");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    
    CE_RegisterMethod(ENTITY_NAME, "Laugh", "@Entity_Laugh");
    CE_RegisterMethod(ENTITY_NAME, "SpawnEggs", "@Entity_SpawnEggs");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-8.0, -8.0, -16.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{8.0, 8.0, 16.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, true);
    CE_SetMember(this, m_flAttackRange, NPC_AttackRange);
    CE_SetMember(this, m_flAttackDelay, NPC_AttackDelay);
}

@Entity_Spawned(this) {
    CE_SetMember(this, m_flDamage, NPC_Damage);

    set_pev(this, pev_health, NPC_Health);
    set_pev(this, pev_maxspeed, NPC_Speed);
}

@Entity_Laugh(this) {
    CE_CallMethod(this, EmitVoice, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}

@Entity_SpawnEggs(this) {}
