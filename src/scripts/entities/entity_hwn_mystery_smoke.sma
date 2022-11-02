#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Mystery Smoke"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_mystery_smoke"

#define EFFECT_RADIUS 64.0

#define SMOKE_EMIT_FREQUENCY 0.25
#define SMOKE_PARTICLES_AMOUNT 5
#define SMOKE_PARTICLES_LIFETIME 30

const Float:EffectRadius = EFFECT_RADIUS;
const Float:EffectPushForce = 260.0;

new g_sprTeamSmoke[3];
new g_sprNull;

new g_ceHandler;

new Float:g_fThinkDelay;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
    RegisterHam(Ham_Think, CE_BASE_CLASSNAME, "OnThink", .Post = 1);
}

public plugin_precache()
{
    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .vMins = Float:{-EFFECT_RADIUS, -EFFECT_RADIUS, 0.0},
        .vMaxs = Float:{EFFECT_RADIUS, EFFECT_RADIUS, EFFECT_RADIUS}
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");

    g_sprNull = precache_model("sprites/white.spr");
    g_sprTeamSmoke[0] = precache_model("sprites/hwn/magic_smoke.spr");
    g_sprTeamSmoke[1] = precache_model("sprites/hwn/magic_smoke_red.spr");
    g_sprTeamSmoke[2] = precache_model("sprites/hwn/magic_smoke_blue.spr");
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
    set_pev(ent, pev_effects, EF_NODRAW);

    set_pev(ent, pev_rendermode, kRenderTransTexture);
    set_pev(ent, pev_renderamt, 0.0);
    set_pev(ent, pev_modelindex, g_sprNull);
    set_pev(ent, pev_fuser1, 0.0);

    set_pev(ent, pev_nextthink, get_gametime());
}

public OnThink(ent)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    new team = pev(ent, pev_team);
    new teamSmokeIndex = max(0, team < sizeof(g_sprTeamSmoke) ? team : 0);
    new modelIndex = g_sprTeamSmoke[teamSmokeIndex];

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:fLastSmokeEmit;
    pev(ent, pev_fuser1, fLastSmokeEmit);

    if (get_gametime() - fLastSmokeEmit > SMOKE_EMIT_FREQUENCY) {
      engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
      write_byte(TE_FIREFIELD);
      engfunc(EngFunc_WriteCoord, vOrigin[0]);
      engfunc(EngFunc_WriteCoord, vOrigin[1]);
      engfunc(EngFunc_WriteCoord, vOrigin[2]);
      write_short(floatround(EffectRadius));
      write_short(modelIndex);
      write_byte(SMOKE_PARTICLES_AMOUNT);
      write_byte(TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA);
      write_byte(SMOKE_PARTICLES_LIFETIME);
      message_end();

      set_pev(ent, pev_fuser1, get_gametime());
    }

    set_pev(ent, pev_nextthink, get_gametime() + g_fThinkDelay);
}

public OnTouch(ent, target) {
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    if (!UTIL_IsPlayer(target) && !UTIL_IsMonster(target)) {
        return;
    }

    new team = pev(ent, pev_team);
    if (UTIL_IsTeammate(target, team)) {
        return;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_PushFromOrigin(vOrigin, target, EffectPushForce, bool:{ false, false, true });
}
