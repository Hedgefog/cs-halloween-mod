#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_rounds>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Intangibility Spell"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#define STATUS_ICON "suit_empty"

const Float:EffectTime = 5.0;

new const g_szSndDetonate[] = "hwn/spells/spell_intangibility.wav";

new g_playerSpellEffectFlag = 0;

new g_hWofSpell;

new g_maxPlayers;

public plugin_precache()
{
    precache_sound(g_szSndDetonate);

    Hwn_Spell_Register(
        "Intangibility",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Protection,
        "Cast"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Intangibility", "Invoke", "Revoke");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
    RegisterHam(Ham_TraceAttack, "player", "OnPlayerTraceAttackPre", .Post = 0);
    RegisterHam(Ham_TraceAttack, "player", "OnPlayerTraceAttack", .Post = 1);
    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamagePre", .Post = 0);

    g_maxPlayers = get_maxplayers();
}

/*--------------------------------[ Forwards ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    Revoke(id);
}

public Round_Fw_NewRound()
{
    for (new i = 1; i <= g_maxPlayers; ++i) {
        Revoke(i);
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerKilled(id) {
    Revoke(id);
}

public OnPlayerTraceAttackPre(id, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (~g_playerSpellEffectFlag & (1 << (id & 31))) {
        return HAM_IGNORED;
    }

    set_pev(id, pev_solid, SOLID_NOT);

    return HAM_SUPERCEDE;
}

public OnPlayerTraceAttack(id, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits) {
    set_pev(id, pev_solid, SOLID_SLIDEBOX);

    return HAM_HANDLED;
}

public OnPlayerTakeDamagePre(id, inflictor, attacker, Float:fDamage, damageBits)
{
    if (~g_playerSpellEffectFlag & (1 << (id & 31))) {
        return HAM_IGNORED;
    }

    if (damageBits & DMG_BULLET) {
        return HAM_SUPERCEDE;
    }

    if (inflictor && pev(inflictor, pev_flags) & FL_MONSTER) {
        return HAM_SUPERCEDE;
    }

    return HAM_HANDLED;
}

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(id)
{
    Invoke(id, EffectTime);

    if (Hwn_Wof_Effect_GetCurrentSpell() != g_hWofSpell) {
        set_task(EffectTime, "Revoke", id);
    }
}

public Invoke(id, Float:fTime)
{
    if (!is_user_alive(id)) {
        return;
    }

    UTIL_ScreenFade(id, {50, 50, 50}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);

    Revoke(id);
    SetSpellEffect(id, true);
    DetonateEffect(id);
}

public Revoke(id)
{
    if (!GetSpellEffect(id)) {
        return;
    }

    remove_task(id);
    SetSpellEffect(id, false);
}

bool:GetSpellEffect(id)
{
    return !!(g_playerSpellEffectFlag & (1 << (id & 31)));
}

SetSpellEffect(id, bool:value)
{
    if (value) {
        g_playerSpellEffectFlag |= (1 << (id & 31));
    } else {
        g_playerSpellEffectFlag &= ~(1 << (id & 31));
    }

    if (is_user_connected(id)) {
        if (value) {
            set_pev(id, pev_renderfx, kRenderFxHologram);
        } else {
            set_pev(id, pev_renderfx, kRenderFxNone);
        }
    }

    UTIL_Message_StatusIcon(id, value, STATUS_ICON, {HWN_COLOR_PRIMARY});
}

DetonateEffect(ent)
{
    emit_sound(ent, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
