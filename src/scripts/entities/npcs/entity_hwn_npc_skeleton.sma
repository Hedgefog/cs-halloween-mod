#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#include <entity_base_npc_const>

#define PLUGIN "[Custom Entity] Hwn NPC Skeleton"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_skeleton"

#define SKELETON_EGG_ENTITY_NAME "hwn_skeleton_egg"
#define SKELETON_EGG_COUNT 2

#define m_flNextLaugh "flNextLaugh"

#define EmitVoice "EmitVoice"
#define SpawnEggs "SpawnEggs"
#define Laugh "Laugh"

enum _:Sequence {
    Sequence_Idle = 0,

    Sequence_Run,

    Sequence_Attack,
    Sequence_RunAttack,

    Sequence_Spawn1,
    Sequence_Spawn2,
    Sequence_Spawn3,
    Sequence_Spawn4,
    Sequence_Spawn5,
    Sequence_Spawn6,
    Sequence_Spawn7,
};

enum Action {
    Action_Invalid = -1,
    Action_Idle,
    Action_Run,
    Action_Attack,
    Action_RunAttack,
    Action_Spawn
};

new const g_rgActions[Action][NPC_Action] = {
    {    Sequence_Idle,         Sequence_Idle,          0.0    },
    {    Sequence_Run,          Sequence_Run,           0.0    },
    {    Sequence_Attack,       Sequence_Attack,        1.0    },
    {    Sequence_RunAttack,    Sequence_RunAttack,     1.0    },
    {    Sequence_Spawn1,       Sequence_Spawn7,        2.0    }
};

new const Action:g_rgiRelatedActions[Action] = { _:Action_Invalid, _:Action_Invalid, _:Action_RunAttack, _:Action_Attack, _:Action_Invalid };

new const g_szSndLaugh[][] = {
    "hwn/npc/skeleton/skelly_medium_01.wav",
    "hwn/npc/skeleton/skelly_medium_02.wav",
    "hwn/npc/skeleton/skelly_medium_03.wav",
    "hwn/npc/skeleton/skelly_medium_04.wav",
    "hwn/npc/skeleton/skelly_medium_05.wav"
};

new const g_szModel[] = "models/hwn/npc/skeleton_v2.mdl";
new const g_szGibsModel[] = "models/bonegibs.mdl";
new const g_szSndBreak[] = "hwn/npc/skeleton/skeleton_break.wav";

new g_iGibsModelIndex;

public plugin_precache() {
    precache_model(g_szModel);
    g_iGibsModelIndex = precache_model(g_szGibsModel);

    precache_sound(g_szSndBreak);

    for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
        precache_sound(g_szSndLaugh[i]);
    }

    CE_RegisterDerived(ENTITY_NAME, "hwn_npc_base");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");

    CE_RegisterMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");

    CE_RegisterVirtualMethod(ENTITY_NAME, PlayAction, "@Entity_PlayAction", CE_MP_Cell, CE_MP_Cell);
    CE_RegisterVirtualMethod(ENTITY_NAME, SpawnEggs, "@Entity_SpawnEggs");
    CE_RegisterVirtualMethod(ENTITY_NAME, Laugh, "@Entity_Laugh");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, -32.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 32.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMember(this, CE_MEMBER_BLOODCOLOR, 242);
    CE_SetMember(this, m_flAttackRange, 48.0);
    CE_SetMember(this, m_flHitRange, 52.0);
    CE_SetMember(this, m_flAttackDuration, 1.0);
    CE_SetMember(this, m_flHitDelay, 0.5);
    CE_SetMember(this, m_flFindRange, 2048.0);
    CE_SetMember(this, m_flViewRange, 512.0);
    CE_SetMember(this, m_flDamage, 24.0);
    CE_SetMember(this, m_flAttackRate, 1.0);
}

