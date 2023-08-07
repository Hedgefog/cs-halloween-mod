#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_player_burn>

#include <hwn>
#include <hwn_utils>
#include <hwn_wof>

#define PLUGIN "[Hwn] Fire WoF Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectRadius = 64.0;
new const EffectColor[3] = {255, 127, 47};

new const g_szSndDetonate[] = "hwn/spells/spell_fireball_impact.wav";

new g_iEffectModelIndex;

public plugin_precache() {
    g_iEffectModelIndex = precache_model("sprites/plasma.spr");

    precache_sound(g_szSndDetonate);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    Hwn_Wof_Spell_Register("Fire", "Invoke", "Revoke");
}

public Invoke(pPlayer, Float:flTime) {
    burn_player(pPlayer, 0);

    new Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectModelIndex, 0, 3, 32, 255, EffectColor, 100, 0);
    emit_sound(pPlayer, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public Revoke(pPlayer, Float:flTime) {
    if (is_user_alive(pPlayer)) {
        extinguish_player(pPlayer);
    }
}
