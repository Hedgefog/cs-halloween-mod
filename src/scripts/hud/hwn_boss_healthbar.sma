#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>

#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Boss Healthbar"
#define AUTHOR "Hedgehog Fog"

#define BOSS_TARGET_ENTITY_CLASSNAME "hwn_boss_target"

new g_bossEnt = 0;

new g_ptrInfoTargetClassname;
new g_sprBossHealthBar;

new g_healthBarEnt;
new Float:g_fBossHealth;
new Float:g_fHealthBarOffsetZ;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    g_ptrInfoTargetClassname = engfunc(EngFunc_AllocString, "info_target");
}

public plugin_precache()
{
    g_sprBossHealthBar = precache_model("sprites/hwn/boss_healthbar.spr");
    
    RegisterHam(Ham_TakeDamage, "info_target", "OnTargetTakeDamage", .Post = 1);
    register_forward(FM_AddToFullPack, "OnAddToFullPack", 1);
}

public OnTargetTakeDamage(ent, inflictor, attacker, Float:fDamage)
{
    if (ent != g_bossEnt) {
        return;
    }

    if (!UTIL_IsPlayer(attacker)) {
        return;
    }

    static Float:fHealth;
    pev(g_bossEnt, pev_health, fHealth);

    new Float:fFrame = 32.0 * (1.0 - fHealth/g_fBossHealth);
    set_pev(g_healthBarEnt, pev_frame, fFrame);
}

public OnAddToFullPack(es, e, ent, host, hostFlags, player, pSet)
{
    if (ent != g_healthBarEnt) {
        return;
    }

    if (!g_bossEnt) {
        return;
    }

    if(!ent || !host) {
        return;
    }

    if(!is_user_connected(host) || !is_user_alive(host)) {
        return;
    }
        
    static Float:vBarOrigin[3];
    pev(g_bossEnt, pev_origin, vBarOrigin);
    vBarOrigin[2] += g_fHealthBarOffsetZ;
    set_pev(g_healthBarEnt, pev_origin, vBarOrigin);
}

public Hwn_Bosses_Fw_BossSpawn(ent) {
    g_bossEnt = ent;
    
    pev(ent, pev_health, g_fBossHealth);

    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);
    g_fHealthBarOffsetZ = vMaxs[2] + 16.0;

    SpawnHealthBar();
}

public Hwn_Bosses_Fw_BossKill() {
    ResetBoss();
}

public Hwn_Bosses_Fw_BossEscape() {
    ResetBoss();
}

ResetBoss() {
    g_bossEnt = 0;
    if (g_healthBarEnt) {
        set_pev(g_healthBarEnt, pev_effects, EF_NODRAW);
    }
}

SpawnHealthBar()
{
    if (g_healthBarEnt) {
        set_pev(g_healthBarEnt, pev_effects, 0);
        return;
    }

    g_healthBarEnt = engfunc(EngFunc_CreateNamedEntity, g_ptrInfoTargetClassname);
    set_pev(g_healthBarEnt, pev_modelindex, g_sprBossHealthBar);
    set_pev(g_healthBarEnt, pev_rendermode, kRenderTransAdd);
    set_pev(g_healthBarEnt, pev_renderamt, 128.0);
    set_pev(g_healthBarEnt, pev_scale, 0.75);
    set_pev(g_healthBarEnt, pev_movetype, MOVETYPE_FOLLOW);
    // set_pev(g_healthBarEnt, pev_aiment, g_bossEnt);
    set_pev(g_healthBarEnt, pev_framerate, 0.0);
    set_pev(g_healthBarEnt, pev_solid, SOLID_NOT);
    
    set_pev(g_healthBarEnt, pev_origin, Float:{0.0, 0.0, 128.0});
    set_pev(g_bossEnt, pev_view_ofs, Float:{0.0, 0.0, 128.0});

    dllfunc(DLLFunc_Spawn, g_healthBarEnt);
}
