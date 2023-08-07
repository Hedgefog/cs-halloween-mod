#include <amxmodx>
#include <fakemeta>
#include <reapi>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "invisibility"

const Float:EffectTime = 9.9;
const Float:EffectRadius = 16.0;
new const EffectColor[3] = {255, 255, 255};

const Float:FadeEffectMaxTime = 10.0;
new FadeEffectColor[3] = {128, 128, 128};

new const g_szSndDetonate[] = "hwn/spells/spell_stealth.wav";

new g_iEffectTraceModelIndex;

public plugin_precache() {
    g_iEffectTraceModelIndex = precache_model("sprites/xbeam4.spr");
    precache_sound(g_szSndDetonate);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke");
    register_message(get_user_msgid("ScreenFade"), "Message_ScreenFade");
}

@Player_EffectInvoke(this, Float:flDuration) {
    @Player_FadeEffect(this, flDuration, true);

    set_pev(this, pev_rendermode, kRenderTransTexture);
    set_pev(this, pev_renderamt, 15.0);

    @Player_DetonateEffect(this);
}

@Player_EffectRevoke(this) {
    @Player_RemoveFadeEffect(this);
    set_pev(this, pev_rendermode, kRenderNormal);
    set_pev(this, pev_renderamt, 0.0);
}

@Player_FadeEffect(this, Float:flTime, bool:external) {
    UTIL_ScreenFade(this, FadeEffectColor, -1.0, flTime > FadeEffectMaxTime ? (FadeEffectMaxTime + 0.1) : flTime, 128, FFADE_IN, .bExternal = external);

    if (external) {
        new iIterationsNum = floatround(flTime / FadeEffectMaxTime, floatround_ceil);
        for (new i = 1; i < iIterationsNum; ++i) {
            set_task(i * FadeEffectMaxTime, "Task_FixInvisibleEffect", this);
        }
    }
}

@Player_RemoveFadeEffect(this) {
    UTIL_ScreenFade(this);
}

@Player_DetonateEffect(pEntity) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    vecOrigin[2] += vecMins[2];

    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectTraceModelIndex, 0, 3, 90, 255, EffectColor, 100, 0);
    emit_sound(pEntity, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public Message_ScreenFade(msg, type, pPlayer) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) {
        return;
    }

    set_task(0.25, "Task_FixInvisibleEffect", pPlayer);
}

public Task_FixInvisibleEffect(pPlayer) {
    new Float:flTimeleft =  1.0;

    if (flTimeleft > 0.0) {
        @Player_FadeEffect(pPlayer, flTimeleft, false);
    }
}
