#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include <api_rounds>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Crits Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 10.0;
const EffectRadius = 32;
new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndDetonate[] = "hwn/spells/spell_crit.wav";

new g_iPlayerSpellEffectFlag = 0;

new g_hWofSpell;

public plugin_precache() {
    precache_sound(g_szSndDetonate);

    Hwn_Spell_Register(
        "Crits",
        (
            Hwn_SpellFlag_Applicable
                | Hwn_SpellFlag_Ability
                | Hwn_SpellFlag_Damage
                | Hwn_SpellFlag_Rare
        ),
        "Cast"
    );
    g_hWofSpell = Hwn_Wof_Spell_Register("Crits", "Invoke", "Revoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "Revoke", .Post = 1);

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

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(pPlayer) {
    Invoke(pPlayer);

    if (Hwn_Wof_Effect_GetCurrentSpell() != g_hWofSpell) {
        set_task(EffectTime, "Revoke", pPlayer);
    }
}

public Invoke(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    Revoke(pPlayer);
    SetSpellEffect(pPlayer, true);
    DetonateEffect(pPlayer);
}

public Revoke(pPlayer) {
    if (!GetSpellEffect(pPlayer)) {
        return;
    }

    SetSpellEffect(pPlayer, false);
    remove_task(pPlayer);
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

    Hwn_Crits_Set(pPlayer, bValue);
}

DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    UTIL_Message_Dlight(vecOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(pEntity, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
