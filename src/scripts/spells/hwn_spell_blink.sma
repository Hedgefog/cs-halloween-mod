#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Blink Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELL_NAME "Blink"

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";

public plugin_precache() {
    precache_sound(g_szSndCast);

    Hwn_Spell_Register(SPELL_NAME, Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage, "@Player_CastSpell");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Player_CastSpell(this) {
    static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, this, vecOrigin);
    static Float:vecVelocity[3]; velocity_by_aim(this, 600, vecVelocity);

    new pEntity = CE_Create("hwn_projectile_blinkball", vecOrigin);
    if (!pEntity) return PLUGIN_HANDLED;

    set_pev(pEntity, pev_owner, this);
    set_pev(pEntity, pev_team, get_ent_data(this, "CBasePlayer", "m_iTeam"));
    dllfunc(DLLFunc_Spawn, pEntity);

    CE_CallMethod(pEntity, "Launch", vecVelocity);

    emit_sound(this, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}
