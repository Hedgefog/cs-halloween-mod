#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_player_effects>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Invisibility Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "hwn-invisibility"

const Float:EffectRadius = 16.0;
new const EffectColor[3] = {255, 255, 255};

const Float:FadeEffectMaxTime = 9.9;
new const FadeEffectColor[3] = {128, 128, 128};

new const g_szDetonateSound[] = "hwn/spells/spell_stealth.wav";

new g_iEffectTraceModelIndex;

new Float:g_rgflPlayerNextFixFade[MAX_PLAYERS + 1];

public plugin_precache() {
    g_iEffectTraceModelIndex = precache_model("sprites/xbeam4.spr");
    precache_sound(g_szDetonateSound);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "hostage", {90, 90, 90});

    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);

    register_message(get_user_msgid("ScreenFade"), "Message_ScreenFade");
}

public client_connect(pPlayer) {
    g_rgflPlayerNextFixFade[pPlayer] = 0.0;
}

/*--------------------------------[ Methods ]--------------------------------*/

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

    g_rgflPlayerNextFixFade[this] = 0.0;
}

@Player_FadeEffect(this, Float:flDuration, bool:bExternal) {
    new Float:flFadeDuration = floatmin(flDuration + 0.1, FadeEffectMaxTime);
    UTIL_ScreenFade(this, FadeEffectColor, -1.0, flFadeDuration, 128, FFADE_IN, .bExternal = bExternal);
    g_rgflPlayerNextFixFade[this] = get_gametime() + flFadeDuration;
}

@Player_RemoveFadeEffect(this) {
    UTIL_ScreenFade(this);
}

@Player_DetonateEffect(this) {
    new Float:vecMins[3];
    pev(this, pev_mins, vecMins);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += vecMins[2];

    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectTraceModelIndex, 0, 3, 90, 255, EffectColor, 100, 0);
    emit_sound(this, CHAN_STATIC , g_szDetonateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_PostThink_Post(pPlayer) {
    static Float:flGameTime; flGameTime = get_gametime();
    
    if (PlayerEffect_Get(pPlayer, EFFECT_ID)) {
        if (g_rgflPlayerNextFixFade[pPlayer] <= flGameTime) {
            new Float:flDuration = PlayerEffect_GetDuration(pPlayer, EFFECT_ID);
            new Float:flTimeLeft = flDuration > 0.0 ? PlayerEffect_GetEndtime(pPlayer, EFFECT_ID) - flGameTime : FadeEffectMaxTime;
            @Player_FadeEffect(pPlayer, flTimeLeft, false);
        }
    }
}

public Message_ScreenFade(iMsgId, iDest, pPlayer) {
    if (!PlayerEffect_Get(pPlayer, EFFECT_ID)) return;

    new Float:flDuration = (float(get_msg_arg_int(1)) / (1<<12)) + (float(get_msg_arg_int(2)) / (1<<12));
    g_rgflPlayerNextFixFade[pPlayer] = get_gametime() + flDuration;
}
