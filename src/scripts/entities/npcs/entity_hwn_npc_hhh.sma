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

#define PLUGIN "[Custom Entity] Hwn NPC HHH"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_hhh"

#define m_flNextLightEmit "flNextLightEmit"
#define m_flNextSmokeEmit "flNextSmokeEmit"
#define m_flNextLaugh "flNextLaugh"
#define m_flNextFootStep "flNextFootStep"

#define Laugh "Laugh"

enum _:Sequence {
    Sequence_Idle = 0,
    Sequence_Run,
    Sequence_Attack,
    Sequence_RunAttack,
    Sequence_Shake,
    Sequence_Spawn
};

enum Action {
    Action_Idle = 0,
    Action_Run,
    Action_Attack,
    Action_RunAttack,
    Action_Shake,
    Action_Spawn
};

new const g_szModel[] = "models/hwn/npc/headless_hatman.mdl";

new const g_szSndAttack[][128] = {
    "hwn/npc/hhh/hhh_attack01.wav",
    "hwn/npc/hhh/hhh_attack02.wav",
    "hwn/npc/hhh/hhh_attack03.wav",
    "hwn/npc/hhh/hhh_attack04.wav"
};

new const g_szSndLaugh[][128] = {
    "hwn/npc/hhh/hhh_laugh01.wav",
    "hwn/npc/hhh/hhh_laugh02.wav",
    "hwn/npc/hhh/hhh_laugh03.wav",
    "hwn/npc/hhh/hhh_laugh04.wav"
};

new const g_szSndPain[][128] = {
    "hwn/npc/hhh/hhh_pain01.wav",
    "hwn/npc/hhh/hhh_pain02.wav",
    "hwn/npc/hhh/hhh_pain03.wav"
};

new const g_szSndStep[][128] = {
    "hwn/npc/hhh/hhh_step01.wav",
    "hwn/npc/hhh/hhh_step02.wav"
};

new const g_szSndHit[] = "hwn/npc/hhh/hhh_axe_hit.wav";
new const g_szSndSpawn[] = "hwn/npc/hhh/hhh_spawn.wav";
new const g_szSndDying[] = "hwn/npc/hhh/hhh_dying.wav";
new const g_szSndDeath[] = "hwn/npc/hhh/hhh_death.wav";

new const g_rgActions[Action][NPC_Action] = {
    { Sequence_Idle, Sequence_Idle, 0.0 },
    { Sequence_Run, Sequence_Run, 0.0 },
    { Sequence_Attack, Sequence_Attack, 0.75 },
    { Sequence_RunAttack, Sequence_RunAttack, 0.75 },
    { Sequence_Shake, Sequence_Shake, 2.0 },
    { Sequence_Spawn, Sequence_Spawn, 6.0 }
};

const Float:NPC_Health = 4000.0;
const Float:NPC_HealthBonusPerPlayer = 300.0;
const Float:NPC_Speed = 300.0;
const Float:NPC_Damage = 160.0;
const Float:NPC_AttackRange = 96.0;
const Float:NPC_AttackDelay = 0.75;
const Float:NPC_PathSearchDelay = 5.0;
const Float:NPC_TargetUpdateRate = 1.0;
const Float:NPC_ViewRange = 512.0;
const Float:NPC_FindRange = 4096.0;
new const Float:NPC_TargetHitOffset[3] = {0.0, 0.0, 16.0};

new gmsgScreenShake;

new g_iSmokeModelIndex;
new g_iGibsModelIndex;

new g_iBossHandler;

new Float:g_flStartHealth = NPC_Health;

public plugin_precache() {
    Nav_Precache();

    precache_model(g_szModel);
    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke_tiny.spr");
    g_iGibsModelIndex = precache_model("models/hwn/npc/headless_hatman_gibs.mdl");

    for (new i = 0; i < sizeof(g_szSndAttack); ++i) {
        precache_sound(g_szSndAttack[i]);
    }

    for (new i = 0; i < sizeof(g_szSndLaugh); ++i) {
        precache_sound(g_szSndLaugh[i]);
    }

    for (new i = 0; i < sizeof(g_szSndPain); ++i) {
        precache_sound(g_szSndPain[i]);
    }

    for (new i = 0; i < sizeof(g_szSndStep); ++i) {
        precache_sound(g_szSndStep[i]);
    }

    precache_sound(g_szSndHit);
    precache_sound(g_szSndSpawn);
    precache_sound(g_szSndDying);
    precache_sound(g_szSndDeath);

    CE_RegisterDerived(ENTITY_NAME, "hwn_npc_base");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");

    CE_RegisterMethod(ENTITY_NAME, Laugh, "@Entity_Laugh");
    CE_RegisterMethod(ENTITY_NAME, AIThink, "@Entity_AIThink");
    CE_RegisterMethod(ENTITY_NAME, PlayAction, "@Entity_PlayAction", CE_MP_Cell, CE_MP_Cell, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, TakeDamage, "@Entity_TakeDamage", CE_MP_Cell, CE_MP_Cell, CE_MP_Float, CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, Dying, "@Entity_Dying");

    g_iBossHandler = Hwn_Bosses_Register(ENTITY_NAME, "Horseless Headless Horsemann");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    gmsgScreenShake = get_user_msgid("ScreenShake");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver() {
    g_flStartHealth += NPC_HealthBonusPerPlayer;
}

public client_disconnected(pPlayer) {
    g_flStartHealth -= NPC_HealthBonusPerPlayer;
}

public Hwn_Bosses_Fw_BossTeleport(pEntity, iBoss) {
    if (iBoss != g_iBossHandler) return;

    CE_CallMethod(pEntity, ResetPath);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMember(this, CE_MEMBER_BLOODCOLOR, 212);
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -16.0, -48.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 16.0, 48.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMemberVec(this, m_vecHitOffset, NPC_TargetHitOffset);
    CE_SetMember(this, m_flAttackRange, NPC_AttackRange);
    CE_SetMember(this, m_flAttackDelay, NPC_AttackDelay);
    CE_SetMember(this, m_flFindRange, NPC_FindRange);
    CE_SetMember(this, m_flViewRange, NPC_ViewRange);
    CE_SetMember(this, m_flDamage, NPC_Damage);
    CE_SetMember(this, m_flAttackRate, 0.5);
    CE_SetMember(this, m_flDieDuration, 2.0);
}

@Entity_Spawned(this) {
    new Float:flGameTime = get_gametime();

    CE_SetMember(this, m_flNextLaugh, flGameTime);
    CE_SetMember(this, m_flNextFootStep, flGameTime);
    CE_SetMember(this, m_flNextLightEmit, flGameTime);
    CE_SetMember(this, m_flNextSmokeEmit, flGameTime);

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        flRenderColor[i] *= 0.2;
    }

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, flRenderColor);
    set_pev(this, pev_team, 666);
    set_pev(this, pev_health, g_flStartHealth);
    set_pev(this, pev_takedamage, DAMAGE_NO);
    set_pev(this, pev_view_ofs, Flaot:{0.0, 0.0, 32.0});
    set_pev(this, pev_maxspeed, NPC_Speed);

    CE_CallMethod(this, EmitVoice, g_szSndSpawn, 1.0);

    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    CE_CallMethod(this, PlayAction, Action_Spawn, false);

    set_pev(this, pev_nextthink, flGameTime + g_rgActions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Dying(this) {
    CE_CallMethod(this, EmitVoice, g_szSndDying, 1.0);
    CE_CallMethod(this, PlayAction, Action_Shake, true);
}

@Entity_Killed(this, pKiller) {
    if (pKiller) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

        UTIL_Message_ExplodeModel(vecOrigin, random_float(-512.0, 512.0), g_iGibsModelIndex, 5, 25);
        CE_CallMethod(this, EmitVoice, g_szSndDeath, 1.0);
    }
}

