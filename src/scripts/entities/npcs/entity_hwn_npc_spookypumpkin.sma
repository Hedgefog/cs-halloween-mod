#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_navsystem>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn NPC Spooky Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_spookypumpkin"

#define m_flDamage "flDamage"
#define m_irgPath "irgPath"
#define m_vecGoal "vecGoal"
#define m_vecTarget "vecTarget"
#define m_pBuildPathTask "pBuildPathTask"
#define m_flReleaseAttack "flReleaseAttack"
#define m_flTargetArrivalTime "flTargetArrivalTime"
#define m_flNextAIThink "flNextAIThink"
#define m_flNextAction "flNextAction"
#define m_flNextAttack "flNextAttack"
#define m_flNextPathSearch "flNextPathSearch"
#define m_flNextLaugh "flNextLaugh"
#define m_pKiller "pKiller"
#define m_flReleaseJump "flReleaseJump"
#define m_bBig "bBig"
#define m_iType "iType"
// #define m_iSize "iSize"
#define m_flAttackRange "flAttackRange"
#define m_flAttackDelay "flAttackDelay"
#define m_flFindRange "flFindRange"
#define m_flViewRange "flViewRange"
#define m_flAttackRate "flAttackRate"

#define PlayAction "PlayAction"
#define Laugh "Laugh"
#define AIThink "AIThink"
#define MoveTo "MoveTo"
#define EmitVoice "EmitVoice"
#define IsInViewCone "IsInViewCone"

enum _:Sequence {
    Sequence_Idle = 0,
    Sequence_JumpStart,
    Sequence_JumpFloat,
    Sequence_Why,
    Sequence_Attack,
};

enum Action {
    Action_Idle = 0,
    Action_JumpStart,
    Action_JumpFloat,
    Action_Why,
    Action_Attack,
};

const Float:NPC_Health = 100.0;
const Float:NPC_Speed = 200.0; // for jump velocity
const Float:NPC_Damage = 20.0;
const Float:NPC_AttackRange = 48.0;
const Float:NPC_AttackDelay = 0.5;
const Float:NPC_ViewRange = 512.0;
const Float:NPC_FindRange = 2048.0;
const Float:NPC_PathSearchDelay = 5.0;
const Float:NPC_TargetUpdateRate = 1.0;
const Float:NPC_JumpVelocity = 160.0;
const Float:NPC_AttackJumpVelocity = 256.0;

new const g_szModel[] = "models/hwn/npc/spookypumpkin.mdl";
new const g_szGibsModel[] = "models/hwn/props/pumpkin_explode_jib_v2.mdl";

new const g_szSndLaugh[][] = {
    "hwn/npc/spookypumpkin/sp_laugh01.wav",
    "hwn/npc/spookypumpkin/sp_laugh02.wav",
    "hwn/npc/spookypumpkin/sp_laugh03.wav"
};

new const g_rgActions[Action][NPC_Action] = {
    { Sequence_Idle, Sequence_Idle, 0.0 },
    { Sequence_JumpStart, Sequence_JumpStart, 0.6 },
    { Sequence_JumpFloat, Sequence_JumpFloat, 0.0 },
    { Sequence_Why, Sequence_Why, 0.0 },
    { Sequence_Attack, Sequence_Attack, 1.2 }
};

new g_iGibsModelIndex;

public plugin_precache() {
    precache_model(g_szModel);
    g_iGibsModelIndex = precache_model(g_szGibsModel);

    for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
        precache_sound(g_szSndLaugh[i]);
    }

    CE_RegisterDerived(ENTITY_NAME, "hwn_npc_base");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");

    CE_RegisterMethod(ENTITY_NAME, PlayAction, "@Entity_PlayAction", CE_MP_Cell, CE_MP_Cell, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, Laugh, "@Entity_Laugh");
    CE_RegisterMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");
    CE_RegisterMethod(ENTITY_NAME, MoveTo, "@Entity_MoveTo", CE_MP_FloatArray, 3);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-12.0, -12.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{12.0, 12.0, 24.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMember(this, CE_MEMBER_BLOODCOLOR, 103);
    CE_SetMember(this, m_flAttackRange, NPC_AttackRange);
    CE_SetMember(this, m_flAttackDelay, NPC_AttackDelay);
    CE_SetMember(this, m_flFindRange, NPC_FindRange);
    CE_SetMember(this, m_flViewRange, NPC_ViewRange);
    CE_SetMember(this, m_flDamage, NPC_Damage);
    CE_SetMember(this, m_flAttackRate, 0.5);
}

