#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Intangibility Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "intangibility"

new const g_szSndDetonate[] = "hwn/spells/spell_intangibility.wav";

public plugin_precache() {
    precache_sound(g_szSndDetonate);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "suit_empty", {64, 64, 64});

    RegisterHamPlayer(Ham_TraceAttack, "HamHook_Player_TraceAttack", .Post = 0);
    RegisterHamPlayer(Ham_TraceAttack, "HamHook_Player_TraceAttack_Post", .Post = 1);
    RegisterHamPlayer(Ham_TakeDamage, "HamHook_Player_TakeDamage", .Post = 0);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_EffectInvoke(pPlayer) {
    set_pev(pPlayer, pev_renderfx, kRenderFxHologram);
    UTIL_ScreenFade(pPlayer, {50, 50, 50}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
    emit_sound(pPlayer, CHAN_STATIC, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Player_EffectRevoke(pPlayer) {
    set_pev(pPlayer, pev_renderfx, kRenderFxNone);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_TraceAttack(pPlayer, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    set_pev(pPlayer, pev_solid, SOLID_NOT);

    return HAM_SUPERCEDE;
}

public HamHook_Player_TraceAttack_Post(pPlayer, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    set_pev(pPlayer, pev_solid, SOLID_SLIDEBOX);

    return HAM_HANDLED;
}

public HamHook_Player_TakeDamage(pPlayer, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    if (iDamageBits & DMG_BULLET) return HAM_SUPERCEDE;
    if (pInflictor && pev(pInflictor, pev_flags) & FL_MONSTER) return HAM_SUPERCEDE;

    return HAM_HANDLED;
}
