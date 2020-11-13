#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Monoculus Rocket"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_monoculus_rocket"

#define EXPLOSION_RADIUS 128.0
#define EXPLOSION_DAMAGE 256.0

new g_sprSmoke;

new Float:g_fThinkDelay;

new g_ceHandler;

new g_sprExlplosion;

new const g_szSndExplode[] = "hwn/misc/pumpkin_explode.wav";

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch");
}

public plugin_precache()
{
    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/props/monoculus_rocket.mdl"),
        .vMins = Float:{-8.0, -8.0, -8.0},
        .vMaxs = Float:{8.0, 8.0, 8.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");

    g_sprSmoke = precache_model("sprites/black_smoke1.spr");

    precache_sound(g_szSndExplode);

    g_sprExlplosion = precache_model("sprites/dexplo.spr");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded()
{
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnSpawn(ent)
{
    set_pev(ent, pev_solid, SOLID_TRIGGER);
    set_pev(ent, pev_movetype, MOVETYPE_FLY);

    set_pev(ent, pev_rendermode, kRenderNormal);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 4.0);
    set_pev(ent, pev_rendercolor, {HWN_COLOR_PRIMARY_F});

    TaskThink(ent);
}

public OnRemove(ent)
{
    remove_task(ent);
}

public OnKilled(ent)
{
    ExplosionEffect(ent);

    new owner = pev(ent, pev_owner);
    if (!pev_valid(owner)) {
        owner = 0;
    }

    RocketRadiusDamage(ent, owner);
}

public OnTouch(ent, target)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    CE_Kill(ent, target);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskThink(ent)
{
    if (!pev_valid(ent)) {
        return;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    //Fix for smoke origin
    {
        static Float:vSub[3];
        UTIL_GetDirectionVector(ent, vSub, 32.0);
        vSub[2] += 18.0;

        xs_vec_sub(vOrigin, vSub, vOrigin);
    }

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_short(g_sprSmoke);
    write_byte(10);
    write_byte(90);
    message_end();

    set_task(g_fThinkDelay, "TaskThink", ent);
}

RocketRadiusDamage(ent, owner)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new target;
    new prevTarget;
    while ((target = engfunc(EngFunc_FindEntityInSphere, target, vOrigin, EXPLOSION_RADIUS * 2)) > 0)
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

        if (pev(target, pev_deadflag) != DEAD_NO) {
            continue;
        }

        if (pev(target, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        static Float:vTargetOrigin[3];
        pev(target, pev_origin, vTargetOrigin);

        new Float:fDamage = UTIL_CalculateRadiusDamage(vOrigin, vTargetOrigin, EXPLOSION_RADIUS, EXPLOSION_DAMAGE);

        if (UTIL_IsPlayer(target)) {
            UTIL_CS_DamagePlayer(target, fDamage, DMG_ALWAYSGIB, owner, owner);
        } else {
            ExecuteHamB(Ham_TakeDamage, target, owner, owner, fDamage, DMG_GENERIC);
        }
    }
}

ExplosionEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 16.0;

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_short(g_sprExlplosion);
    write_byte(32);
    write_byte(10);
    write_byte(0);
    message_end();

    emit_sound(ent, CHAN_BODY, g_szSndExplode, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    UTIL_Message_Dlight(vOrigin, 32, {HWN_COLOR_PRIMARY}, UTIL_DelayToLifeTime(g_fThinkDelay), 0);
}