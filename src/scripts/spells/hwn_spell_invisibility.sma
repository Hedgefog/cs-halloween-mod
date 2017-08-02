#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Invisibility Spell"
#define AUTHOR "Hedgehog Fog"

const Float:InvisibilityTime = 10.0;

const Float:EffectRadius = 128.0;
new const Float:EffectColor[] = {255.0, 127.0, 47.0};

new const g_szSndDetonate[] = "hwn/spells/spell_teleport.wav";

new g_sprEffectTrace;

new g_maxPlayers;

public plugin_precache()
{
    g_sprEffectTrace = precache_model("sprites/xbeam4.spr");

    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
    
    Hwn_Spell_Register("Invisibility", "OnCast");

    g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerKilled(id)
{
	SetInvisible(id, false);
}

public OnCast(id)
{
    new team = get_pdata_int(id, m_iTeam);
    
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);        
    
    new Array:users = UTIL_FindUsersNearby(vOrigin, EffectRadius, .team = team, .maxPlayers = g_maxPlayers);
    new userCount = ArraySize(users);
    
    for (new i = 0; i < userCount; ++i) {
        new id = ArrayGetCell(users, i);
        
        if (team != get_pdata_int(id, m_iTeam)) {
            continue;
        }        
        
        SetInvisible(id, true);
        UTIL_ScreenFade(id, {128, 128, 128}, InvisibilityTime+2.0, 0.0, 128, FFADE_IN);
        
        if (task_exists(id)) {
            remove_task(id);
        }
        
        set_task(10.0, "TaskRemoveInvisibility", id);
    }
    
    ArrayDestroy(users);

    DetonateEffect(id, vOrigin);
}

/*--------------------------------[ Methods ]--------------------------------*/

DetonateEffect(ent, const Float:vOrigin[3])
{
    UTIL_SpellballDetonateEffect(
      .modelindex = g_sprEffectTrace,
      .vOrigin = vOrigin,
      .fRadius = EffectRadius,
      .fColor = EffectColor
    );

    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Methods ]--------------------------------*/

SetInvisible(id, bool:value = true)
{
	if (value) {
		set_pev(id, pev_rendermode, kRenderTransTexture);
		set_pev(id, pev_renderamt, 15.0);
	} else {
		set_pev(id, pev_rendermode, kRenderNormal);
		set_pev(id, pev_renderamt, 0.0);
	}
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskRemoveInvisibility(id)
{
	SetInvisible(id, false);
}