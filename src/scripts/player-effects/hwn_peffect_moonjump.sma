#include <amxmodx>
#include <fakemeta>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Moonjump Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "moonjump"

const Float:EffectTime = 25.0;
const EffectRadius = 32;
new const EffectColor[3] = {32, 32, 32};
new const g_szSndDetonate[] = "hwn/spells/spell_moonjump.wav";

public plugin_precache() {
     precache_sound(g_szSndDetonate);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "item_longjump", {200, 200, 200});
}

@Player_EffectInvoke(pPlayer) {
    set_pev(pPlayer, pev_gravity, MOON_GRAVIY);

    new Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    UTIL_Message_Dlight(vecOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(pPlayer, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Player_EffectRevoke(pPlayer) {
    set_pev(pPlayer, pev_gravity, 1.0);
}
