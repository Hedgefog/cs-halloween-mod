#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Overheal Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectRadius = 128.0;
new const Float:EffectColor[] = {255.0, 0.0, 0.0};

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
    
    Hwn_Spell_Register("Overheal", "OnCast");

    g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Hooks ]--------------------------------*/

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
        
        set_pev(id, pev_health, 150.0);
        UTIL_ScreenFade(id, {255, 0, 0}, 1.0, 0.0, 128, FFADE_IN);
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