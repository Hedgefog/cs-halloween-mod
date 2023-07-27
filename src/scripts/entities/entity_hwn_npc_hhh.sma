#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <astar>
#include <api_custom_entities>

#include <hwn>
#include <hwn_npc_stocks>

#define PLUGIN    "[Custom Entity] Hwn NPC HHH"
#define AUTHOR    "Hedgehog Fog"

#define ENTITY_NAME "hwn_npc_hhh"

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

new const g_actions[Action][NPC_Action] = {
    {    Sequence_Idle,            Sequence_Idle,        0.0    },
    {    Sequence_Run,            Sequence_Run,        0.0    },
    {    Sequence_Attack,        Sequence_Attack,    1.0    },
    {    Sequence_RunAttack,        Sequence_RunAttack,    1.0    },
    {    Sequence_Shake,            Sequence_Shake,        2.0    },
    {    Sequence_Spawn,            Sequence_Spawn,        6.0    }
};

new Float:NPC_Health                = 4000.0;
new Float:NPC_HealthBonusPerPlayer  = 300.0;
const Float:NPC_Speed               = 300.0;
const Float:NPC_Damage              = 160.0;
const Float:NPC_HitRange            = 96.0;
const Float:NPC_HitDelay            = 0.75;
const Float:NPC_ViewRange           = 2048.0;

new gmsgScreenShake;

new g_iBloodModelIndex;
new g_iBloodSprayModelIndex;
new g_iSmokeModelIndex;

new g_mdlGibs;

new g_pAstar[10];

new g_pCvarUseAstar;

new g_iCeHandler;
new g_iBoss;

public plugin_precache() {
    g_iBloodModelIndex = precache_model("sprites/blood.spr");
    g_iBloodSprayModelIndex = precache_model("sprites/bloodspray.spr");
    g_mdlGibs = precache_model("models/hwn/npc/headless_hatman_gibs.mdl");
    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke_tiny.spr");

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

    g_iCeHandler = CE_Register(
        ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/npc/headless_hatman.mdl"),
        .vMins = Float:{-16.0, -16.0, -48.0},
        .vMaxs = Float:{16.0, 16.0, 48.0},
        .preset = CEPreset_NPC
    );

    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "@Entity_Kill");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    g_iBoss = Hwn_Bosses_Register(ENTITY_NAME, "Horseless Headless Horsemann");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);

    g_pCvarUseAstar = register_cvar("hwn_npc_hhh_use_astar", "1");

    gmsgScreenShake = get_user_msgid("ScreenShake");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_putinserver() {
    NPC_Health += NPC_HealthBonusPerPlayer;
}

public client_disconnected(pPlayer) {
    NPC_Health -= NPC_HealthBonusPerPlayer;
}

public Hwn_Bosses_Fw_BossTeleport(pEntity, iBoss) {
    if (iBoss != g_iBoss) {
        return;
    }

    @Entity_ResetPath(pEntity);
}

/*--------------------------------[ Methods ]--------------------------------*/

public @Entity_Init(this) {
    CE_SetMember(this, "iAstarIndex", -1);
    CE_SetMember(this, "irgPath", Invalid_Array);

    NPC_Create(this);
}

public @Entity_Spawn(this) {
    new Float:flGameTime = get_gametime();

    @Entity_ResetPath(this);

    CE_SetMember(this, "flNextHit", 0.0);
    CE_SetMember(this, "flNextSmokeEmit", flGameTime);
    CE_SetMember(this, "flNextLaugh", flGameTime);
    CE_SetMember(this, "flNextPathSearch", flGameTime);
    CE_SetMemberVec(this, "vecTarget", Float:{0.0, 0.0, 0.0});

    new Float:flRenderColor[3] = {HWN_COLOR_PRIMARY_F};
    for (new i = 0; i < 3; ++i) {
        flRenderColor[i] *= 0.2;
    }

    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 4.0);
    set_pev(this, pev_rendercolor, flRenderColor);
    set_pev(this, pev_fuser1, 0.0);
    set_pev(this, pev_team, 666);
    set_pev(this, pev_health, NPC_Health);
    set_pev(this, pev_takedamage, DAMAGE_NO);

    engfunc(EngFunc_DropToFloor, this);

    NPC_EmitVoice(this, g_szSndSpawn);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 60, 4);

    NPC_PlayAction(this, g_actions[Action_Spawn]);

    set_pev(this, pev_nextthink, flGameTime + g_actions[Action_Spawn][NPC_Action_Time]);
}

