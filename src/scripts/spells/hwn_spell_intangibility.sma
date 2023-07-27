#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include <api_rounds>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Intangibility Spell"
#define AUTHOR "Hedgehog Fog"

#define STATUS_ICON "suit_empty"

const Float:EffectTime = 5.0;

new const g_szSndDetonate[] = "hwn/spells/spell_intangibility.wav";

new g_iPlayerSpellEffectFlag = 0;

new g_hWofSpell;

public plugin_precache() {
    precache_sound(g_szSndDetonate);

    Hwn_Spell_Register(
        "Intangibility",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Protection,
        "Cast"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Intangibility", "Invoke", "Revoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
    RegisterHamPlayer(Ham_TraceAttack, "HamHook_Player_TraceAttack", .Post = 0);
    RegisterHamPlayer(Ham_TraceAttack, "HamHook_Player_TraceAttack_Post", .Post = 1);
    RegisterHamPlayer(Ham_TakeDamage, "HamHook_Player_TakeDamage", .Post = 0);

}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_disconnected(pPlayer) {
    Revoke(pPlayer);
}

public Round_Fw_NewRound() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        Revoke(pPlayer);
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed_Post(pPlayer) {
    Revoke(pPlayer);
}

public HamHook_Player_TraceAttack(pPlayer, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (~g_iPlayerSpellEffectFlag & BIT(pPlayer & 31)) {
        return HAM_IGNORED;
    }

    set_pev(pPlayer, pev_solid, SOLID_NOT);

    return HAM_SUPERCEDE;
}

public HamHook_Player_TraceAttack_Post(pPlayer, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    set_pev(pPlayer, pev_solid, SOLID_SLIDEBOX);

    return HAM_HANDLED;
}

public HamHook_Player_TakeDamage(pPlayer, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (~g_iPlayerSpellEffectFlag & BIT(pPlayer & 31)) {
        return HAM_IGNORED;
    }

    if (iDamageBits & DMG_BULLET) {
        return HAM_SUPERCEDE;
    }

    if (pInflictor && pev(pInflictor, pev_flags) & FL_MONSTER) {
        return HAM_SUPERCEDE;
    }

    return HAM_HANDLED;
}

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(pPlayer) {
    Invoke(pPlayer, EffectTime);

    if (Hwn_Wof_Effect_GetCurrentSpell() != g_hWofSpell) {
        set_task(EffectTime, "Revoke", pPlayer);
    }
}

public Invoke(pPlayer, Float:flTime) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    UTIL_ScreenFade(pPlayer, {50, 50, 50}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);

    Revoke(pPlayer);
    SetSpellEffect(pPlayer, true);
    DetonateEffect(pPlayer);
}

public Revoke(pPlayer) {
    if (!GetSpellEffect(pPlayer)) {
        return;
    }

    remove_task(pPlayer);
    SetSpellEffect(pPlayer, false);
}

bool:GetSpellEffect(pPlayer) {
    return !!(g_iPlayerSpellEffectFlag & BIT(pPlayer & 31));
}

SetSpellEffect(pPlayer, bool:bValue) {
    if (bValue) {
        g_iPlayerSpellEffectFlag |= BIT(pPlayer & 31);
    } else {
        g_iPlayerSpellEffectFlag &= ~BIT(pPlayer & 31);
    }

    if (is_user_connected(pPlayer)) {
        set_pev(pPlayer, pev_renderfx, bValue ? kRenderFxHologram : kRenderFxNone);
    }

    UTIL_Message_StatusIcon(pPlayer, bValue, STATUS_ICON, {HWN_COLOR_PRIMARY});
}

DetonateEffect(pEntity) {
    emit_sound(pEntity, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
