#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_player_camera>
#include <api_player_effects>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Dance Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "hwn-dance"

#define DANCE_LIGHT_RANGE 24
#define DANCE_LIGHT_LIFETIME 5
#define DANCE_LIGHT_DECAY_RATE DANCE_LIGHT_RANGE * (10 / DANCE_LIGHT_LIFETIME)
#define DANCE_LIGHT_DURATION 0.25
#define DANCE_LIGHT_HEIGHT 32.0
#define DANCE_LIGHT_OFFSET_MAX 32.0
#define DANCE_LIGHT_COLOR_MIN 128
#define DANCE_SOUND_DURATION 4.0
#define DANCE_THINK_RATE 0.25

enum PlayerAnimation {
    PlayerAnimation_Extension[32],
    PLAYER_ANIM:PlayerAnimation_Action,
    Float:PlayerAnimation_Duration,
}

new const g_szSndLoop[] = "hwn/spells/spell_dance_loop.wav";

new const g_rgDancingAnimationsLoop[][PlayerAnimation] = {
    { "dualpistols", PLAYER_RELOAD, 0.35 }
};

new Float:g_rgvecPlayerNextDanceThink[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerNextDanceLight[MAX_PLAYERS + 1];
new Float:g_rgvecPlayerNextSoundLoop[MAX_PLAYERS + 1];
new g_rgiPlayerCurrentDanceMovement[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextAnimationChange[MAX_PLAYERS + 1];

public plugin_precache() {
    precache_sound(g_szSndLoop);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    for (new iWeapon = CSW_P228; iWeapon <= CSW_LAST_WEAPON; ++iWeapon) {
        static szWeapon[32]; get_weaponname(iWeapon, szWeapon, charsmax(szWeapon));
        if (equal(szWeapon, NULL_STRING)) continue;
        RegisterHam(Ham_Item_CanDeploy, szWeapon, "HamHook_Weapon_CanDeploy");
        RegisterHam(Ham_CS_Item_GetMaxSpeed, szWeapon, "HamHook_Weapon_GetMaxSpeed");
        RegisterHam(Ham_Weapon_PrimaryAttack, szWeapon, "HamHook_Weapon_PrimaryAttack");
        RegisterHam(Ham_Weapon_SecondaryAttack, szWeapon, "HamHook_Weapon_SecondaryAttack");
    }

    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink_Post", .Post = 1);

    PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke");
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:@Player_CanUseWeapon(this) {
    if (!IS_PLAYER(this)) return true;
    if (!is_user_alive(this)) return true;
    if (!PlayerEffect_Get(this, EFFECT_ID)) return true;

    return false;
}

@Player_EffectInvoke(this, Float:flDuration) {
    new Float:flGameTime = get_gametime();
    g_rgvecPlayerNextDanceThink[this] = flGameTime;
    g_rgvecPlayerNextSoundLoop[this] = flGameTime;

    if (PlayerCamera_IsActive(this)) {
        PlayerCamera_Deactivate(this);
    }

    PlayerCamera_Activate(this);
    PlayerCamera_SetAngles(this, Float:{15.0, 0.0, 0.0});
    PlayerCamera_SetOffset(this, Float:{0.0, 0.0, 8.0});
    PlayerCamera_SetDistance(this, 128.0);

    new pActiveItem = get_member(this, m_pActiveItem);
    if (pActiveItem != -1) ExecuteHamB(Ham_Item_Holster, pActiveItem, 0);

    rg_reset_maxspeed(this);
}

@Player_EffectRevoke(this) {
    rg_reset_maxspeed(this);

    new pActiveItem = get_member(this, m_pActiveItem);
    if (pActiveItem != -1) ExecuteHamB(Ham_Item_Deploy, pActiveItem);

    PlayerCamera_Deactivate(this);
}

@Player_DanceSoundLoop(this) {
    emit_sound(this, CHAN_STATIC, g_szSndLoop, VOL_NORM, ATTN_IDLE, 0, PITCH_NORM);
}

@Player_DanceThink(this) {
    new rgiColor[3];
    for (new i = 0; i < 2; ++i) {
        rgiColor[random(3)] = DANCE_LIGHT_COLOR_MIN + random(256 - DANCE_LIGHT_COLOR_MIN);
    }

    static Float:flGameTime; flGameTime = get_gametime(); 

    if (g_rgflPlayerNextAnimationChange[this] <= flGameTime) {
        new iDance = g_rgiPlayerCurrentDanceMovement[this];
        set_member(this, m_szAnimExtention, g_rgDancingAnimationsLoop[iDance][PlayerAnimation_Extension]);
        rg_set_animation(this, g_rgDancingAnimationsLoop[iDance][PlayerAnimation_Action]);

        g_rgiPlayerCurrentDanceMovement[this]++;
        if (g_rgiPlayerCurrentDanceMovement[this] >= sizeof(g_rgDancingAnimationsLoop)) {
            g_rgiPlayerCurrentDanceMovement[this] = 0;
        }

        g_rgflPlayerNextAnimationChange[this] = flGameTime + g_rgDancingAnimationsLoop[iDance][PlayerAnimation_Duration];
    }

    if (g_rgvecPlayerNextDanceLight[this] <= flGameTime) {
        static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
        for (new i = 0; i < 2; ++i) vecOrigin[i] += random_float(-DANCE_LIGHT_OFFSET_MAX, DANCE_LIGHT_OFFSET_MAX);
        vecOrigin[2] += DANCE_LIGHT_HEIGHT;
        UTIL_Message_Dlight(vecOrigin, DANCE_LIGHT_RANGE, rgiColor, DANCE_LIGHT_LIFETIME, DANCE_LIGHT_DECAY_RATE);

        g_rgvecPlayerNextDanceLight[this] = flGameTime + DANCE_LIGHT_DURATION;
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Weapon_CanDeploy(pWeapon) {
    new pPlayer = get_member(pWeapon, m_pPlayer);

    if (!@Player_CanUseWeapon(pPlayer)) {
        SetHamReturnInteger(0);
        return HAM_OVERRIDE;
    }

    return HAM_IGNORED;
}

public HamHook_Weapon_GetMaxSpeed(pWeapon) {
    new pPlayer = get_member(pWeapon, m_pPlayer);

    if (!@Player_CanUseWeapon(pPlayer)) {
        SetHamReturnFloat(1.0);
        return HAM_OVERRIDE;
    }

    return HAM_IGNORED;
}

public HamHook_Weapon_PrimaryAttack(pWeapon) {
    new pPlayer = get_member(pWeapon, m_pPlayer);

    return @Player_CanUseWeapon(pPlayer) ? HAM_IGNORED : HAM_SUPERCEDE;
}

public HamHook_Weapon_SecondaryAttack(pWeapon) {
    new pPlayer = get_member(pWeapon, m_pPlayer);

    return @Player_CanUseWeapon(pPlayer) ? HAM_IGNORED : HAM_SUPERCEDE;
}

public HamHook_Player_PostThink_Post(pPlayer) {
    if (!PlayerEffect_Get(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    static Float:flGameTime; flGameTime = get_gametime();

    if (g_rgvecPlayerNextDanceThink[pPlayer] <= flGameTime) {
        @Player_DanceThink(pPlayer);
        g_rgvecPlayerNextDanceThink[pPlayer] = flGameTime + DANCE_THINK_RATE;
    }
    
    if (g_rgvecPlayerNextSoundLoop[pPlayer] <= flGameTime) {
        @Player_DanceSoundLoop(pPlayer);
        g_rgvecPlayerNextSoundLoop[pPlayer] = get_gametime() + DANCE_SOUND_DURATION;
    }

    return HAM_HANDLED;
}