public @Entity_Remove(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 32, {HWN_COLOR_PRIMARY}, 10, 32);

    @Entity_ResetPath(this);
    NPC_Destroy(this);
}

public @Entity_Kill(this) {
    new iDeadFlag = pev(this, pev_deadflag);

    if (iDeadFlag == DEAD_NO) {
        NPC_EmitVoice(this, g_szSndDying, .supercede = true);
        NPC_PlayAction(this, g_actions[Action_Shake], .supercede = true);

        NPC_StopMovement(this);
        set_pev(this, pev_takedamage, DAMAGE_NO);
        set_pev(this, pev_deadflag, DEAD_DYING);

        set_pev(this, pev_nextthink, get_gametime() + 2.0);
    } else if (iDeadFlag == DEAD_DEAD) {
        return PLUGIN_CONTINUE;
    }

    return PLUGIN_HANDLED;
}

@Entity_Think(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    if (pev(this, pev_deadflag) == DEAD_DYING) {
        UTIL_Message_ExplodeModel(vecOrigin, random_float(-512.0, 512.0), g_mdlGibs, 5, 25);
        NPC_EmitVoice(this, g_szSndDeath, .supercede = true);
        set_pev(this, pev_deadflag, DEAD_DEAD);
        CE_Kill(this);

        return HAM_HANDLED;
    }

    new Float:flGameTime = get_gametime();
    new Float:flRate = Hwn_GetUpdateRate();

    if (pev(this, pev_takedamage) == DAMAGE_NO) {
        set_pev(this, pev_takedamage, DAMAGE_AIM);
    }

    new Float:flNextLaugh = CE_GetMember(this, "flNextLaugh");
    if (flNextLaugh <= flGameTime) {
        NPC_EmitVoice(this, g_szSndLaugh[random(sizeof(g_szSndLaugh))], 2.0);
        CE_SetMember(this, "flNextLaugh", flGameTime + random_float(1.0, 2.0));
    }

    new pEnemy = NPC_GetEnemy(this);
    // new Action:iAction = Action_Idle;

    static Float:flLastUpdate;
    pev(this, pev_fuser1, flLastUpdate);
    new bool:shouldUpdate = get_gametime() - flLastUpdate >= flRate;

    if (pEnemy) {
        @Entity_Attack(this, pEnemy, shouldUpdate);
        pEnemy = NPC_GetEnemy(this);
    }

    if (pEnemy && shouldUpdate) {
        @Entity_ResetPath(this);
    }

    if (shouldUpdate) {
        if (!pEnemy) {
            NPC_FindEnemy(this, 96.0, .allowMonsters = true);
            pEnemy = NPC_GetEnemy(this);
        }

        if (!pEnemy) {
            NPC_FindEnemy(this, NPC_ViewRange, .allowMonsters = false);
            pEnemy = NPC_GetEnemy(this);
        }

        if (!pEnemy && get_pcvar_num(g_pCvarUseAstar) > 0) {
            @Entity_AStarAttack(this);
        }

        @Entity_EmitLight(this);

        new Action:iAction = @Entity_GetAction(this);
        NPC_PlayAction(this, g_actions[iAction]);

        set_pev(this, pev_fuser1, get_gametime());
    }

    @Entity_EmitSmoke(this);
    set_pev(this, pev_nextthink, flGameTime+ 0.01);

    return HAM_HANDLED;
}

