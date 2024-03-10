#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_player_effects>
#include <api_player_model>
#include <api_player_camera>
#include <api_custom_events>

#include <hwn>
#include <hwn_stun>
#include <hwn_utils>

#define PLUGIN "[Hwn] fear Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "hwn-fear"

new const g_szAnimationsModel[] = "hwn/v700/player.mdl";
new const g_szSound[] = "scientist/sci_fear15.wav";

public plugin_precache() {
    PlayerModel_PrecacheAnimation(g_szAnimationsModel);

    precache_sound(g_szSound);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke");
}

@Player_EffectInvoke(this) {
    Hwn_Stun_Set(this, Hwn_StunType_Slowdown);

    set_ent_data_string(this, "CBasePlayer", "m_szAnimExtention", "fear");
    set_ent_data(this, "CBaseMonster", "m_Activity", ACT_IDLE);
    rg_set_animation(this, PLAYER_IDLE);

    emit_sound(this, CHAN_VOICE, g_szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Player_EffectRevoke(this) {
    Hwn_Stun_Set(this, Hwn_StunType_None);
}

bool:@Player_CanUseWeapon(this) {
    if (!IS_PLAYER(this)) return true;
    if (!is_user_alive(this)) return true;
    if (!PlayerEffect_Get(this, EFFECT_ID)) return true;

    return false;
}
