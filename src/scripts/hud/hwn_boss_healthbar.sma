#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Boss Healthbar"
#define AUTHOR "Hedgehog Fog"

#define BOSS_TARGET_ENTITY_CLASSNAME "hwn_boss_target"

#define HEALTHBAR_Z_OFFSET 48.0
#define HEALTHBAR_FRAME_COUNT 32
#define HEALTHBAR_SCALE 1.0
#define HEALTHBAR_RENDERAMT 200.0

new g_cvarEnabled;

new g_bossEnt = 0;

new g_ptrInfoTargetClassname;
new g_sprBossHealthBar;

new Float:g_fThinkDelay;
new bool:g_enabled = true;

new g_healthBarEnt;
new Float:g_fBossHealth;
new Float:g_fHealthBarOffsetZ;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    if (get_pcvar_num(g_cvarEnabled) <= 0) {
        g_enabled = false;
        return;
    }

    g_ptrInfoTargetClassname = engfunc(EngFunc_AllocString, "info_target");
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_fps"));

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTargetTakeDamage", .Post = 1);

    set_task(g_fThinkDelay, "TaskThink", 0, _, _, "b");
}

public plugin_precache()
{
    g_cvarEnabled = register_cvar("hwn_boss_healthbar", "1");
    g_sprBossHealthBar = precache_model("sprites/hwn/boss_healthbar.spr");
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

    new Float:fMultiplier = (1.0 - fHealth/g_fBossHealth);
    if (fMultiplier > 1.0) {
        fMultiplier = 1.0;
    }

    new Float:fFrame = (HEALTHBAR_FRAME_COUNT - 1) * fMultiplier;
    set_pev(g_healthBarEnt, pev_frame, fFrame);
}

public Hwn_Bosses_Fw_BossSpawn(ent)
{
    if (!g_enabled) {
        return;
    }

    g_bossEnt = ent;
    
    pev(ent, pev_health, g_fBossHealth);

    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);
    g_fHealthBarOffsetZ = vMaxs[2] + HEALTHBAR_Z_OFFSET;

    SpawnHealthBar();
}

public Hwn_Bosses_Fw_BossKill()
{
    ResetBoss();
}

public Hwn_Bosses_Fw_BossEscape()
{
    ResetBoss();
}

ResetBoss()
{
    g_bossEnt = 0;
    if (g_healthBarEnt) {
        set_pev(g_healthBarEnt, pev_effects, EF_NODRAW);
    }
}

SpawnHealthBar()
{
    if (!g_healthBarEnt) {
        g_healthBarEnt = engfunc(EngFunc_CreateNamedEntity, g_ptrInfoTargetClassname);    
        dllfunc(DLLFunc_Spawn, g_healthBarEnt);
    }

    InitHealthBar(g_healthBarEnt);
}

InitHealthBar(ent)
{
    set_pev(ent, pev_modelindex, g_sprBossHealthBar);
    set_pev(ent, pev_rendermode, kRenderTransAdd);
    set_pev(ent, pev_renderamt, HEALTHBAR_RENDERAMT);
    set_pev(ent, pev_scale, HEALTHBAR_SCALE);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_movetype, MOVETYPE_NONE);
    set_pev(ent, pev_framerate, 0.0);
    set_pev(ent, pev_frame, 0);
    set_pev(ent, pev_effects, 0);
}

public TaskThink()
{
    if (!g_healthBarEnt || !g_bossEnt) {
        return;
    }

    static Float:vBarOrigin[3];
    pev(g_bossEnt, pev_origin, vBarOrigin);
    vBarOrigin[2] += g_fHealthBarOffsetZ;
    engfunc(EngFunc_SetOrigin, g_healthBarEnt, vBarOrigin);
}
