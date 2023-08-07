#include <amxmodx>
#include <fakemeta>
#include <reapi>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Overheal Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "overheal"

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 0, 0};

new const g_szSndDetonate[] = "hwn/spells/spell_overheal.wav";

new g_iEffectModelIndex;

public plugin_precache() {
    g_iEffectModelIndex = precache_model("sprites/smoke.spr");
    precache_sound(g_szSndDetonate);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "cross", EffectColor);
}

@Player_EffectInvoke(pPlayer) {
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

    return PLUGIN_HANDLED;
}

@Player_EffectRevoke(pPlayer) {}

DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    vecOrigin[2] += vecMins[2] + 1.0;

    UTIL_Message_BeamDisk(vecOrigin, EffectRadius * 2, g_iEffectModelIndex, 0, 5, 0, 0, EffectColor, 100, 0);

    emit_sound(pEntity, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
