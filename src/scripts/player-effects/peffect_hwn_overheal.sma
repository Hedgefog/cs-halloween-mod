#include <amxmodx>
#include <fakemeta>

#include <api_player_effects>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Overheal Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "hwn-overheal"

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 0, 0};

new const g_szDetonateSound[] = "hwn/spells/spell_overheal.wav";

new g_iEffectModelIndex;

public plugin_precache() {
    g_iEffectModelIndex = precache_model("sprites/smoke.spr");
    precache_sound(g_szDetonateSound);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "cross", EffectColor);
}

@Player_EffectInvoke(this) {
    new iTeam = get_ent_data(this, "CBasePlayer", "m_iTeam");

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pTarget = 0;
    while ((pTarget = UTIL_FindUsersNearby(pTarget, vecOrigin, EffectRadius, .iTeam = iTeam)) != 0) {
        if (iTeam != get_ent_data(pTarget, "CBasePlayer", "m_iTeam")) continue;

        set_pev(pTarget, pev_health, 150.0);
        UTIL_ScreenFade(pTarget, {255, 0, 0}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
        UTIL_Message_BeamEnts(this, pTarget, g_iEffectModelIndex, .iLifeTime = 10, .iColor = EffectColor, .iWidth = 8, .iNoise = 120);
    }

    @Player_HealEffect(this);

    return PLUGIN_HANDLED;
}

@Player_EffectRevoke(this) {}

@Player_HealEffect(pEntity) {
    new Float:vecMins[3]; pev(pEntity, pev_mins, vecMins);

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    vecOrigin[2] += vecMins[2] + 1.0;

    UTIL_Message_BeamDisk(vecOrigin, EffectRadius * 2, g_iEffectModelIndex, 0, 5, 0, 0, EffectColor, 100, 0);

    emit_sound(pEntity, CHAN_STATIC , g_szDetonateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}