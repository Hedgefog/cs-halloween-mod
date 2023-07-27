#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Lightning Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"

#define TASKID_SUM_DAMAGE 1000
#define TASKID_SUM_KILL 2000
#define TASKID_SUM_LIGHTNING_EFFECT 3000

const Float:SpellballSpeed = 320.0;
const Float:SpellballLifeTime = 5.0;
const Float:SpellballMagnetism = 320.0;

const Float:EffectDamage = 30.0;
const Float:EffectDamageDelay = 0.5;
const Float:EffectLightningDelay = 0.1;
const Float:EffectRadius = 96.0;
const Float:EffectDamageRadiusMultiplier = 0.75;
const Float:EffectImpactRadiusMultiplier = 0.5;
new const EffectColor[3] = {32, 128, 192};

new const g_szSndCast[] = "hwn/spells/spell_lightning_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_lightning_impact.wav";
new const g_szSprSpellBall[] = "sprites/flare6.spr";

new g_rgpPlayerFocalPoint[MAX_PLAYERS + 1];

new g_iEffectModelIndex;
new g_hSpell;
new Float:g_flThinkDelay;

public plugin_precache() {
    g_iEffectModelIndex = precache_model("sprites/lgtning.spr");
    precache_model(g_szSprSpellBall);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register(
        "Lightning", 
        (
            Hwn_SpellFlag_Throwable
                | Hwn_SpellFlag_Damage
                | Hwn_SpellFlag_Radius
                | Hwn_SpellFlag_Rare
        ),
        "OnCast"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
    CE_RegisterHook(CEFunction_Remove, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballRemove");

    RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink_Post", .Post = 1);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded() {
    g_flThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(pPlayer) {
    new pEntity = UTIL_HwnSpawnPlayerSpellball(pPlayer, EffectColor, floatround(SpellballSpeed), g_szSprSpellBall, _, _, 10.0);
    if (!pEntity) {
        return PLUGIN_HANDLED;
    }

    new Float:vecVelocity[3];
    pev(pEntity, pev_velocity, vecVelocity);

    set_pev(pEntity, pev_vuser1, vecVelocity);
    set_pev(pEntity, pev_iuser1, g_hSpell);
    set_pev(pEntity, pev_groupinfo, 128);

    set_task(SpellballLifeTime, "Task_Kill", pEntity+TASKID_SUM_KILL);
    set_task(g_flThinkDelay, "Task_Think", pEntity, _, _, "b");
    set_task(EffectDamageDelay, "Task_Damage", pEntity+TASKID_SUM_DAMAGE, _, _, "b");
    set_task(EffectLightningDelay, "Task_LightningEffect", pEntity+TASKID_SUM_LIGHTNING_EFFECT, _, _, "b");

    emit_sound(pPlayer, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    dllfunc(DLLFunc_Think, pEntity);

    return PLUGIN_CONTINUE;
}

public OnSpellballRemove(pEntity) {
    remove_task(pEntity);
    remove_task(pEntity+TASKID_SUM_DAMAGE);
    remove_task(pEntity+TASKID_SUM_KILL);
    remove_task(pEntity+TASKID_SUM_LIGHTNING_EFFECT);
}

public OnSpellballKilled(pEntity) {
    new iSpell = pev(pEntity, pev_iuser1);
    if (iSpell != g_hSpell) {
        return;
    }

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (g_rgpPlayerFocalPoint[pPlayer] == pEntity) {
            g_rgpPlayerFocalPoint[pPlayer] = 0;
        }
    }

    Detonate(pEntity);
}

public HamHook_Player_PreThink_Post(pPlayer) {
    if (!g_rgpPlayerFocalPoint[pPlayer]) {
        return HAM_IGNORED;
    }

    if (!is_user_alive(pPlayer)) {
        g_rgpPlayerFocalPoint[pPlayer] = 0;
        return HAM_IGNORED;
    }

    if (!pev_valid(g_rgpPlayerFocalPoint[pPlayer])) {
        g_rgpPlayerFocalPoint[pPlayer] = 0;
        return HAM_IGNORED;
    }

    if (!Magnetize(g_rgpPlayerFocalPoint[pPlayer], pPlayer)) {
        g_rgpPlayerFocalPoint[pPlayer] = 0;
    }

    return HAM_HANDLED;
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:Magnetize(pEntity, pTarget) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTargetOrigin[3];
    pev(pTarget, pev_origin, vecTargetOrigin);

    new Float:flDistance = get_distance_f(vecOrigin, vecTargetOrigin);

    if (flDistance > EffectRadius) {
        return false;
    }

    if (flDistance > EffectRadius * EffectImpactRadiusMultiplier) {
        UTIL_PushFromOrigin(vecOrigin, pTarget, -SpellballMagnetism);
    } else {
        static Float:vecVelocity[3];
        pev(pEntity, pev_velocity, vecVelocity);
        set_pev(pTarget, pev_velocity, vecVelocity);
    }

    return true;
}

/*--------------------------------[ Methods ]--------------------------------*/

Detonate(pEntity) {
    RadiusDamage(pEntity, true);
    DetonateEffect(pEntity);
}

RadiusDamage(pEntity, bool:push = false) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pOwner = pev(pEntity, pev_owner);
    new iTeam = pOwner ? get_member(pOwner, m_iTeam) : -1;

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EffectRadius)) != 0) {
        if (pEntity == pTarget) {
            continue;
        }

        if (!pev_valid(pTarget)) {
            continue;
        }

        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        if (pTarget == pOwner) {
            continue;
        }

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        new Float:flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, EffectRadius * EffectDamageRadiusMultiplier, EffectDamage, false, pTarget);

        if (UTIL_IsTeammate(pTarget, iTeam)) {
            continue;
        }

        if (push) {
            if (IS_PLAYER(pTarget) || pev(pTarget, pev_flags) & FL_MONSTER) {
                UTIL_PushFromOrigin(vecOrigin, pTarget, SpellballMagnetism);
            }
        }

        ExecuteHamB(Ham_TakeDamage, pTarget, pEntity, pOwner, flDamage, DMG_SHOCK);
    }
}

