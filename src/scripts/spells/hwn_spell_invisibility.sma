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
const Float:MaxFadeTime = 10.0;

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 255, 255};

new FadeEffectColor[3] = {128, 128, 128};
new const Float:FadeEffectTimeRatio = 1.2;

new const g_szSndDetonate[] = "hwn/spells/spell_stealth.wav";

new g_sprEffectTrace;

new Array:g_playerInvisibilityStart;
new Array:g_playerInvisibilityTime;

new g_maxPlayers;

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
    
    Hwn_Spell_Register("Invisibility", "OnCast");
    Hwn_Wof_Spell_Register("Invisibility", "Invoke", "Revoke");

    g_maxPlayers = get_maxplayers();
    g_playerInvisibilityStart = ArrayCreate(1, g_maxPlayers+1);
    g_playerInvisibilityTime = ArrayCreate(1, g_maxPlayers+1);

    register_message(get_user_msgid("ScreenFade"), "OnMessage_ScreenFade");

    for (new i = 0; i <= g_maxPlayers; ++i) {
        ArrayPushCell(g_playerInvisibilityStart, 0.0);
        ArrayPushCell(g_playerInvisibilityTime, 0.0);
    }
}

public plugin_end()
{
    ArrayDestroy(g_playerInvisibilityStart);
    ArrayDestroy(g_playerInvisibilityTime);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnMessage_ScreenFade(msg, type, id)
{
    set_task(0.25, "TaskFixInvisibleEffect", id);
}

public OnPlayerSpawn(id)
{
    SetInvisible(id, false);
}

public OnPlayerKilled(id)
{
    SetInvisible(id, false);
}

public OnCast(id)
{
    new team = UTIL_GetPlayerTeam(id);
    
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);        
    
    new Array:users = UTIL_FindUsersNearby(vOrigin, EffectRadius, .team = team, .maxPlayers = g_maxPlayers);
    new userCount = ArraySize(users);
    
    for (new i = 0; i < userCount; ++i) {
        new id = ArrayGetCell(users, i);
        
        if (team != UTIL_GetPlayerTeam(id)) {
            continue;
        }        
        
        SetInvisible(id, true, InvisibilityTime);
        
        if (task_exists(id)) {
            remove_task(id);
        }
        
        set_task(InvisibilityTime, "TaskRemoveInvisibility", id);
    }
    
    ArrayDestroy(users);

    DetonateEffect(id, vOrigin);
}

public Invoke(id, Float:fTime)
{
    if (!is_user_alive(id)) {
        return;
    }

    SetInvisible(id, true, fTime);

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    DetonateEffect(id, vOrigin);
}

public Revoke(id)
{
    SetInvisible(id, false);
}

/*--------------------------------[ Methods ]--------------------------------*/

SetInvisible(id, bool:value = true, Float:time = 0.0)
{
    if (value) {
        set_pev(id, pev_rendermode, kRenderTransTexture);
        set_pev(id, pev_renderamt, 15.0);

        ArraySetCell(g_playerInvisibilityStart, id, get_gametime());
        ArraySetCell(g_playerInvisibilityTime, id, time);
        FadeEffect(id, time);
    } else {
        set_pev(id, pev_rendermode, kRenderNormal);
        set_pev(id, pev_renderamt, 0.0);

        ArraySetCell(g_playerInvisibilityStart, id, 0.0);
        RemoveFadeEffect(id);
    }
}

FadeEffect(id, Float:fTime, bool:external = true)
{
    UTIL_ScreenFade(id, FadeEffectColor, -1.0, fTime > MaxFadeTime ? MaxFadeTime : fTime, 128, FFADE_IN, .bExternal = external);

    if (external) {
        new iterationCount = floatround(fTime / MaxFadeTime, floatround_ceil);
        for (new i = 1; i < iterationCount; ++i) {
            set_task(i * MaxFadeTime, "TaskFixInvisibleEffect", id);
        }
    }
}

RemoveFadeEffect(id)
{
    UTIL_ScreenFade(id);
    remove_task(id);
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

public TaskRemoveInvisibility(id)
{
    SetInvisible(id, false);
}

public TaskFixInvisibleEffect(id)
{
    new Float:fStart = Float:ArrayGetCell(g_playerInvisibilityStart, id);
    new Float:fTime = Float:ArrayGetCell(g_playerInvisibilityTime, id);
    new Float:fTimeleft =  fStart > 0.0 ? fTime - (get_gametime() - fStart) : 0.0;

    if (fTimeleft > 0.0) {
        FadeEffect(id, fTimeleft, false);
    }
}
