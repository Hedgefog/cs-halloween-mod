#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Prop Jack'O'Lantern"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_prop_explosive_pumpkin"

#define EXPLOSION_RADIUS 256.0
#define EXPLOSION_DAMAGE 130.0

new g_mdlGibs;
new g_sprExlplosion;

new const g_szSndExplode[] = "hwn/misc/pumpkin_explode.wav";

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{    
    CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/props/pumpkin_explode.mdl"),
        .vMins = Float:{-16.0, -16.0, 0.0},
        .vMaxs = Float:{16.0, 16.0, 32.0},
        .preset = CEPreset_Prop
    );
    
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");
    
    precache_sound(g_szSndExplode);
    
    g_sprExlplosion = precache_model("sprites/dexplo.spr");
    g_mdlGibs = precache_model("models/hwn/props/pumpkin_explode_jib.mdl");
}

public OnSpawn(ent)
{
    set_pev(ent, pev_takedamage, DAMAGE_AIM);
    set_pev(ent, pev_health, 1.0);

    engfunc(EngFunc_DropToFloor, ent);
}

public OnKilled(ent, attacker)
{    
    ExplosionEffect(ent);
    PumpkinRadiusDamage(ent, attacker);
}

PumpkinRadiusDamage(ent, owner)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new target;
    new prevTarget;
    while ((target = engfunc(EngFunc_FindEntityInSphere, target, vOrigin, EXPLOSION_RADIUS)) > 0)
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

        if (target == owner) {
            owner = 0;
        }
        
        static Float:vTargetOrigin[3];
        pev(target, pev_origin, vTargetOrigin);
        
        new Float:fDamage = UTIL_CalculateRadiusDamage(vOrigin, vTargetOrigin, EXPLOSION_RADIUS, EXPLOSION_DAMAGE);
        
        if (UTIL_IsPlayer(target)) {
            UTIL_CS_DamagePlayer(target, fDamage, DMG_ALWAYSGIB, owner, ent);
        } else {
            ExecuteHamB(Ham_TakeDamage, target, ent, owner, fDamage, DMG_GENERIC);
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
    
    static Float:vVelocity[3];
    UTIL_RandomVector(-128.0, 128.0, vVelocity);
    
    UTIL_Message_BreakModel(vOrigin, Float:{16.0, 16.0, 16.0}, vVelocity, 32, g_mdlGibs, 4, 25, 0);
    
    emit_sound(ent, CHAN_BODY, g_szSndExplode, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}