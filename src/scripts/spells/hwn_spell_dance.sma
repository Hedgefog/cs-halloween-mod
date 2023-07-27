#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_rounds>
#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Dance Spell"
#define AUTHOR "Hedgehog Fog"

#define LIGHT_RANGE 24
#define LIGHT_LIFETIME 5
#define LIGHT_DECAY_RATE LIGHT_RANGE * (10 / LIGHT_LIFETIME)
#define LIGHT_HEIGHT 32.0
#define LIGHT_OFFSET_MAX 32.0
#define LIGHT_COLOR_MIN 128
#define SOUND_DURATION 4.0
#define DANCE_CHECK_DELAY 0.25
#define HEALTH_TO_DIE 250.0
#define DANCE_MIN_MOVE_ANGLE 45.0
#define DANCE_MIN_VIEW_ANGLE 5.0
#define EFFECT_DAMAGE HEALTH_TO_DIE / EffectTime * DANCE_CHECK_DELAY

const Float:EffectTime = 8.0;

new const g_szSndLoop[] = "hwn/spells/spell_dance_loop.wav";

new g_hWofSpell;

new Float:g_rgvecPlayerLastAngle[MAX_PLAYERS + 1][3];
new Float:g_rgvecPlayerLastViewAngle[MAX_PLAYERS + 1][3];

public plugin_precache() {
    precache_sound(g_szSndLoop);

    g_hWofSpell = Hwn_Wof_Spell_Register("Dance", "Invoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed");

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastAngle[pPlayer]);
        xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastViewAngle[pPlayer]);
    }
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_disconnected(pPlayer) {
    Revoke(pPlayer);
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_hWofSpell == iSpell) {
        Hwn_Wof_Abort();
    }
}

public Round_Fw_NewRound() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        Revoke(pPlayer);
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed(pPlayer) {
    Revoke(pPlayer);
}

/*--------------------------------[ Methods ]--------------------------------*/

public Invoke(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    set_task(DANCE_CHECK_DELAY, "CheckDance", pPlayer, _, _, "b");
    set_task(EffectTime, "Revoke", pPlayer);

    new iIterationsNum = floatround(EffectTime / SOUND_DURATION, floatround_ceil);
    for (new i = 1; i < iIterationsNum; ++i) {
        set_task(i * SOUND_DURATION, "PlaySound", pPlayer);
    }

    PlaySound(pPlayer);
}

public Revoke(pPlayer) {
    remove_task(pPlayer);
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastAngle[pPlayer]);
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, g_rgvecPlayerLastViewAngle[pPlayer]);
}

public PlaySound(pPlayer) {
    client_cmd(pPlayer, "spk %s", g_szSndLoop);
}

public CheckDance(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    static Float:vecViewAngles[3];
    pev(pPlayer, pev_v_angle, vecViewAngles);

    static Float:vecAngles[3];
    {
        static Float:vecVelocity[3];
        pev(pPlayer, pev_velocity, vecVelocity);
        engfunc(EngFunc_VecToAngles, vecVelocity, vecAngles);
    }

    new rgiColor[3];
    for (new i = 0; i < 2; ++i) {
        rgiColor[random(3)] = LIGHT_COLOR_MIN + random(256 - LIGHT_COLOR_MIN);
    }

    static Float:vecOrigin[3];
    {
        pev(pPlayer, pev_origin, vecOrigin);

        for (new i = 0; i < 2; ++i) {
            vecOrigin[i] += random_float(-LIGHT_OFFSET_MAX, LIGHT_OFFSET_MAX);
        }

        vecOrigin[2] += LIGHT_HEIGHT;
    }

    UTIL_Message_Dlight(vecOrigin, LIGHT_RANGE, rgiColor, LIGHT_LIFETIME, LIGHT_DECAY_RATE);

    if (xs_vec_len(g_rgvecPlayerLastAngle[pPlayer]) > 0
        && xs_vec_len(g_rgvecPlayerLastViewAngle[pPlayer]) > 0
        && get_distance_f(g_rgvecPlayerLastAngle[pPlayer], vecAngles) <= DANCE_MIN_MOVE_ANGLE
        && (
            get_distance_f(g_rgvecPlayerLastViewAngle[pPlayer], vecViewAngles) <= DANCE_MIN_VIEW_ANGLE
                || get_distance_f(g_rgvecPlayerLastAngle[pPlayer], vecAngles) > 0.1 // restrict forward movement on "camera dance"
        )
        && pev(pPlayer, pev_flags) & FL_ONGROUND
    ) {
        ExecuteHamB(Ham_TakeDamage, pPlayer, 0, 0, EFFECT_DAMAGE, DMG_GENERIC);
    }
    
    xs_vec_copy(vecAngles, g_rgvecPlayerLastAngle[pPlayer]);
    xs_vec_copy(vecViewAngles, g_rgvecPlayerLastViewAngle[pPlayer]);
}