@Entity_Remove(this) {
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 10, 32);
}

@Entity_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    CE_CallBaseMethod(pInflictor, pAttacker, Float:flDamage, iDamageBits);

    if (random(100) < 50) {
        CE_CallMethod(this, EmitVoice, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }
}

@Entity_AIThink(this) {
    CE_CallBaseMethod();

    static Float:flGameTime; flGameTime = get_gametime();

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    static Float:vecVelocity[3]; pev(this, pev_velocity, vecVelocity);
    if (xs_vec_len(vecVelocity) > 50.0) {
        static Float:flNextLaugh; flNextLaugh = CE_GetMember(this, m_flNextLaugh);
        if (flNextLaugh <= flGameTime) {
            CE_CallMethod(this, Laugh);
            CE_SetMember(this, m_flNextLaugh, flGameTime + random_float(1.0, 2.0));
        }

        static Float:flNextFootStep; flNextFootStep = CE_GetMember(this, m_flNextFootStep);
        if (flNextFootStep <= flGameTime) {
            @Entity_EmitFootStep(this);
            @Entity_ScareAway(this);
            CE_SetMember(this, m_flNextFootStep, flGameTime + 0.25);
        }
    }

    static Float:flNextLightEmit; flNextLightEmit = CE_GetMember(this, m_flNextLightEmit);
    if (flNextLightEmit <= flGameTime) {
        @Entity_EmitLight(this);
        CE_SetMember(this, m_flNextLightEmit, flGameTime + 0.1);
    }

    static Float:flNextSmokeEmit; flNextSmokeEmit = CE_GetMember(this, m_flNextSmokeEmit);
    if (flNextSmokeEmit <= flGameTime) {
        @Entity_EmitSmoke(this);
        CE_SetMember(this, m_flNextSmokeEmit, flGameTime + 0.1);
    }

    static Action:iAction; iAction = @Entity_GetAction(this);
    CE_CallMethod(this, PlayAction, iAction, false);
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
            }

            if (CE_HasMember(this, m_vecInput)) {
                iAction = iAction == Action_Attack ? Action_RunAttack : Action_Run;
            }
        }
    }

    return iAction;
}

@Entity_Laugh(this) {
    CE_CallMethod(this, EmitVoice, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
}

@Entity_EmitFootStep(this) {
    emit_sound(this, CHAN_BODY, g_szSndStep[random(sizeof(g_szSndStep))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_EmitLight(this) {
    static Float:flRate; flRate = Hwn_GetNpcUpdateRate();
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static iLifeTime; iLifeTime = min(floatround(flRate * 10), 1);

    UTIL_Message_Dlight(vecOrigin, 4, {HWN_COLOR_PRIMARY}, iLifeTime, 0);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_ELIGHT);
    write_short(0);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]+42.0);
    write_coord(16);
    write_byte(64);
    write_byte(52);
    write_byte(4);
    write_byte(iLifeTime);
    write_coord(0);
    message_end();
}

@Entity_EmitSmoke(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += random_float(-16.0, 16.0);
    UTIL_Message_FireField(vecOrigin, 8, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);
}

@Entity_ScareAway(this) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_alive(pPlayer)) continue;

        static Float:vecUserOrigin[3]; pev(pPlayer, pev_origin, vecUserOrigin);

        if (get_distance_f(vecOrigin, vecUserOrigin) > 512.0) {
            continue;
        }

        message_begin(MSG_ONE, gmsgScreenShake, .player = pPlayer);
        write_short(UTIL_FixedUnsigned16(8.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<12));
        write_short(UTIL_FixedUnsigned16(1.0, 1<<8));
        message_end();
    }
}
