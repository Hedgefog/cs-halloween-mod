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

new g_iEffectModelIndex;

new g_hWofSpell;

public plugin_precache() {
    g_iEffectModelIndex = precache_model("sprites/smoke.spr");
    precache_sound(g_szSndDetonate);

    Hwn_Spell_Register(
        "Overheal",
        Hwn_SpellFlag_Applicable | Hwn_SpellFlag_Heal | Hwn_SpellFlag_Radius,
        "Invoke"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Overheal", "Invoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_hWofSpell == iSpell) {
        Hwn_Wof_Abort();
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

public Invoke(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    new iTeam = get_member(pPlayer, m_iTeam);

    new Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    new pTarget = 0;
    while ((pTarget = UTIL_FindUsersNearby(pTarget, vecOrigin, EffectRadius, .iTeam = iTeam)) != 0) {
        if (iTeam != get_member(pTarget, m_iTeam)) {
            continue;
        }

        set_pev(pTarget, pev_health, 150.0);
        UTIL_ScreenFade(pTarget, {255, 0, 0}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
        UTIL_Message_BeamEnts(pPlayer, pTarget, g_iEffectModelIndex, .iLifeTime = 10, .iColor = EffectColor, .iWidth = 8, .iNoise = 120);
    }

    DetonateEffect(pPlayer);
}

DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    vecOrigin[2] += vecMins[2] + 1.0;

    UTIL_Message_BeamDisk(vecOrigin, EffectRadius * 2, g_iEffectModelIndex, 0, 5, 0, 0, EffectColor, 100, 0);

    emit_sound(pEntity, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
