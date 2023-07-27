#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN "[Custom Entity] Hwn NPC Skeleton"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_skeleton"
#define ENTITY_NAME_SMALL "hwn_npc_skeleton_small"

#define SKELETON_EGG_ENTITY_NAME "hwn_skeleton_egg"
#define SKELETON_EGG_COUNT 2

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
    Action_Idle = 0,
    Action_Run,
    Action_Attack,
    Action_RunAttack,
    Action_Spawn
};

const Float:NPC_Health = 100.0;
const Float:NPC_Speed = 230.0;
const Float:NPC_Damage = 24.0;
const Float:NPC_HitRange = 48.0;
const Float:NPC_HitDelay = 0.35;
const Float:NPC_LifeTime = 30.0;
const Float:NPC_RespawnTime = 15.0;

const Float:NPC_Small_Health = 50.0;
const Float:NPC_Small_Speed = 250.0;
const Float:NPC_Small_Damage = 12.0;
const Float:NPC_Small_HitRange = 48.0;
const Float:NPC_Small_HitDelay = 0.35;

new const g_szSndIdleList[][] = {
    "hwn/npc/skeleton/skelly_medium_01.wav",
    "hwn/npc/skeleton/skelly_medium_02.wav",
    "hwn/npc/skeleton/skelly_medium_03.wav",
    "hwn/npc/skeleton/skelly_medium_04.wav",
    "hwn/npc/skeleton/skelly_medium_05.wav"
};

new const g_szSndSmallIdleList[][] = {
    "hwn/npc/skeleton/skelly_small_01.wav",
    "hwn/npc/skeleton/skelly_small_02.wav",
    "hwn/npc/skeleton/skelly_small_03.wav",
    "hwn/npc/skeleton/skelly_small_04.wav",
    "hwn/npc/skeleton/skelly_small_05.wav"
};

new const g_szSndBreak[]    = "hwn/npc/skeleton/skeleton_break.wav";

new const g_actions[Action][NPC_Action] = {
    {    Sequence_Idle,         Sequence_Idle,          0.0    },
    {    Sequence_Run,          Sequence_Run,           0.0    },
    {    Sequence_Attack,       Sequence_Attack,        1.0    },
    {    Sequence_RunAttack,    Sequence_RunAttack,     1.0    },
    {    Sequence_Spawn1,       Sequence_Spawn7,        2.0    }
};

new g_mdlGibs;

new g_iBloodModelIndex;
new g_iBloodSprayModelIndex;

new g_iCeHandler;
new g_ceHandlerSmall;

public plugin_precache() {
    g_mdlGibs = precache_model("models/bonegibs.mdl");
    g_iBloodModelIndex = precache_model("sprites/blood.spr");
    g_iBloodSprayModelIndex = precache_model("sprites/bloodspray.spr");

    precache_sound(g_szSndBreak);

    for (new i = 0; i < sizeof(g_szSndIdleList); ++i) {
        precache_sound(g_szSndIdleList[i]);
    }

    for (new i = 0; i < sizeof(g_szSndSmallIdleList); ++i) {
        precache_sound(g_szSndSmallIdleList[i]);
    }

    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/skeleton_v2.mdl"),
        .vMins = Float:{-12.0, -12.0, -32.0},
        .vMaxs = Float:{12.0, 12.0, 32.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    g_ceHandlerSmall = CE_Register(
        ENTITY_NAME_SMALL,
        .modelIndex = precache_model("models/hwn/npc/skeleton_small_v3.mdl"),
        .vMins = Float:{-8.0, -8.0, -16.0},
        .vMaxs = Float:{8.0, 8.0, 16.0},
        .fLifeTime = NPC_LifeTime,
        .fRespawnTime = NPC_RespawnTime,
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME_SMALL, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME_SMALL, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME_SMALL, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME_SMALL, "@Entity_Think");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
}

/*--------------------------------[ Hooks ]--------------------------------*/

@Entity_Spawn(this) {
    new Float:flGameTime = get_gametime();

    NPC_Create(this);

    new bool:bSmall = CE_GetHandlerByEntity(this) == CE_GetHandler(ENTITY_NAME_SMALL);
    CE_SetMember(this, "bSmall", bSmall);
    CE_SetMember(this, "flNextUpdate", flGameTime);
    CE_SetMember(this, "flNextVoice", flGameTime);

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_health, bSmall ? NPC_Small_Health : NPC_Health);
    set_pev(this, pev_groupinfo, 128);
    set_pev(this, pev_fuser1, 0.0);

    engfunc(EngFunc_DropToFloor, this);

    @Entity_UpdateColor(this);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, bSmall ? 8 : 16, {HWN_COLOR_SECONDARY}, 20, 8);

    NPC_PlayAction(this, g_actions[Action_Spawn]);
    
    set_pev(this, pev_nextthink, flGameTime + g_actions[Action_Spawn][NPC_Action_Time]);
}

