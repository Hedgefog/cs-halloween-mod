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

    Hwn_Spell_Register(
        "Overheal",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Heal | Hwn_SpellFlag_Radius,
        "Invoke"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Overheal", "Invoke");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

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

    new Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    new target;
    while ((target = UTIL_FindUsersNearby(target, vOrigin, EffectRadius, .team = team, .maxPlayers = g_maxPlayers)) != 0) {
        if (team != UTIL_GetPlayerTeam(target)) {
            continue;
        }

        set_pev(target, pev_health, 150.0);
        UTIL_ScreenFade(target, {255, 0, 0}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
        UTIL_Message_BeamEnts(id, target, g_sprEffect, .lifeTime = 10, .color = EffectColor, .width = 8, .noise = 120);
    }

    DetonateEffect(id);
}

DetonateEffect(ent)
{
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new Float:vMins[3];
    pev(ent, pev_mins, vMins);

    vOrigin[2] += vMins[2] + 1.0;

    UTIL_Message_BeamDisk(vOrigin, EffectRadius * 2, g_sprEffect, 0, 5, 0, 0, EffectColor, 100, 0);

    emit_sound(ent, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