DrawLightingBeam(pEntity) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    // generate random offset
    static Float:vecTarget[3];
    for (new i = 0; i < 3; ++i) {
        vecTarget[i] = random_float(-16.0, 16.0);
    }

    xs_vec_normalize(vecTarget, vecTarget);
    xs_vec_mul_scalar(vecTarget, EffectRadius, vecTarget);
    xs_vec_add(vecOrigin, vecTarget, vecTarget);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, vecTarget[0]);
    engfunc(EngFunc_WriteCoord, vecTarget[1]);
    engfunc(EngFunc_WriteCoord, vecTarget[2]);
    write_short(g_iEffectModelIndex);
    write_byte(0);
    write_byte(30);
    write_byte(5);
    write_byte(20);
    write_byte(192);
    write_byte(EffectColor[0]);
    write_byte(EffectColor[1]);
    write_byte(EffectColor[2]);
    write_byte(100);
    write_byte(100);
    message_end();
}

DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectModelIndex, 0, 3, 32, 255, EffectColor, 100, 0);
    emit_sound(pEntity, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Task ]--------------------------------*/

public Task_Think(pEntity) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pOwner = pev(pEntity, pev_owner);
    new iTeam = pOwner ? get_member(pOwner, m_iTeam) : -1;

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EffectRadius)) != 0)
    {
        if (pEntity == pTarget) {
            continue;
        }

        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        if (pTarget == pOwner) {
            continue;
        }

        if (!IS_PLAYER(pTarget)) {
            continue;
        }

        if (UTIL_IsTeammate(pTarget, iTeam)) {
            continue;
        }

        if (g_rgpPlayerFocalPoint[pTarget]) {
            continue;
        }

        g_rgpPlayerFocalPoint[pTarget] = pEntity;
    }

    // update velocity
    static Float:vecVelocity[3];
    pev(pEntity, pev_vuser1, vecVelocity);
    set_pev(pEntity, pev_velocity, vecVelocity);
}

public Task_Kill(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_KILL;
    CE_Kill(pEntity);
}

public Task_Damage(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_DAMAGE;

    RadiusDamage(pEntity);
    emit_sound(pEntity, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public Task_LightningEffect(iTaskId) {
    new pEntity = iTaskId - TASKID_SUM_LIGHTNING_EFFECT;

    for (new i = 0; i < 4; ++i) {
        DrawLightingBeam(pEntity);
    }
}