@Entity_Killed(this, pKiller) {
    new bool:bSmall = CE_GetMember(this, "bSmall");

    @Entity_DisappearEffect(this);

    if (!bSmall) {
        @Entity_SpawnEggs(this);
    }
}

@Entity_Remove(this) {
    NPC_Destroy(this);
}

@Entity_Think(this) {
    new Float:flGameTime = get_gametime();

    if (pev(this, pev_deadflag) == DEAD_NO) {
        new Float:flNextUpdate = CE_GetMember(this, "flNextUpdate");
        new bool:bShouldUpdate = flNextUpdate <= flGameTime;

        new pEnemy = NPC_GetEnemy(this);
        if (pEnemy) {
            @Entity_Attack(this, pEnemy, bShouldUpdate);
        }

        if (bShouldUpdate) {
            if (!pEnemy) {
                NPC_FindEnemy(this, 1024.0);
            } else {
                new Float:flNextVoice = CE_GetMember(this, "flNextVoice");
                if (flNextVoice <= flGameTime) {
                    new bool:bSmall = CE_GetMember(this, "bSmall");

                    if (bSmall) {
                        NPC_EmitVoice(this, g_szSndSmallIdleList[random(sizeof(g_szSndSmallIdleList))]);
                    } else {
                        NPC_EmitVoice(this, g_szSndIdleList[random(sizeof(g_szSndIdleList))]);
                    }

                    CE_SetMember(this, "flNextVoice", flGameTime + random_float(1.0, 2.0));
                }
            }

            new Action:iAction = @Entity_GetAction(this);
            NPC_PlayAction(this, g_actions[iAction]);

            @Entity_UpdateColor(this);

            CE_SetMember(this, "flNextUpdate", flGameTime + Hwn_GetNpcUpdateRate());
        }
    }

    set_pev(this, pev_nextthink, flGameTime + Hwn_GetUpdateRate());
}

@Entity_UpdateColor(this) {
    new iTeam = pev(this, pev_team);

    switch (iTeam) {
        case 0: set_pev(this, pev_rendercolor, {HWN_COLOR_SECONDARY_F});
        case 1: set_pev(this, pev_rendercolor, {HWN_COLOR_RED_F});
        case 2: set_pev(this, pev_rendercolor, {HWN_COLOR_BLUE_F});
    }
}

bool:@Entity_Attack(this, pTarget, bool:bCheckTarget) {
    new Float:flGameTime = get_gametime();

    new bool:bSmall = CE_GetMember(this, "bSmall");

    new Float:flHitRange = bSmall ? NPC_Small_HitRange : NPC_HitRange;
    new Float:flHitDelay = bSmall ? NPC_Small_HitDelay : NPC_HitDelay;
    new Float:flSpeed = bSmall ? NPC_Small_Speed : NPC_Speed;

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    if (bCheckTarget) {
        if (!NPC_GetTarget(this, flSpeed, vecTarget)) {
            NPC_SetEnemy(this, 0);
            NPC_StopMovement(this);
            set_pev(this, pev_vuser1, vecOrigin);
            return false;
        }

        set_pev(this, pev_vuser1, vecTarget);
    } else {
        pev(this, pev_vuser1, vecTarget);
    }

    new bool:bCanHit = NPC_CanHit(this, pTarget, flHitRange);

    if (bCheckTarget && bCanHit) {
        new Float:flNextHit = CE_GetMember(this, "flNextHit");
        if (!flNextHit) {
            CE_SetMember(this, "flNextHit", flGameTime + flHitDelay);
        } else if (flNextHit <= flGameTime) {
            @Entity_Hit(this);
            CE_SetMember(this, "flNextHit", 0.0);
        }
    }

    static Float:vecTargetVelocity[3];
    pev(pTarget, pev_velocity, vecTargetVelocity);

    new bool:bShouldRun = !bCanHit || xs_vec_len(vecTargetVelocity) > flHitRange;
    if (bShouldRun) {
        NPC_MoveToTarget(this, vecTarget, NPC_Speed);
    } else {
        NPC_StopMovement(this);
    }

    return true;
}

