#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>

#include <api_rounds>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Invisibility Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 9.9;
const Float:EffectRadius = 16.0;
new const EffectColor[3] = {255, 255, 255};

const Float:FadeEffectMaxTime = 10.0;
new FadeEffectColor[3] = {128, 128, 128};

new const g_szSndDetonate[] = "hwn/spells/spell_stealth.wav";

new g_iEffectTraceModelIndex;

new g_iPlayerSpellEffectFlag = 0;
new Float:g_rgflPlayerSpellEffectStart[MAX_PLAYERS + 1];
new Float:g_rgflPlayerSpellEffectTime[MAX_PLAYERS + 1];

new g_hWofSpell;

public plugin_precache() {
    g_iEffectTraceModelIndex = precache_model("sprites/xbeam4.spr");
    precache_sound(g_szSndDetonate);

    Hwn_Spell_Register(
        "Invisibility",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Ability | Hwn_SpellFlag_Protection,
        "Cast"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Invisibility", "Invoke", "Revoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "Revoke", .Post = 1);

    register_message(get_user_msgid("ScreenFade"), "Message_ScreenFade");

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

public Message_ScreenFade(msg, type, pPlayer) {
    if (!GetSpellEffect(pPlayer)) {
        return;
    }

    set_task(0.25, "Task_FixInvisibleEffect", pPlayer);
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

    Revoke(pPlayer);
    SetSpellEffect(pPlayer, true, flTime);
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

SetSpellEffect(pPlayer, bool:bValue, Float:flTime = 0.0) {
    if (bValue) {
        FadeEffect(pPlayer, flTime);
        g_rgflPlayerSpellEffectStart[pPlayer] = get_gametime();
        g_rgflPlayerSpellEffectTime[pPlayer] = flTime;
        g_iPlayerSpellEffectFlag |= BIT(pPlayer & 31);
    } else {
        RemoveFadeEffect(pPlayer);
        g_iPlayerSpellEffectFlag &= ~BIT(pPlayer & 31);
    }

    if (is_user_connected(pPlayer)) {
        SetInvisibility(pPlayer, bValue);
    }
}

SetInvisibility(pEntity, bool:bValue) {
    if (bValue) {
        set_pev(pEntity, pev_rendermode, kRenderTransTexture);
        set_pev(pEntity, pev_renderamt, 15.0);
    } else {
        set_pev(pEntity, pev_rendermode, kRenderNormal);
        set_pev(pEntity, pev_renderamt, 0.0);
    }
}

FadeEffect(pPlayer, Float:flTime, bool:external = true) {
    UTIL_ScreenFade(pPlayer, FadeEffectColor, -1.0, flTime > FadeEffectMaxTime ? (FadeEffectMaxTime + 0.1) : flTime, 128, FFADE_IN, .bExternal = external);

    if (external) {
        new iIterationsNum = floatround(flTime / FadeEffectMaxTime, floatround_ceil);
        for (new i = 1; i < iIterationsNum; ++i) {
            set_task(i * FadeEffectMaxTime, "Task_FixInvisibleEffect", pPlayer);
        }
    }
}

RemoveFadeEffect(pPlayer) {
    UTIL_ScreenFade(pPlayer);
}

DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    vecOrigin[2] += vecMins[2];

    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectTraceModelIndex, 0, 3, 90, 255, EffectColor, 100, 0);
    emit_sound(pEntity, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_FixInvisibleEffect(pPlayer) {
    new Float:flStart = g_rgflPlayerSpellEffectStart[pPlayer];
    new Float:flTime = g_rgflPlayerSpellEffectTime[pPlayer];
    new Float:flTimeleft =  flStart > 0.0 ? flTime - (get_gametime() - flStart) : 0.0;

    if (flTimeleft > 0.0) {
        FadeEffect(pPlayer, flTimeleft, false);
    }
}
