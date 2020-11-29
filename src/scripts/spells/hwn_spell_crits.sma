#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Crits Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectTime = 10.0;
const EffectRadius = 32;
new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndDetonate[] = "hwn/spells/spell_crit.wav";

new g_playerSpellEffectFlag = 0;

new g_hWofSpell;

new g_maxPlayers;

public plugin_precache()
{
    precache_sound(g_szSndDetonate);

    Hwn_Spell_Register("Crits", Hwn_SpellFlag_Rare, "Cast");
    g_hWofSpell = Hwn_Wof_Spell_Register("Crits", "Invoke", "Revoke");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Killed, "player", "Revoke", .Post = 1);

    g_maxPlayers = get_maxplayers();
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

public Hwn_Gamemode_Fw_NewRound()
{
    for (new i = 1; i <= g_maxPlayers; ++i) {
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

    SetSpellEffect(id, false);
    remove_task(id);
}

bool:GetSpellEffect(id)
{
    return !!(g_playerSpellEffectFlag & (1 << (id & 31)));
}

SetSpellEffect(id, bool:value)
{
    if (value) {
        g_playerSpellEffectFlag |= (1 << (id & 31));
    } else {
        g_playerSpellEffectFlag &= ~(1 << (id & 31));
    }

    Hwn_Crits_Set(id, value);
}

DetonateEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_Dlight(vOrigin, EffectRadius, EffectColor, 5, 80);
    emit_sound(ent, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
