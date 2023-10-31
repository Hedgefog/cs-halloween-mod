#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Dance Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "dance"

#define DANCE_LIGHT_RANGE 24
#define DANCE_LIGHT_LIFETIME 5
#define DANCE_LIGHT_DECAY_RATE DANCE_LIGHT_RANGE * (10 / DANCE_LIGHT_LIFETIME)
#define DANCE_LIGHT_HEIGHT 32.0
#define DANCE_LIGHT_OFFSET_MAX 32.0
#define DANCE_LIGHT_COLOR_MIN 128
#define DANCE_SOUND_DURATION 4.0
#define DANCE_CHECK_DELAY 0.25
#define DANCE_MIN_MOVE_ANGLE 45.0
#define DANCE_MIN_VIEW_ANGLE 5.0
#define DANCE_DAMAGE 32.0 * DANCE_CHECK_DELAY

new const g_szSndLoop[] = "hwn/spells/spell_dance_loop.wav";

new Float:g_rgvecPlayerNextDanceThink[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerNextSoundLoop[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerLastAngle[MAX_PLAYERS + 1][3];
new Float:g_rgvecPlayerLastViewAngle[MAX_PLAYERS + 1][3];

public plugin_precache() {
    precache_sound(g_szSndLoop);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke");
}

public client_connect(pPlayer) {
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastAngle[pPlayer]);
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastViewAngle[pPlayer]);
}

public HamHook_Player_PostThink_Post(pPlayer) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) {
        return HAM_IGNORED;
    }

    static Float:flGameTime; flGameTime = get_gametime();

    if (g_rgvecPlayerNextDanceThink[pPlayer] <= flGameTime) {
        @Player_DanceThink(pPlayer);
        g_rgvecPlayerNextDanceThink[pPlayer] = flGameTime + DANCE_CHECK_DELAY;
    }
    
    if (g_rgvecPlayerNextSoundLoop[pPlayer] <= flGameTime) {
        @Player_DanceSoundLoop(pPlayer);
        g_rgvecPlayerNextSoundLoop[pPlayer] = get_gametime() + DANCE_SOUND_DURATION;
    }

    return HAM_HANDLED;
}

@Player_EffectInvoke(this, Float:flDuration) {
    new Float:flGameTime = get_gametime();
    g_rgvecPlayerNextDanceThink[this] = flGameTime;
    g_rgvecPlayerNextSoundLoop[this] = flGameTime;
}

@Player_EffectRevoke(this) {
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastAngle[this]);
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastViewAngle[this]);
}

@Player_DanceSoundLoop(this) {
    client_cmd(this, "spk %s", g_szSndLoop);
}

@Player_DanceThink(this) {
    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    static Float:vecViewAngles[3];
    pev(this, pev_v_angle, vecViewAngles);

    static Float:vecAngles[3];
    engfunc(EngFunc_VecToAngles, vecVelocity, vecAngles);

    new rgiColor[3];
    for (new i = 0; i < 2; ++i) {
        rgiColor[random(3)] = DANCE_LIGHT_COLOR_MIN + random(256 - DANCE_LIGHT_COLOR_MIN);
    }

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    for (new i = 0; i < 2; ++i) {
        vecOrigin[i] += random_float(-DANCE_LIGHT_OFFSET_MAX, DANCE_LIGHT_OFFSET_MAX);
    }

    vecOrigin[2] += DANCE_LIGHT_HEIGHT;

    UTIL_Message_Dlight(vecOrigin, DANCE_LIGHT_RANGE, rgiColor, DANCE_LIGHT_LIFETIME, DANCE_LIGHT_DECAY_RATE);

    if (xs_vec_len(g_rgvecPlayerLastAngle[this]) > 0
        && xs_vec_len(g_rgvecPlayerLastViewAngle[this]) > 0
        && get_distance_f(g_rgvecPlayerLastAngle[this], vecAngles) <= DANCE_MIN_MOVE_ANGLE
        && (
            get_distance_f(g_rgvecPlayerLastViewAngle[this], vecViewAngles) <= DANCE_MIN_VIEW_ANGLE
                || get_distance_f(g_rgvecPlayerLastAngle[this], vecAngles) > 0.1 // restrict forward movement on "camera dance"
        )
        && pev(this, pev_flags) & FL_ONGROUND
    ) {
        ExecuteHamB(Ham_TakeDamage, this, 0, 0, DANCE_DAMAGE, DMG_GENERIC);
    }
    
    xs_vec_copy(vecAngles, g_rgvecPlayerLastAngle[this]);
    xs_vec_copy(vecViewAngles, g_rgvecPlayerLastViewAngle[this]);
}
