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

#include <entity_base_npc_const>

#define PLUGIN "[Custom Entity] Hwn NPC Spooky Pumpkin"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_spookypumpkin"

#define m_flNextLaugh "flNextLaugh"
#define m_flReleaseJump "flReleaseJump"
#define m_flJumpVelocity "flJumpVelocity"

#define Laugh "Laugh"

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
    Action_Attack
};

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
    { Sequence_JumpStart, Sequence_JumpStart, 0.5 },
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
    CE_RegisterMethod(ENTITY_NAME, CanAttack, "@Entity_CanAttack", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, Laugh, "@Entity_Laugh");
    CE_RegisterMethod(ENTITY_NAME, MoveForward, "@Entity_MoveForward");
    CE_RegisterMethod(ENTITY_NAME, StartAttack, "@Entity_StartAttack");
    CE_RegisterMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");
    CE_RegisterMethod(ENTITY_NAME, MovementThink, "@Entity_MovementThink");
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
    CE_SetMember(this, m_flAttackRange, 64.0);
    CE_SetMember(this, m_flHitRange, 52.0);
    CE_SetMember(this, m_flAttackRate, 1.0);
    CE_SetMember(this, m_flAttackDuration, 1.5);
    CE_SetMember(this, m_flHitDelay, 0.5);
    CE_SetMember(this, m_flFindRange, 2048.0);
    CE_SetMember(this, m_flViewRange, 512.0);
    CE_SetMember(this, m_flDamage, 20.0);
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
    set_pev(this, pev_health, 100.0);
    set_pev(this, pev_maxspeed, 200.0);
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

    CE_CallMethod(this, PlayAction, @Entity_GetAction(this), false);
}

@Entity_StartAttack(this) {
    CE_CallBaseMethod();
    CE_CallMethod(this, MoveForward);
}

@Entity_MovementThink(this) {}

@Entity_MoveForward(this) {
    @Entity_StartJump(this);
}

bool:@Entity_CanAttack(this, pEnemy) {
    if (~pev(this, pev_flags) & FL_ONGROUND) return false;

    return CE_CallBaseMethod(pEnemy);
}

bool:@Entity_StartJump(this) {
    if (~pev(this, pev_flags) & FL_ONGROUND) return false;

    static Float:flReleaseJump; flReleaseJump = CE_GetMember(this, m_flReleaseJump);
    if (flReleaseJump) return false;


    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flReleaseAttack; flReleaseAttack = CE_GetMember(this, m_flReleaseAttack);

    CE_SetMember(this, m_flReleaseJump, flGameTime + 0.5);
    CE_SetMember(this, m_flJumpVelocity, flReleaseAttack ? NPC_AttackJumpVelocity : NPC_JumpVelocity);
    CE_CallMethod(this, PlayAction, Action_JumpStart, true);

    return true;
}

bool:@Entity_Jump(this) {
    if (~pev(this, pev_flags) & FL_ONGROUND) return;

    static Float:flMaxSpeed; pev(this, pev_maxspeed, flMaxSpeed);

    static Float:vecVelocity[3];
    UTIL_GetDirectionVector(this, vecVelocity, flMaxSpeed);
    vecVelocity[2] = Float:CE_GetMember(this, m_flJumpVelocity);

    set_pev(this, pev_velocity, vecVelocity);
}

bool:@Entity_PlayAction(this, Action:iAction, bool:bSupercede) {
    return CE_CallBaseMethod(g_rgActions[iAction][NPC_Action_StartSequence], g_rgActions[iAction][NPC_Action_EndSequence], g_rgActions[iAction][NPC_Action_Time], bSupercede);
}

Action:@Entity_GetAction(this) {
    new Action:iAction = Action_Idle;

    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            if (~pev(this, pev_flags) & FL_ONGROUND) {
                iAction = CE_GetMember(this, m_flReleaseAttack) ? Action_Attack : Action_JumpFloat;
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
