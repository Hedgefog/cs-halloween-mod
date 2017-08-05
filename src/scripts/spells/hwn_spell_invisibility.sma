#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Invisibility Spell"
#define AUTHOR "Hedgehog Fog"

const Float:InvisibilityTime = 10.0;

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 255, 255};

new FadeEffectColor[3] = {128, 128, 128};
new const Float:FadeEffectTimeRatio = 1.2;

new const g_szSndDetonate[] = "hwn/spells/spell_teleport.wav";

new g_sprEffectTrace;

new Array:g_playerInvisibilityStart;

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
    g_playerInvisibilityStart = ArrayCreate(1, g_maxPlayers);

    register_message(get_user_msgid("ScreenFade"), "OnMessage_ScreenFade");

    for (new i = 0; i < g_maxPlayers; ++i) {
        ArrayPushCell(g_playerInvisibilityStart, 0.0);
    }
}

public plugin_end()
{
    ArrayDestroy(g_playerInvisibilityStart);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnMessage_ScreenFade(msg, type, id)
{
    set_task(0.25, "TaskFixInvisibleEffect", id);
}

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
        FadeEffect(id, InvisibilityTime);
        
        if (task_exists(id)) {
            remove_task(id);
        }
        
        set_task(10.0, "TaskRemoveInvisibility", id);
    }
    
    ArrayDestroy(users);

    DetonateEffect(id, vOrigin);
}

/*--------------------------------[ Methods ]--------------------------------*/

FadeEffect(id, Float:fTime, bool:external = true)
{
    UTIL_ScreenFade(id, FadeEffectColor, fTime*FadeEffectTimeRatio, 0.0, 128, FFADE_IN, .bExternal = external);
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

/*--------------------------------[ Methods ]--------------------------------*/

SetInvisible(id, bool:value = true)
{
	if (value) {
		set_pev(id, pev_rendermode, kRenderTransTexture);
		set_pev(id, pev_renderamt, 15.0);

		ArraySetCell(g_playerInvisibilityStart, id, get_gametime());
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

public TaskFixInvisibleEffect(id)
{
    new Float:fStart = Float:ArrayGetCell(g_playerInvisibilityStart, id);
    new Float:fTimeleft =  fStart > 0.0 ? InvisibilityTime - (get_gametime() - fStart) : 0.0;

    if (fTimeleft > 0.0) {
        FadeEffect(id, fTimeleft, false);
    }
}