Action:@Entity_GetAction(this) {
    new Action:iAction = Action_Idle;

    static Float:vecTargetVelocity[3];
    pev(this, pev_velocity, vecTargetVelocity);

    new Float:flNextHit = CE_GetMember(this, "flNextHit");
    if (flNextHit) {
        iAction = Action_Attack;
    }

    if (xs_vec_len(vecTargetVelocity) > 10.0) {
        iAction = iAction == Action_Attack ? Action_RunAttack : Action_Run;
    }

    return iAction;
}

@Entity_Hit(this) {
    new bool:bSmall = CE_GetMember(this, "bSmall");

    new Float:flHitRange = bSmall ? NPC_Small_HitRange : NPC_HitRange;
    new Float:flHitDelay = bSmall ? NPC_Small_HitDelay : NPC_HitDelay;
    new Float:flDamage = bSmall ? NPC_Small_Damage : NPC_Damage;

    NPC_Hit(this, flDamage, flHitRange, flHitDelay);
}

@Entity_DisappearEffect(this) {
    new bool:bSmall = CE_GetMember(this, "bSmall");

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new Float:vecVelocity[3];
    UTIL_RandomVector(-48.0, 48.0, vecVelocity);

    UTIL_Message_Dlight(vecOrigin, bSmall ? 8 : 16, {HWN_COLOR_SECONDARY}, 10, 32);
    UTIL_Message_BreakModel(vecOrigin, Float:{16.0, 16.0, 16.0}, vecVelocity, 10, g_mdlGibs, 5, 25, 0);

    emit_sound(this, CHAN_BODY, g_szSndBreak, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_SpawnEggs(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    for (new i = 0; i < SKELETON_EGG_COUNT; ++i) {
        new pEgg = CE_Create(SKELETON_EGG_ENTITY_NAME, vecOrigin);
        if (!pEgg) {
            continue;
        }

        set_pev(pEgg, pev_team, pev(this, pev_team));
        set_pev(pEgg, pev_owner, pev(this, pev_owner));
        dllfunc(DLLFunc_Spawn, pEgg);

        new Float:vecVelocity[3];
        xs_vec_set(vecVelocity, random_float(-96.0, 96.0), random_float(-96.0, 96.0), 128.0);
        set_pev(pEgg, pev_velocity, vecVelocity);
    }
}

public HamHook_Base_TraceAttack(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity) && g_ceHandlerSmall != CE_GetHandlerByEntity(pEntity)) {
        return HAM_IGNORED;
    }

    new iTeam = pev(pEntity, pev_team);
    if (IS_PLAYER(pAttacker) && get_member(pAttacker, m_iTeam) == iTeam) {
        return HAM_SUPERCEDE;
    }

    return HAM_HANDLED;
}

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity) && g_ceHandlerSmall != CE_GetHandlerByEntity(pEntity)) {
        return HAM_IGNORED;
    }

    new iTeam = pev(pEntity, pev_team);
    if (IS_PLAYER(pAttacker) && get_member(pAttacker, m_iTeam) == iTeam) {
        return HAM_HANDLED;
    }

    static Float:vecEnd[3];
    get_tr2(pTrace, TR_vecEndPos, vecEnd);
    UTIL_Message_BloodSprite(vecEnd, g_iBloodSprayModelIndex, g_iBloodModelIndex, 242, floatround(flDamage/4));

    return HAM_HANDLED;
}

public HamHook_Player_Killed(pPlayer, pKiller) {
    new iCeHandler = CE_GetHandlerByEntity(pKiller);
    if (iCeHandler == g_iCeHandler || iCeHandler == g_ceHandlerSmall) {
        new pOwner = pev(pKiller, pev_owner);
        if (pOwner) {
            SetHamParamEntity(2, pOwner);
        }
    }

    return HAM_HANDLED;
}
