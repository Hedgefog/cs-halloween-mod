#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Hwn] Skeletons Horde Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELL_NAME "Skeletons Horde"

new const g_szSndCast[] = "hwn/spells/spell_skeletons_horde_cast.wav";

public plugin_precache() {
    precache_sound(g_szSndCast);

    Hwn_Spell_Register(
        SPELL_NAME,
        Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Radius | Hwn_SpellFlag_Rare,
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_CastSpell(this) {
    static Float:vecOrigin[3]; ExecuteHamB(Ham_EyePosition, this, vecOrigin);
    static Float:vecVelocity[3]; velocity_by_aim(this, 720, vecVelocity);

    new pEntity = CE_Create("hwn_projectile_skeletonball", vecOrigin);
    if (!pEntity) return PLUGIN_HANDLED;

    set_pev(pEntity, pev_owner, this);
    set_pev(pEntity, pev_team, get_ent_data(this, "CBasePlayer", "m_iTeam"));
    dllfunc(DLLFunc_Spawn, pEntity);

    CE_CallMethod(pEntity, "Launch", vecVelocity);

    emit_sound(this, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}
