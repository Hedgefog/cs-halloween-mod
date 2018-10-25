#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Moon Jump Spell"
#define AUTHOR "Hedgehog Fog"

#define GRAVITATIONAL_ACCELERATION_EARTH 9.807
#define GRAVITATIONAL_ACCELERATION_MOON 1.62

const Float:EffectTime = 25.0;

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 255, 255};

new const g_szSndDetonate[] = "hwn/spells/spell_stealth.wav";

new g_sprEffectTrace;

public plugin_precache()
{
    g_sprEffectTrace = precache_model("sprites/xbeam4.spr");

    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
    
    Hwn_Spell_Register("Moon Jump", "OnCast");
}

/*--------------------------------[ Hooks ]--------------------------------*/


public OnPlayerSpawn(id)
{
    SetGravity(id, false);
}

public OnPlayerKilled(id)
{
    SetGravity(id, false);
}

public OnCast(id)
{   
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    SetGravity(id, true);
    set_task(EffectTime, "TaskRemoveGravity", id);
    
    DetonateEffect(id, vOrigin);
}

/*--------------------------------[ Methods ]--------------------------------*/

SetGravity(id, bool:value = true)
{
    if (value) {
        new Float:fGravityValue = (GRAVITATIONAL_ACCELERATION_MOON / GRAVITATIONAL_ACCELERATION_EARTH);
        set_pev(id, pev_rendermode, kRenderTransTexture);
        set_pev(id, pev_gravity, fGravityValue);
    } else {
        set_pev(id, pev_gravity, 1.0);
    }
}

DetonateEffect(ent, const Float:vOrigin[3])
{
    UTIL_HwnSpellDetonateEffect(
      .modelindex = g_sprEffectTrace,
      .vOrigin = vOrigin,
      .fRadius = EffectRadius,
      .color = EffectColor
    );

    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskRemoveGravity(id)
{
    SetGravity(id, false);
}