@Entity_Spawned(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flNextLaugh, flGameTime);
    CE_SetMember(this, m_flReleaseJump, 0.0);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, HWN_COLOR_ORANGE_DIRTY_F);
    set_pev(this, pev_view_ofs, Float:{0.0, 0.0, 12.0});
    set_pev(this, pev_health, NPC_Health);
    set_pev(this, pev_maxspeed, NPC_Speed);
    set_pev(this, pev_fov, 30.0);

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecMaxs[3]; CE_GetMemberVec(this, CE_MEMBER_MAXS, vecMaxs);

    UTIL_Message_Dlight(vecOrigin, floatround(floatmax(vecMaxs[0], vecMaxs[1])), {HWN_COLOR_YELLOW}, 20, 8);

    CE_CallMethod(this, Laugh);
}

@Entity_Killed(this) {
    @Entity_DisappearEffect(this);
}

@Entity_AIThink(this) {
    CE_CallBaseMethod();

    static Float:flGameTime; flGameTime = get_gametime();

    static Float:flReleaseJump; flReleaseJump = CE_GetMember(this, m_flReleaseJump);
    if (flReleaseJump && flReleaseJump <= flGameTime) {
        @Entity_Jump(this);
        CE_SetMember(this, m_flReleaseJump, 0.0);
    }

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

@Entity_MoveTo(this, const Float:vecTarget[3]) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flLastThink; pev(this, pev_ltime, flLastThink);
    static Float:flDelta; flDelta = flGameTime - flLastThink;
    static Float:flMaxAngle; flMaxAngle = 180.0 * floatmin(flDelta, 0.1);

    UTIL_TurnTo(this, vecTarget, bool:{true, false, true}, flMaxAngle);

    if (CE_CallMethod(this, IsInViewCone, vecTarget)) {
        @Entity_StartJump(this);
    }
}

bool:@Entity_StartJump(this) {
    if (~pev(this, pev_flags) & FL_ONGROUND) return false;

    static Float:flReleaseJump; flReleaseJump = CE_GetMember(this, m_flReleaseJump);
    if (flReleaseJump) return false;

    static Float:flGameTime; flGameTime = get_gametime();
    CE_SetMember(this, m_flReleaseJump, flGameTime + g_rgActions[Action_JumpStart][NPC_Action_Time]);
    CE_CallMethod(this, PlayAction, Action_JumpStart, false);

    return true;
}

bool:@Entity_Jump(this) {
    if (~pev(this, pev_flags) & FL_ONGROUND) return;

    static Float:flReleaseAttack; flReleaseAttack = CE_GetMember(this, m_flReleaseAttack);
    static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);

    static Float:vecVelocity[3];
    UTIL_GetDirectionVector(this, vecVelocity, flMaxSpeed);
    vecVelocity[2] = flReleaseAttack ? NPC_AttackJumpVelocity : NPC_JumpVelocity;

    set_pev(this, pev_velocity, vecVelocity);

    CE_CallMethod(this, PlayAction, Action_JumpFloat, false);
}

bool:@Entity_PlayAction(this, Action:iAction, bool:bSupercede) {
    return CE_CallBaseMethod(g_rgActions[iAction][NPC_Action_StartSequence], g_rgActions[iAction][NPC_Action_EndSequence], g_rgActions[iAction][NPC_Action_Time], bSupercede);
}

Action:@Entity_GetAction(this) {
    new Action:iAction = Action_Idle;

    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (CE_GetMember(this, m_flReleaseAttack) > 0.0) {
                iAction = Action_Attack;
            } if (~pev(this, pev_flags) & FL_ONGROUND) {
                iAction = Action_JumpFloat;
            }
        }
    }

    return iAction;
}

@Entity_DisappearEffect(this) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecVelocity[3]; UTIL_RandomVector(-16.0, 16.0, vecVelocity);
    static Float:vecMaxs[3]; CE_GetMemberVec(this, CE_MEMBER_MAXS, vecMaxs);

    UTIL_Message_Dlight(vecOrigin, floatround(floatmax(vecMaxs[0], vecMaxs[1])), {HWN_COLOR_YELLOW}, 10, 32);
    UTIL_Message_BreakModel(vecOrigin, Float:{4.0, 4.0, 4.0}, vecVelocity, 32, g_iGibsModelIndex, 4, 25, 0);
}

@Entity_Laugh(this) {
    CE_CallMethod(this, EmitVoice, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}
