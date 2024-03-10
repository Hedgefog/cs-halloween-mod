#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Boss Healthbar"
#define AUTHOR "Hedgehog Fog"

#define HEALTHBAR_CLASSNAME "info_target"

#define HEALTHBAR_Z_OFFSET 48.0
#define HEALTHBAR_FRAME_COUNT 32
#define HEALTHBAR_SCALE 1.0
#define HEALTHBAR_RENDERAMT 200.0

new g_pCvarEnabled;

new g_iszHealthBarClassname;
new g_iBossHealthBarModelIndex;

new g_pHealthBar;
new Float:g_flBossHealth;
new g_pBoss = 0;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarEnabled = register_cvar("hwn_boss_healthbar", "1");

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);
}

public plugin_precache() {
    g_iBossHealthBarModelIndex = precache_model("sprites/hwn/boss_healthbar.spr");
    g_iszHealthBarClassname = engfunc(EngFunc_AllocString, HEALTHBAR_CLASSNAME);
}

public Hwn_Bosses_Fw_BossSpawn(pEntity) {
    if (!get_pcvar_bool(g_pCvarEnabled)) return;

    g_pBoss = pEntity;
    pev(g_pBoss, pev_health, g_flBossHealth);

    if (!g_pHealthBar) {
        g_pHealthBar = @HealthBar_Create();
    }
}

public Hwn_Bosses_Fw_BossRemove() {
    g_pBoss = 0;

    if (g_pHealthBar) {
        @HealthBar_Destroy(g_pHealthBar);
        g_pHealthBar = 0;
    }
}

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage) {
    if (pEntity != g_pBoss) return;
    if (!IS_PLAYER(pAttacker)) return;

    static Float:flHealth; pev(g_pBoss, pev_health, flHealth);
    static Float:flHealthMultiplier; flHealthMultiplier = floatclamp(1.0 - (flHealth / g_flBossHealth), 0.0, 1.0);
    static Float:flFrame; flFrame = (HEALTHBAR_FRAME_COUNT - 1) * flHealthMultiplier;

    set_pev(g_pHealthBar, pev_frame, flFrame);
}

@HealthBar_Create() {
    new this = engfunc(EngFunc_CreateNamedEntity, g_iszHealthBarClassname);

    set_pev(this, pev_modelindex, g_iBossHealthBarModelIndex);
    set_pev(this, pev_rendermode, kRenderTransAdd);
    set_pev(this, pev_renderamt, HEALTHBAR_RENDERAMT);
    set_pev(this, pev_scale, HEALTHBAR_SCALE);
    set_pev(this, pev_solid, SOLID_NOT);
    set_pev(this, pev_movetype, MOVETYPE_NONE);
    set_pev(this, pev_framerate, 0.0);
    set_pev(this, pev_frame, 0);
    set_pev(this, pev_effects, 0);

    dllfunc(DLLFunc_Spawn, this);

    SetThink(this, "@HealthBar_Think");

    set_pev(this, pev_nextthink, get_gametime());

    return this;
}

@HealthBar_Destroy(this) {
    SetThink(this, NULL_STRING);
    set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
    dllfunc(DLLFunc_Think, this);
}

@HealthBar_Think(this) {
    if (g_pBoss) {
        static Float:vecBossMaxs[3];
        pev(g_pBoss, pev_maxs, vecBossMaxs);

        static Float:vecOrigin[3];
        pev(g_pBoss, pev_origin, vecOrigin);
        vecOrigin[2] += (vecBossMaxs[2] + HEALTHBAR_Z_OFFSET);
        engfunc(EngFunc_SetOrigin, this, vecOrigin);
    }

    set_pev(this, pev_nextthink, get_gametime() + Hwn_GetUpdateRate());
}
