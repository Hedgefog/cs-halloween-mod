#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Moon Jump Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 25.0;
const EffectRadius = 48;
new const EffectColor[3] = {32, 32, 32};

new const g_szSndDetonate[] = "hwn/spells/spell_moonjump.wav";

new Array:g_playerSpellEffect;

new g_hWofSpell;

new g_maxPlayers;

public plugin_precache()
{
    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Killed, "player", "Revoke", .Post = 1);

    Hwn_Spell_Register("Moon Jump", "Cast");
    g_hWofSpell = Hwn_Wof_Spell_Register("Moon Jump", "Invoke", "Revoke");

    g_maxPlayers = get_maxplayers();

    g_playerSpellEffect = ArrayCreate(1, g_maxPlayers+1);

    for (new i = 0; i <= g_maxPlayers; ++i) {
        ArrayPushCell(g_playerSpellEffect, false);
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Hwn_Gamemode_Fw_NewRound()
{
    for (new i = 0; i <= g_maxPlayers; ++i) {
        Revoke(i);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(id)
{
    Invoke(id);

    if (Hwn_Wof_Effect_GetCurrentSpell() != g_hWofSpell) {
        set_task(EffectTime, "Revoke", id);
    }
}

public Invoke(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    Revoke(id);
    SetSpellEffect(id, true);
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
    return ArrayGetCell(g_playerSpellEffect, id);
}

SetSpellEffect(id, bool:value)
{
    SetGravity(id, value);
    ArraySetCell(g_playerSpellEffect, id, value);
}

SetGravity(id, bool:value)
{
    if (value) {
        new Float:fGravityValue = (MOON_GRAVIY);
        set_pev(id, pev_gravity, fGravityValue);
    } else {
        set_pev(id, pev_gravity, 1.0);
    }
}

DetonateEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_Dlight(vOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
