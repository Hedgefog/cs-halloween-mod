#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

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
#define HEALTH_TO_DIE 150.0
#define EFFECT_DAMAGE HEALTH_TO_DIE / EffectTime * DANCE_CHECK_DELAY

const Float:EffectTime = 8.0;

new const g_szSndLoop[] = "hwn/spells/spell_dance_loop.wav";

new g_hWofSpell;

new g_maxPlayers;

new Array:g_playerLastAngle;
new Array:g_playerLastViewAngle;

public plugin_precache()
{
    precache_sound(g_szSndLoop);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Killed, "player", "OnPlayerKilled");

    g_hWofSpell = Hwn_Wof_Spell_Register("Dance", "Invoke");

    g_maxPlayers = get_maxplayers();

    g_playerLastAngle = ArrayCreate(3, g_maxPlayers+1);
    g_playerLastViewAngle = ArrayCreate(3, g_maxPlayers+1);

    for (new id = 0; id <= g_maxPlayers; ++id) {
        ArrayPushCell(g_playerLastAngle, 0);
        ArrayPushCell(g_playerLastViewAngle, 0);
    }
}

public plugin_end()
{
    ArrayDestroy(g_playerLastAngle);
    ArrayDestroy(g_playerLastViewAngle);
}


/*--------------------------------[ Forwards ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    Revoke(id);
}

public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    if (g_hWofSpell == spellIdx) {
        Hwn_Wof_Abort();
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerKilled(id)
{
    Revoke(id);
}

/*--------------------------------[ Methods ]--------------------------------*/

public Invoke(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    set_task(DANCE_CHECK_DELAY, "CheckDance", id, _, _, "b");
    set_task(EffectTime, "Revoke", id);

    new iterationCount = floatround(EffectTime / SOUND_DURATION, floatround_ceil);
    for (new i = 1; i < iterationCount; ++i) {
        set_task(i * SOUND_DURATION, "PlaySound", id);
    }

    PlaySound(id);
}

public Revoke(id)
{
    remove_task(id);
    ArraySetArray(g_playerLastAngle, id, {0, 0, 0});
    ArraySetArray(g_playerLastViewAngle, id, {0, 0, 0});
}

public PlaySound(id)
{
    client_cmd(id, "spk %s", g_szSndLoop);
}

public CheckDance(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    new Float:vLastAngles[3];
    ArrayGetArray(g_playerLastAngle, id, vLastAngles);

    new Float:vLastViewAngles[3];
    ArrayGetArray(g_playerLastViewAngle, id, vLastViewAngles);

    static Float:vViewAngles[3];
    pev(id, pev_v_angle, vViewAngles);

    static Float:vAngles[3];
    {
        static Float:vVelocity[3];
        pev(id, pev_velocity, vVelocity);
        engfunc(EngFunc_VecToAngles, vVelocity, vAngles);
    }

    new color[3];
    for (new i = 0; i < 2; ++i) {
        color[random(3)] = LIGHT_COLOR_MIN + random(256 - LIGHT_COLOR_MIN);
    }

    static Float:vOrigin[3];
    {
        pev(id, pev_origin, vOrigin);

        for (new i = 0; i < 2; ++i) {
            vOrigin[i] += random_float(-LIGHT_OFFSET_MAX, LIGHT_OFFSET_MAX);
        }

        vOrigin[2] += LIGHT_HEIGHT;
    }

    UTIL_Message_Dlight(vOrigin, LIGHT_RANGE, color, LIGHT_LIFETIME, LIGHT_DECAY_RATE);

    if (xs_vec_len(vLastAngles) > 0
        && xs_vec_len(vLastViewAngles) > 0
        && get_distance_f(vLastAngles, vAngles) <= 45
        && get_distance_f(vLastViewAngles, vViewAngles) <= 5
        && pev(id, pev_flags) & FL_ONGROUND
    ) {
        UTIL_CS_DamagePlayer(id, EFFECT_DAMAGE);
    }
    
    ArraySetArray(g_playerLastAngle, id, vAngles);
    ArraySetArray(g_playerLastViewAngle, id, vViewAngles);
}
