#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Overheal Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 0, 0};

new const g_szSndDetonate[] = "hwn/spells/spell_overheal.wav";

new g_sprEffectTrace;

new g_hWofSpell;

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
    g_hWofSpell = Hwn_Wof_Spell_Register("Overheal", "OnCast");

    g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    if (!is_user_alive(id)) {
        return;
    }

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
        
        set_pev(id, pev_health, 150.0);
        UTIL_ScreenFade(id, {255, 0, 0}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
    }
    
    ArrayDestroy(users);

    DetonateEffect(id, vOrigin);
}

public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    if (g_hWofSpell == spellIdx) {
        Hwn_Wof_Abort();
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

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