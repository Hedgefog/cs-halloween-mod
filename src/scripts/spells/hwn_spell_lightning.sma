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

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

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

new g_playerFocalPointEnt[MAX_PLAYERS + 1];

new g_sprEffect;
new g_hSpell;
new Float:g_fThinkDelay;

public plugin_precache()
{
    g_sprEffect = precache_model("sprites/lgtning.spr");
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

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
    CE_RegisterHook(CEFunction_Remove, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballRemove");

    RegisterHam(Ham_Player_PreThink, "player", "OnPlayerPreThink", .Post = 1);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded()
{
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, EffectColor, floatround(SpellballSpeed), g_szSprSpellBall, _, _, 10.0);
    if (!ent) {
        return PLUGIN_HANDLED;
    }

    new Float:vVelocity[3];
    pev(ent, pev_velocity, vVelocity);

    set_pev(ent, pev_vuser1, vVelocity);
    set_pev(ent, pev_iuser1, g_hSpell);
    set_pev(ent, pev_groupinfo, 128);

    set_task(SpellballLifeTime, "TaskKill", ent+TASKID_SUM_KILL);
    set_task(g_fThinkDelay, "TaskThink", ent, _, _, "b");
    set_task(EffectDamageDelay, "TaskDamage", ent+TASKID_SUM_DAMAGE, _, _, "b");
    set_task(EffectLightningDelay, "TaskLightningEffect", ent+TASKID_SUM_LIGHTNING_EFFECT, _, _, "b");

    emit_sound(id, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    dllfunc(DLLFunc_Think, ent);

    return PLUGIN_CONTINUE;
}

public OnSpellballRemove(ent)
{
    remove_task(ent);
    remove_task(ent+TASKID_SUM_DAMAGE);
    remove_task(ent+TASKID_SUM_KILL);
    remove_task(ent+TASKID_SUM_LIGHTNING_EFFECT);
}

public OnSpellballKilled(ent)
{
    new spellIdx = pev(ent, pev_iuser1);
    if (spellIdx != g_hSpell) {
        return;
    }

    for (new id = 1; id <= MAX_PLAYERS; ++id) {
        if (g_playerFocalPointEnt[id] == ent) {
            g_playerFocalPointEnt[id] = 0;
        }
    }

    Detonate(ent);
}

public OnPlayerPreThink(id)
{
    if (!g_playerFocalPointEnt[id]) {
        return HAM_IGNORED;
    }

    if (!is_user_alive(id)) {
        g_playerFocalPointEnt[id] = 0;
        return HAM_IGNORED;
    }

    if (!pev_valid(g_playerFocalPointEnt[id])) {
        g_playerFocalPointEnt[id] = 0;
        return HAM_IGNORED;
    }

    if (!Magnetize(g_playerFocalPointEnt[id], id)) {
        g_playerFocalPointEnt[id] = 0;
    }

    return HAM_HANDLED;
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:Magnetize(ent, target)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vTargetOrigin[3];
    pev(target, pev_origin, vTargetOrigin);

    new Float:fDistance = get_distance_f(vOrigin, vTargetOrigin);

    if (fDistance > EffectRadius) {
        return false;
    }

    if (fDistance > EffectRadius * EffectImpactRadiusMultiplier) {
        UTIL_PushFromOrigin(vOrigin, target, -SpellballMagnetism);
    } else {
        static Float:vVelocity[3];
        pev(ent, pev_velocity, vVelocity);
        set_pev(target, pev_velocity, vVelocity);
    }

    return true;
}

/*--------------------------------[ Methods ]--------------------------------*/

Detonate(ent)
{
    RadiusDamage(ent, true);
    DetonateEffect(ent);
}

RadiusDamage(ent, bool:push = false)
{
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new owner = pev(ent, pev_owner);
    new team = owner ? UTIL_GetPlayerTeam(owner) : -1;

    new target;
    while ((target = UTIL_FindEntityNearby(target, vOrigin, EffectRadius)) != 0) {
        if (ent == target) {
            continue;
        }

        if (!pev_valid(target)) {
            continue;
        }

        if (pev(target, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        if (target == owner) {
            continue;
        }

        static Float:vTargetOrigin[3];
        pev(target, pev_origin, vTargetOrigin);

        new Float:fDamage = UTIL_CalculateRadiusDamage(vOrigin, vTargetOrigin, EffectRadius * EffectDamageRadiusMultiplier, EffectDamage, false, target);

        if (UTIL_IsTeammate(target, team)) {
            continue;
        }

        if (push) {
            if (UTIL_IsPlayer(target) || pev(target, pev_flags) & FL_MONSTER) {
                UTIL_PushFromOrigin(vOrigin, target, SpellballMagnetism);
            }
        }

        ExecuteHamB(Ham_TakeDamage, target, ent, owner, fDamage, DMG_SHOCK);
    }
}

DrawLightingBeam(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    // generate random offset
    static Float:vTarget[3];
    for (new i = 0; i < 3; ++i) {
        vTarget[i] = random_float(-16.0, 16.0);
    }

    xs_vec_normalize(vTarget, vTarget);
    xs_vec_mul_scalar(vTarget, EffectRadius, vTarget);
    xs_vec_add(vOrigin, vTarget, vTarget);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, vTarget[0]);
    engfunc(EngFunc_WriteCoord, vTarget[1]);
    engfunc(EngFunc_WriteCoord, vTarget[2]);
    write_short(g_sprEffect);
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

DetonateEffect(ent)
{
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_BeamCylinder(vOrigin, EffectRadius * 3, g_sprEffect, 0, 3, 32, 255, EffectColor, 100, 0);
    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Task ]--------------------------------*/


public TaskThink(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new owner = pev(ent, pev_owner);
    new team = owner ? UTIL_GetPlayerTeam(owner) : -1;

    new target;
    while ((target = UTIL_FindEntityNearby(target, vOrigin, EffectRadius)) != 0)
    {
        if (ent == target) {
            continue;
        }

        if (pev(target, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        if (target == owner) {
            continue;
        }

        if (!UTIL_IsPlayer(target)) {
            continue;
        }

        if (UTIL_IsTeammate(target, team)) {
            continue;
        }

        if (g_playerFocalPointEnt[target]) {
            continue;
        }

        g_playerFocalPointEnt[target] = ent;
    }

    // update velocity
    static Float:vVelocity[3];
    pev(ent, pev_vuser1, vVelocity);
    set_pev(ent, pev_velocity, vVelocity);
}

public TaskKill(taskID)
{
    new ent = taskID - TASKID_SUM_KILL;
    CE_Kill(ent);
}

public TaskDamage(taskID)
{
    new ent = taskID - TASKID_SUM_DAMAGE;

    RadiusDamage(ent);
    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public TaskLightningEffect(taskID)
{
    new ent = taskID - TASKID_SUM_LIGHTNING_EFFECT;

    for (new i = 0; i < 4; ++i) {
        DrawLightingBeam(ent);
    }
}