@Entity_Spawned(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    CE_SetMember(this, m_flNextLaugh, flGameTime);

    set_pev(this, pev_groupinfo, 128);
    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, Float:{0.0, 0.0, 0.0});
    set_pev(this, pev_health, 100.0);
    set_pev(this, pev_maxspeed, 230.0);

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecMaxs[3]; CE_GetMemberVec(this, CE_MEMBER_MAXS, vecMaxs);
    UTIL_Message_Dlight(vecOrigin, floatround(floatmax(vecMaxs[0], vecMaxs[1])), {HWN_COLOR_SECONDARY}, 20, 8);

    CE_CallMethod(this, PlayAction, Action_Spawn, false);
    @Entity_UpdateColor(this);

    set_pev(this, pev_nextthink, flGameTime + g_rgActions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Killed(this) {
    CE_CallMethod(this, SpawnEggs);

    @Entity_DisappearEffect(this);
}

@Entity_AIThink(this) {
    CE_CallBaseMethod();

    static Float:flGameTime; flGameTime = get_gametime();
    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);

    if (xs_vec_len(vecVelocity) > 50.0) {
        static Float:flNextLaugh; flNextLaugh = CE_GetMember(this, m_flNextLaugh);
        if (flNextLaugh <= flGameTime) {
            CE_CallMethod(this, Laugh);
            CE_SetMember(this, m_flNextLaugh, flGameTime + random_float(1.0, 2.0));
        }
    }

    static Action:iAction; iAction = @Entity_GetAction(this);
    CE_CallMethod(this, PlayAction, iAction, false);
}

bool:@Entity_PlayAction(this, Action:iAction, bool:bSupercede) {
    if (@Entity_IsRelatedAction(this, iAction)) {
        set_pev(this, pev_sequence, g_rgActions[iAction][NPC_Action_StartSequence]);
        return true;
    }

    return CE_CallBaseMethod(g_rgActions[iAction][NPC_Action_StartSequence], g_rgActions[iAction][NPC_Action_EndSequence], g_rgActions[iAction][NPC_Action_Time], bSupercede);
}

@Entity_IsRelatedAction(this, Action:iAction) {
    new Action:iRelatedAction = g_rgiRelatedActions[iAction];
    if (iRelatedAction == Action_Invalid) return false;

    new iSequence = pev(this, pev_sequence);
    if (iSequence < g_rgActions[iRelatedAction][NPC_Action_StartSequence]) return false;
    if (iSequence > g_rgActions[iRelatedAction][NPC_Action_EndSequence]) return false;

    return true;
}

Action:@Entity_GetAction(this) {
    static Action:iAction; iAction = Action_Idle;
    static iDeadFlag; iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (CE_GetMember(this, m_flReleaseAttack) > 0.0) {
                iAction = Action_Attack;
            }

            if (CE_HasMember(this, m_vecInput)) {
                iAction = iAction == Action_Attack ? Action_RunAttack : Action_Run;
            }
        }
    }

    return iAction;
}

@Entity_UpdateColor(this) {
    new iTeam = pev(this, pev_team);

    switch (iTeam) {
        case 0: set_pev(this, pev_rendercolor, {HWN_COLOR_SECONDARY_F});
        case 1: set_pev(this, pev_rendercolor, {HWN_COLOR_RED_F});
        case 2: set_pev(this, pev_rendercolor, {HWN_COLOR_BLUE_F});
    }
}

@Entity_DisappearEffect(this) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecVelocity[3]; UTIL_RandomVector(-48.0, 48.0, vecVelocity);
    static Float:vecMaxs[3]; CE_GetMemberVec(this, CE_MEMBER_MAXS, vecMaxs);

    UTIL_Message_Dlight(vecOrigin, floatround(floatmax(vecMaxs[0], vecMaxs[1])), {HWN_COLOR_SECONDARY}, 10, 32);
    UTIL_Message_BreakModel(vecOrigin, Float:{16.0, 16.0, 16.0}, vecVelocity, 10, g_iGibsModelIndex, 5, 25, 0);

    emit_sound(this, CHAN_BODY, g_szSndBreak, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_SpawnEggs(this) {
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    for (new i = 0; i < SKELETON_EGG_COUNT; ++i) {
        new pEgg = CE_Create("hwn_projectile_egg", vecOrigin);
        if (!pEgg) continue;

        set_pev(pEgg, pev_team, pev(this, pev_team));
        set_pev(pEgg, pev_owner, pev(this, pev_owner));
        CE_SetMemberString(pEgg, "szTargetClassname", "hwn_npc_skeleton_small");
        CE_SetMemberVec(pEgg, CE_MEMBER_MINS, Float:{-8.0, -8.0, -16.0});
        CE_SetMemberVec(pEgg, CE_MEMBER_MAXS, Float:{8.0, 8.0, 16.0});
        dllfunc(DLLFunc_Spawn, pEgg);

        new Float:vecVelocity[3]; xs_vec_set(vecVelocity, random_float(-96.0, 96.0), random_float(-96.0, 96.0), 128.0);
        CE_CallMethod(pEgg, "Launch", vecVelocity);
    }
}

@Entity_Laugh(this) {
    CE_CallMethod(this, EmitVoice, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}
