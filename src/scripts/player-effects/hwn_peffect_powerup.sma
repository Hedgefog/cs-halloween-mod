#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <xs>
#include <reapi>

#include <api_rounds>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Power Up Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "powerup"

#define JUMP_SPEED 320.0
#define JUMP_DELAY 0.175
#define JUMP_EFFECT_BRIGHTNESS 255
#define JUMP_EFFECT_LIFETIME 5

#define SPEED_BOOST 2.0
#define ATTACK_SPEED_BOOST 1.25

const EffectRadius = 48;
new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndDetonate[] = "hwn/spells/spell_powerup.wav";
new const g_szSndJump[] = "hwn/spells/spell_powerup_jump_v2.wav";

new g_iTrailModelIndex;

new Float:g_rgPlayerLastJump[MAX_PLAYERS + 1];

public plugin_precache() {
    g_iTrailModelIndex = precache_model("sprites/zbeam2.spr");
    precache_sound(g_szSndDetonate);
    precache_sound(g_szSndJump);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "stopwatch", EffectColor);

    RegisterHamPlayer(Ham_Player_Jump, "HamHook_Player_Jump_Post", .Post = 1);
    RegisterHamPlayer(Ham_Item_PreFrame, "HamHook_Player_ItemPreFrame_Post", .Post = 1);
    RegisterHamPlayer(Ham_TakeDamage, "HamHook_Player_TakeDamage", .Post = 0);

    for (new i = CSW_NONE + 1; i <= CSW_LAST_WEAPON; ++i) {
        if ((1 << i) & ~(CSW_ALL_GUNS | (1 << CSW_KNIFE))) continue;

        new szWeaponName[32];
        get_weaponname(i, szWeaponName, charsmax(szWeaponName));

        RegisterHam(Ham_Weapon_PrimaryAttack, szWeaponName, "HamHook_Weapon_Attack_Post", .Post = 1);
        RegisterHam(Ham_Weapon_SecondaryAttack, szWeaponName, "HamHook_Weapon_Attack_Post", .Post = 1);
    }
}

public plugin_cfg() {
    server_cmd("sv_maxspeed 9999");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Weapon_Attack_Post(pEntity) {
    new pPlayer = get_member(pEntity, m_pPlayer);

    if (!is_user_alive(pPlayer)) return HAM_IGNORED;
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    @Weapon_BoostShootSpeed(pEntity);

    return HAM_HANDLED;
}

public HamHook_Player_Jump_Post(pPlayer) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    @Player_ProcessJump(pPlayer);

    return HAM_HANDLED;
}

public HamHook_Player_ItemPreFrame_Post(pPlayer) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    @Player_BoostSpeed(pPlayer);

    return HAM_HANDLED;
}

public HamHook_Player_TakeDamage(pPlayer, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (!Hwn_Player_GetEffect(pPlayer, EFFECT_ID)) return HAM_IGNORED;

    if (~iDamageBits & DMG_FALL) return HAM_IGNORED;

    SetHamParamFloat(4, 0.0);

    return HAM_OVERRIDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

@Player_EffectInvoke(this) {
    @Player_Heal(this);
    @Player_JumpEffect(this);
    ExecuteHamB(Ham_Item_PreFrame, this);
    emit_sound(this, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Player_EffectRevoke(this) {
    if (!is_user_connected(this)) return;

    ExecuteHamB(Ham_Item_PreFrame, this);
}

@Player_ProcessJump(this) {
    new iOldButton = pev(this, pev_oldbuttons);
    if (iOldButton & IN_JUMP) return;

    new iFlags = pev(this, pev_flags);
    if (~iFlags & FL_ONGROUND) {
        if (get_gametime() - g_rgPlayerLastJump[this] < JUMP_DELAY) {
            return;
        }

        @Player_Jump(this);
    }

    @Player_JumpEffect(this);
    g_rgPlayerLastJump[this] = get_gametime();
}

@Player_Jump(this) {
    static Float:flMaxSpeed;
    pev(this, pev_maxspeed, flMaxSpeed);

    static Float:vecVelocity[3];
    GetMoveVector(this, vecVelocity);
    xs_vec_mul_scalar(vecVelocity, flMaxSpeed, vecVelocity);
    vecVelocity[2] = JUMP_SPEED;
    
    set_pev(this, pev_velocity, vecVelocity);
    set_pev(this, pev_gaitsequence, 6);

    new Float:flDuration = Hwn_Player_GetEffectDuration(this, EFFECT_ID);
    new Float:flTimeLeft = Hwn_Player_GetEffectEndtime(this, EFFECT_ID) - get_gametime();
    new Float:flTimeRatio = floatclamp(1.0 - (flTimeLeft / flDuration), 0.0, 1.0);
    new iPitch = PITCH_NORM + floatround(80 * flTimeRatio);
    emit_sound(this, CHAN_STATIC, g_szSndJump, VOL_NORM, ATTN_NORM, 0, iPitch);
}

@Player_Heal(this) {
    new Float:flHealth; pev(this, pev_health, flHealth);
    if (flHealth < 100.0) {
        set_pev(this, pev_health, 100.0);
    }
}

@Player_BoostSpeed(this) {
    new Float:flMaxSpeed = get_user_maxspeed(this);
    set_user_maxspeed(this, flMaxSpeed * SPEED_BOOST);
}

@Player_JumpEffect(this) {
    static Float:vecMins[3];
    pev(this, pev_mins, vecMins);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += vecMins[2] + 1.0;

    UTIL_Message_BeamDisk(
        vecOrigin,
        float(EffectRadius) * (10 / JUMP_EFFECT_LIFETIME),
        .iModelIndex = g_iTrailModelIndex,
        .iColor = EffectColor,
        .iBrightness = JUMP_EFFECT_BRIGHTNESS,
        .iSpeed = 0,
        .iNoise = 0,
        .iLifeTime = JUMP_EFFECT_LIFETIME,
        .iWidth = 0
    );
}

@Weapon_BoostShootSpeed(this) {
    static Float:flMultiplier; flMultiplier =  1.0 / ATTACK_SPEED_BOOST;

    static Float:flNextPrimaryAttack; flNextPrimaryAttack = get_member(this, m_Weapon_flNextPrimaryAttack);
    set_member(this, m_Weapon_flNextPrimaryAttack, flNextPrimaryAttack * flMultiplier);

    static Float:flNextSecondaryAttack; flNextSecondaryAttack = get_member(this, m_Weapon_flNextSecondaryAttack);
    set_member(this, m_Weapon_flNextSecondaryAttack, flNextSecondaryAttack * flMultiplier);
}

/*--------------------------------[ Functions ]--------------------------------*/

GetMoveVector(pPlayer, Float:vecOut[3]) {
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecOut);

    static Float:vecAngles[3]; pev(pPlayer, pev_angles, vecAngles);
    static Float:vecDirectionForward[3]; angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecDirectionForward);
    static Float:vecDirectionRight[3]; angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecDirectionRight);

    static iButton; iButton = pev(pPlayer, pev_button);

    if (iButton & IN_FORWARD) xs_vec_add(vecOut, vecDirectionForward, vecOut);
    if (iButton & IN_BACK) xs_vec_sub(vecOut, vecDirectionForward, vecOut);
    if (iButton & IN_MOVERIGHT) xs_vec_add(vecOut, vecDirectionRight, vecOut);
    if (iButton & IN_MOVELEFT) xs_vec_sub(vecOut, vecDirectionRight, vecOut);

    vecOut[2] = 0.0;

    xs_vec_normalize(vecOut, vecOut);
}