@Entity_EmitLight(this) {
    new Float:flRate = Hwn_GetUpdateRate();

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new iLifeTime = min(floatround(flRate * 10), 1);

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


bool:@Entity_Attack(this, pTarget, bool:bCheckTarget) {
    new Float:flGameTime = get_gametime();

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static Float:vecTarget[3];

    if (bCheckTarget) {
        if (!NPC_GetTarget(this, NPC_Speed, vecTarget)) {
            NPC_SetEnemy(this, 0);
            NPC_StopMovement(this);
            set_pev(this, pev_vuser1, vecOrigin);
            return false;
        }

        set_pev(this, pev_vuser1, vecTarget);
    } else {
        pev(this, pev_vuser1, vecTarget);
    }

    new bool:bCanHit = NPC_CanHit(this, pTarget, NPC_HitRange);
    if (bCheckTarget && bCanHit) {
        new Float:flNextHit = CE_GetMember(this, "flNextHit");
        if (!flNextHit) {
            NPC_EmitVoice(this, g_szSndAttack[random(sizeof(g_szSndAttack))], 0.5);     
            CE_SetMember(this, "flNextHit", flGameTime + NPC_HitDelay);
        } else if (flNextHit <= flGameTime) {
            @Entity_Hit(this);
            CE_SetMember(this, "flNextHit", 0.0);
        }
    }

    static Float:vecTargetVelocity[3];
    pev(pTarget, pev_velocity, vecTargetVelocity);

    new bool:bShouldRun = !bCanHit || xs_vec_len(vecTargetVelocity) > NPC_HitRange;
    if (bShouldRun) {
        @Entity_ScareAway(this);
        NPC_EmitFootStep(this, g_szSndStep[random(sizeof(g_szSndStep))]);
        NPC_MoveToTarget(this, vecTarget, NPC_Speed);
    } else {
        NPC_StopMovement(this);
    }

    return true;
}

@Entity_Hit(this) {
    if (NPC_Hit(this, NPC_Damage, NPC_HitRange, NPC_HitDelay, Float:{0.0, 0.0, 16.0})) {
        emit_sound(this, CHAN_WEAPON, g_szSndHit, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    }
}

Action:@Entity_GetAction(this) {
    new Action:iAction = Action_Idle;

    new iDeadFlag = pev(this, pev_deadflag);

    switch (iDeadFlag) {
        case DEAD_NO: {
            static Float:vecTargetVelocity[3];
            pev(this, pev_velocity, vecTargetVelocity);

            new Float:flNextHit = CE_GetMember(this, "flNextHit");
            if (flNextHit) {
                iAction = Action_Attack;
            }

            if (xs_vec_len(vecTargetVelocity) > 10.0) {
                iAction = iAction == Action_Attack ? Action_RunAttack : Action_Run;
            }
        }
        case DEAD_DYING: {
            iAction = Action_Shake;
        }
    }

    return iAction;
}

@Entity_FindPath(this) {
    new pEnemy = pev(this, pev_enemy);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    pev(pEnemy, pev_origin, vecTarget);

    static Float:vecMins[3];
    pev(this, pev_mins, vecMins);

    new iAStar = AStarThreaded(vecOrigin, vecTarget, "AStarThreadHandler", 30, DONT_IGNORE_MONSTERS, this, floatround(-vecMins[2]), 50);
    CE_SetMember(this, "iAstarIndex", iAStar);

    if (iAStar != -1) {
        g_pAstar[iAStar] = this;
    }
}

bool:@Entity_AStarAttack(this) {
    new Float:flGameTime = get_gametime();

    new iAStar = CE_GetMember(this, "iAstarIndex");
    new Array:irgPath = CE_GetMember(this, "irgPath");
    new Float:flNextSearch = CE_GetMember(this, "flNextPathSearch");

    if (iAStar == -1) {
        new pEnemy = NPC_GetEnemy(this);
        if (pEnemy || NPC_FindEnemy(this, NPC_ViewRange, .reachableOnly = false, .visibleOnly = false, .allowMonsters = false)) {
            @Entity_FindPath(this);
            CE_SetMember(this, "flNextPathSearch", flGameTime + 10.0);
        }

        // NPC_PlayAction(this, g_actions[Action_Idle]);
    } else if (irgPath != Invalid_Array) {
        @Entity_ProcessPath(this, irgPath);
        NPC_EmitFootStep(this, g_szSndStep[random(sizeof(g_szSndStep))]);
        // iAction = Action_Run;
    } else {
        if (flGameTime > flNextSearch) {
            @Entity_ResetPath(this);
        }
    }
}

@Entity_ProcessPath(this, Array:irgPath) {
    new Float:flArrivalTime = CE_GetMember(this, "flArrivalTime");

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    CE_GetMemberVec(this, "vecTarget", vecTarget);

    if (ArraySize(irgPath) > 0) {
        if (get_gametime() >= flArrivalTime) {
            static curStep[3];
            ArrayGetArray(irgPath, 0, curStep);
            ArrayDeleteItem(irgPath, 0);

            for (new i = 0; i < 3; ++i) {
                vecTarget[i] = float(curStep[i]);
            }

            if (NPC_IsReachable(this, vecTarget)) {
                new Float:flDistance = get_distance_f(vecOrigin, vecTarget);
                CE_SetMemberVec(this, "vecTarget", vecTarget);
                CE_SetMember(this, "flArrivalTime", get_gametime() + (flDistance / NPC_Speed));
            } else {
                @Entity_ResetPath(this);
            }
        }

        NPC_PlayAction(this, g_actions[Action_Run]);
        NPC_MoveToTarget(this, vecTarget, NPC_Speed);
    } else {
        vecOrigin[2] = vecTarget[2];

        if (get_distance_f(vecOrigin, vecTarget) <= 64.0 && get_gametime() >= flArrivalTime) {
            @Entity_ResetPath(this);
            NPC_PlayAction(this, g_actions[Action_Idle]);
        }
    }
}

@Entity_ResetPath(this) {
    new Array:irgPath = CE_GetMember(this, "irgPath");
    if (irgPath != Invalid_Array) {
        ArrayDestroy(irgPath);
    }

    new iAStar = CE_GetMember(this, "iAstarIndex");
    AStarAbort(iAStar);

    CE_SetMember(this, "iAstarIndex", -1);
    CE_SetMember(this, "irgPath", Invalid_Array);
}

@Entity_EmitSmoke(this) {
    new Float:flNextSmokeEmit = CE_GetMember(this, "flNextSmokeEmit");
    if (get_gametime() < flNextSmokeEmit) {
        return;
    }

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += random_float(-16.0, 16.0);
    UTIL_Message_FireField(vecOrigin, 8, g_iSmokeModelIndex, 2, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);

    CE_SetMember(this, "flNextSmokeEmit", get_gametime() + 0.1);
}

@Entity_ScareAway(pEntity) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_alive(pPlayer)) {
            continue;
        }

        static Float:vecUserOrigin[3];
        pev(pPlayer, pev_origin, vecUserOrigin);

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

@Entity_TakeDamage(this, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (IS_PLAYER(pAttacker) && NPC_IsValidEnemy(pAttacker)) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);

        static Float:vecTarget[3];
        pev(pAttacker, pev_origin, vecTarget);

        if (get_distance_f(vecOrigin, vecTarget) <= NPC_HitRange && NPC_IsVisible(this, vecTarget)) {
            if (get_gametime() - NPC_GetEnemyTime(this) > 6.0) {
                NPC_SetEnemy(this, pAttacker);
            }
        }
    }

    if (random(100) < 10) {
        NPC_EmitVoice(this, g_szSndPain[random(sizeof(g_szSndPain))], 0.5);
    }
}

@Entity_TraceAttack(this, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    static Float:vecEnd[3];
    get_tr2(pTrace, TR_vecEndPos, vecEnd);

    UTIL_Message_BloodSprite(vecEnd, g_iBloodSprayModelIndex, g_iBloodModelIndex, 212, floatround(flDamage/4));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler == CE_GetHandlerByEntity(pEntity)) {
        @Entity_TraceAttack(pEntity, pAttacker, flDamage, vecDirection, pTrace, iDamageBits);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (g_iCeHandler == CE_GetHandlerByEntity(pEntity)) {
        @Entity_TakeDamage(pEntity,  pInflictor, pAttacker, flDamage, iDamageBits);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

/*--------------------------------[ Callbacks ]--------------------------------*/

public AStarThreadHandler(iAStar, Array:irgPath, Float:Distance, NodesAdded, NodesValidated, NodesCleared) {
    if (irgPath == Invalid_Array) {
        return;
    }

    new pEntity = g_pAstar[iAStar];

    if (!pev_valid(pEntity)) {
        return;
    }

    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    CE_SetMember(pEntity, "irgPath", irgPath);
}
