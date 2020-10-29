#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Blink Spell"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_DAMAGE 1000
#define TASKID_SUM_KILL 2000

const Float:EffectDamage = 15.0;
const Float:EffectRadius = 192.0;
new const EffectColor[3] = {32, 128, 192};

new const g_szSndCast[] = "hwn/spells/spell_lightning_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_lightning_impact.wav";
new const g_szSprSpellBall[] = "sprites/flare6.spr";

new g_sprEffect;

new g_hSpell;

new Float:g_fThinkDelay;

public plugin_precache()
{
    g_sprEffect = precache_model("sprites/lgtning.spr");
    precache_model(g_szSprSpellBall);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_hSpell = Hwn_Spell_Register("Lightning", "OnCast");

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
    CE_RegisterHook(CEFunction_Remove, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballRemove");

    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, EffectColor, _, g_szSprSpellBall, _, 1.0, 10.0);

    if (!ent) {
        return PLUGIN_HANDLED;
    }

    static Float:vVelocity[3];
    pev(ent, pev_velocity, vVelocity);

    xs_vec_normalize(vVelocity, vVelocity);
    xs_vec_mul_scalar(vVelocity, 320.0, vVelocity);

    set_pev(ent, pev_vuser1, vVelocity);
    set_pev(ent, pev_velocity, vVelocity);

    set_pev(ent, pev_iuser1, g_hSpell);

    set_pev(ent, pev_groupinfo, 128);

    CreateThinkTask(ent);
    CreateDamageTask(ent);
    CreateKillTask(ent);

    emit_sound(id, CHAN_BODY, g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

public OnSpellballRemove(ent)
{
    remove_task(ent);
    remove_task(ent+TASKID_SUM_DAMAGE);
    remove_task(ent+TASKID_SUM_KILL);
}

public OnSpellballKilled(ent)
{
    new spellIdx = pev(ent, pev_iuser1);

    if (spellIdx != g_hSpell) {
        return;
    }

    Detonate(ent);
}

/*--------------------------------[ Methods ]--------------------------------*/

CreateThinkTask(ent)
{
    set_task(g_fThinkDelay, "TaskThink", ent);
}

CreateDamageTask(ent)
{
    set_task(0.5, "TaskDamage", ent+TASKID_SUM_DAMAGE);
}

CreateKillTask(ent)
{
    set_task(5.0, "TaskKill", ent+TASKID_SUM_KILL);
}

Detonate(ent)
{
    DetonateEffect(ent);
}

DetonateEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_BeamCylinder(vOrigin, EffectRadius * 3, g_sprEffect, 0, 3, 90, 255, EffectColor, 100, 0);
    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

DrawLightingBeam(const Float:vOrigin[3])
{
    // generate random offset
    static Float:vTarget[3];
    for (new i = 0; i < 3; ++i) {
        vTarget[i] = random_float(-16.0, 16.0);
    }

    // normalize generated vector
    xs_vec_normalize(vTarget, vTarget);

    // add length to target point
    xs_vec_mul_scalar(vTarget, EffectRadius * 0.5, vTarget);

    // finally get target point
    xs_vec_add(vOrigin, vTarget, vTarget);

    engfunc(EngFunc_MessageBegin, MSG_ALL, SVC_TEMPENTITY, vOrigin, 0);
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

/*--------------------------------[ Task ]--------------------------------*/

public TaskKill(taskID)
{
    new ent = taskID - TASKID_SUM_KILL;
    CE_Kill(ent);
}

public TaskDamage(taskID)
{
    new ent = taskID - TASKID_SUM_DAMAGE;

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new owner = pev(ent, pev_owner);
    new team = owner ? UTIL_GetPlayerTeam(owner) : -1;

    new Array:nearbyEntities = UTIL_FindEntityNearby(vOrigin, EffectRadius);
    new size = ArraySize(nearbyEntities);

    for (new i = 0; i < size; ++i) {
        new target = ArrayGetCell(nearbyEntities, i);

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

        if (UTIL_IsPlayer(target)) {
            if (team == UTIL_GetPlayerTeam(target)) {
                continue;
            }

            UTIL_CS_DamagePlayer(target, EffectDamage, DMG_SHOCK, owner, 0);
        } else {
            ExecuteHamB(Ham_TakeDamage, target, 0, owner, EffectDamage, DMG_SHOCK);
        }
    }

    ArrayDestroy(nearbyEntities);

    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    CreateDamageTask(ent);
}

public TaskThink(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new owner = pev(ent, pev_owner);
    new team = owner ? UTIL_GetPlayerTeam(owner) : -1;

    new target;
    new prevTarget;
    while ((target = engfunc(EngFunc_FindEntityInSphere, target, vOrigin, EffectRadius)) != 0)
    {
        if (prevTarget >= target) {
            break; // infinite loop fix
        }

        prevTarget = target;

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

        if (UTIL_IsPlayer(target)) {
            if (team == UTIL_GetPlayerTeam(target)) {
                continue;
            }

            static Float:vDirection[3];
            xs_vec_sub(vTargetOrigin, vOrigin, vDirection);
            xs_vec_normalize(vDirection, vDirection);
            xs_vec_mul_scalar(vDirection, -512.0, vDirection);

            static Float:vTargetVelocity[3];
            pev(target, pev_velocity, vTargetVelocity);

            xs_vec_add(vTargetVelocity, vDirection, vTargetVelocity);
            set_pev(target, pev_velocity, vTargetVelocity);
        }
    }

    // update velocity
    static Float:vVelocity[3];
    pev(ent, pev_vuser1, vVelocity);
    set_pev(ent, pev_velocity, vVelocity);

    for (new i = 0; i < 4; ++i) {
        DrawLightingBeam(vOrigin);
    }

    CreateThinkTask(ent);
}
