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

new g_sprEffect;

new g_hWofSpell;

new g_maxPlayers;

public plugin_precache()
{
    g_sprEffect = precache_model("sprites/smoke.spr");

    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Spell_Register("Overheal", "Invoke");
    g_hWofSpell = Hwn_Wof_Spell_Register("Overheal", "Invoke");

    g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Forwards ]--------------------------------*/


public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    if (g_hWofSpell == spellIdx) {
        Hwn_Wof_Abort();
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

public Invoke(id)
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
        new nearbyId = ArrayGetCell(users, i);

        if (team != UTIL_GetPlayerTeam(nearbyId)) {
            continue;
        }

        set_pev(nearbyId, pev_health, 150.0);
        UTIL_ScreenFade(nearbyId, {255, 0, 0}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
        UTIL_Message_BeamEnts(id, nearbyId, g_sprEffect, .lifeTime = 10, .color = EffectColor, .width = 8, .noise = 120);
    }

    ArrayDestroy(users);

    DetonateEffect(id);
}

DetonateEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vMins[3];
    pev(ent, pev_mins, vMins);

    vOrigin[2] += vMins[2] + 1.0;

    UTIL_Message_BeamDisk(vOrigin, EffectRadius * 2, g_sprEffect, 0, 5, 0, 0, EffectColor, 100, 0);

    emit_sound(ent, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
