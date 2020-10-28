#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Invisibility Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 10.0;
const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 255, 255};

const Float:FadeEffectMaxTime = 10.0;
new FadeEffectColor[3] = {128, 128, 128};

new const g_szSndDetonate[] = "hwn/spells/spell_stealth.wav";

new g_sprEffectTrace;

new g_playerSpellEffectFlag = 0;
new Array:g_playerSpellEffectStart;
new Array:g_playerSpellEffectTime;

new g_hWofSpell;

new g_maxPlayers;

public plugin_precache()
{
    g_sprEffectTrace = precache_model("sprites/xbeam4.spr");

    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Killed, "player", "Revoke", .Post = 1);

    Hwn_Spell_Register("Invisibility", "Cast");
    g_hWofSpell = Hwn_Wof_Spell_Register("Invisibility", "Invoke", "Revoke");

    register_message(get_user_msgid("ScreenFade"), "OnMessage_ScreenFade");

    g_maxPlayers = get_maxplayers();

    g_playerSpellEffectStart = ArrayCreate(1, g_maxPlayers+1);
    g_playerSpellEffectTime = ArrayCreate(1, g_maxPlayers+1);

    for (new i = 0; i <= g_maxPlayers; ++i) {
        ArrayPushCell(g_playerSpellEffectStart, 0.0);
        ArrayPushCell(g_playerSpellEffectTime, 0.0);
    }
}

public plugin_end()
{
    ArrayDestroy(g_playerSpellEffectStart);
    ArrayDestroy(g_playerSpellEffectTime);
}

/*--------------------------------[ Hooks ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    Revoke(id);
}

public OnMessage_ScreenFade(msg, type, id)
{
    if (!GetSpellEffect(id)) {
        return;
    }

    set_task(0.25, "TaskFixInvisibleEffect", id);
}

public Hwn_Gamemode_Fw_NewRound()
{
    for (new i = 0; i <= g_maxPlayers; ++i) {
        Revoke(i);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(id)
{
    new team = UTIL_GetPlayerTeam(id);

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    new Array:users = UTIL_FindUsersNearby(vOrigin, EffectRadius, .team = team, .maxPlayers = g_maxPlayers);
    new userCount = ArraySize(users);

    for (new i = 0; i < userCount; ++i) {
        new nearbyUserID = ArrayGetCell(users, i);

        if (team != UTIL_GetPlayerTeam(nearbyUserID)) {
            continue;
        }

        Revoke(nearbyUserID);
        SetSpellEffect(nearbyUserID, true, EffectTime);

        if (Hwn_Wof_Effect_GetCurrentSpell() != g_hWofSpell) {
            set_task(EffectTime, "Revoke", nearbyUserID);
        }
    }

    ArrayDestroy(users);
    DetonateEffect(id);
}

public Invoke(id, Float:fTime)
{
    if (!is_user_alive(id)) {
        return;
    }

    Revoke(id);
    SetSpellEffect(id, true, fTime);
    DetonateEffect(id);
}

public Revoke(id)
{
    if (!GetSpellEffect(id)) {
        return;
    }

    remove_task(id);
    SetSpellEffect(id, false);
}

bool:GetSpellEffect(id)
{
    return !!(g_playerSpellEffectFlag & (1 << (id & 31)));
}

SetSpellEffect(id, bool:value, Float:fTime = 0.0)
{
    if (value) {
        FadeEffect(id, fTime);
        ArraySetCell(g_playerSpellEffectStart, id, get_gametime());
        ArraySetCell(g_playerSpellEffectTime, id, fTime);
        g_playerSpellEffectFlag |= (1 << (id & 31));
    } else {
        RemoveFadeEffect(id);
        g_playerSpellEffectFlag &= ~(1 << (id & 31));
    }

    if (is_user_connected(id)) {
        SetInvisibility(id, value);
    }
}

SetInvisibility(ent, bool:value)
{
    if (value) {
        set_pev(ent, pev_rendermode, kRenderTransTexture);
        set_pev(ent, pev_renderamt, 15.0);
    } else {
        set_pev(ent, pev_rendermode, kRenderNormal);
        set_pev(ent, pev_renderamt, 0.0);
    }
}

FadeEffect(id, Float:fTime, bool:external = true)
{
    UTIL_ScreenFade(id, FadeEffectColor, -1.0, fTime > FadeEffectMaxTime ? FadeEffectMaxTime : fTime, 128, FFADE_IN, .bExternal = external);

    if (external) {
        new iterationCount = floatround(fTime / FadeEffectMaxTime, floatround_ceil);
        for (new i = 1; i < iterationCount; ++i) {
            set_task(i * FadeEffectMaxTime, "TaskFixInvisibleEffect", id);
        }
    }
}

RemoveFadeEffect(id)
{
    UTIL_ScreenFade(id);
}

DetonateEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_HwnSpellDetonateEffect(
      .modelindex = g_sprEffectTrace,
      .vOrigin = vOrigin,
      .fRadius = EffectRadius,
      .color = EffectColor
    );

    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskFixInvisibleEffect(id)
{
    new Float:fStart = Float:ArrayGetCell(g_playerSpellEffectStart, id);
    new Float:fTime = Float:ArrayGetCell(g_playerSpellEffectTime, id);
    new Float:fTimeleft =  fStart > 0.0 ? fTime - (get_gametime() - fStart) : 0.0;

    if (fTimeleft > 0.0) {
        FadeEffect(id, fTimeleft, false);
    }
}
