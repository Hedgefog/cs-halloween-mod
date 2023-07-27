#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include <api_rounds>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Moon Jump Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 25.0;
const EffectRadius = 32;
new const EffectColor[3] = {32, 32, 32};

new const g_szSndDetonate[] = "hwn/spells/spell_moonjump.wav";

new g_iPlayerSpellEffectFlag = 0;

new g_hWofSpell;

public plugin_precache() {
    precache_sound(g_szSndDetonate);

    Hwn_Spell_Register(
        "Moon Jump",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability,
        "Cast"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Moon Jump", "Invoke", "Revoke");
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

    remove_task(pPlayer);
    SetSpellEffect(pPlayer, false);
}

bool:GetSpellEffect(pPlayer) {
    return !!(g_iPlayerSpellEffectFlag & BIT(pPlayer & 31));
}

SetSpellEffect(pPlayer, bool:bValue) {
    if (is_user_connected(pPlayer)) {
        SetGravity(pPlayer, bValue);
    }

    if (bValue) {
        g_iPlayerSpellEffectFlag |= BIT(pPlayer & 31);
    } else {
        g_iPlayerSpellEffectFlag &= ~BIT(pPlayer & 31);
    }
}

SetGravity(pPlayer, bool:bValue) {
    if (bValue) {
        new Float:flGravityValue = MOON_GRAVIY;
        set_pev(pPlayer, pev_gravity, flGravityValue);
    } else {
        set_pev(pPlayer, pev_gravity, 1.0);
    }
}

DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    UTIL_Message_Dlight(vecOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(pEntity, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
