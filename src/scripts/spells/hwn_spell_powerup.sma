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

#define PLUGIN "[Hwn] Power Up Spell"
#define AUTHOR "Hedgehog Fog"

#define JUMP_SPEED 320.0
#define JUMP_DELAY 0.175
#define JUMP_EFFECT_BRIGHTNESS 255
#define JUMP_EFFECT_LIFETIME 5
#define SPEED_BOOST 2.0
#define WEAPON_SPEED_BOOST 1.25

const Float:EffectTime = 10.0;
const EffectRadius = 48;
new const EffectColor[3] = {HWN_COLOR_PRIMARY};

new const g_szSndDetonate[] = "hwn/spells/spell_powerup.wav";
new const g_szSndJump[] = "hwn/spells/spell_powerup_jump_v2.wav";

new g_iTrailModelIndex;

new g_iPlayerSpellEffectFlag = 0;
new Float:g_rgPlayerLastJump[MAX_PLAYERS + 1];
new Float:g_flPlayerEffectEnd[MAX_PLAYERS + 1];

new g_hWofSpell;

public plugin_precache() {
    g_iTrailModelIndex = precache_model("sprites/zbeam2.spr");
    precache_sound(g_szSndDetonate);
    precache_sound(g_szSndJump);

    Hwn_Spell_Register(
        "Power Up",
        (
            Hwn_SpellFlag_Applicable
                | Hwn_SpellFlag_Ability
                | Hwn_SpellFlag_Damage
                | Hwn_SpellFlag_Heal
                | Hwn_SpellFlag_Rare
        ),
        "Cast"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Power Up", "Invoke", "Revoke");
}

public plugin_cfg() {
    server_cmd("sv_maxspeed 9999");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Player_Jump, "HamHook_Player_Jump_Post", .Post = 1);
    RegisterHamPlayer(Ham_Item_PreFrame, "HamHook_Player_ItemPreFrame_Post", .Post = 1);
    RegisterHamPlayer(Ham_TakeDamage, "HamHook_Player_TakeDamage", .Post = 0);
    RegisterHamPlayer(Ham_Killed, "Revoke", .Post = 1);

    for (new i = CSW_NONE + 1; i <= CSW_LAST_WEAPON; ++i) {
        if ((1 << i) & ~(CSW_ALL_GUNS | (1 << CSW_KNIFE))) {
            continue;
        }

        new szWeaponName[32];
        get_weaponname(i, szWeaponName, charsmax(szWeaponName));

        RegisterHam(Ham_Weapon_PrimaryAttack, szWeaponName, "HamHook_Weapon_Attack_Post", .Post = 1);
        RegisterHam(Ham_Weapon_SecondaryAttack, szWeaponName, "HamHook_Weapon_Attack_Post", .Post = 1);
    }
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_disconnected(pPlayer) {
    Revoke(pPlayer);
}

public Round_Fw_NewRound() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        Revoke(pPlayer);
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Weapon_Attack_Post(pEntity) {
    new pPlayer = get_member(pEntity, m_pPlayer);

    if (!is_user_alive(pPlayer)) {
        return HAM_IGNORED;
    }

    if (!GetSpellEffect(pPlayer)) {
        return HAM_IGNORED;
    }

    BoostWeaponShootSpeed(pEntity);

    return HAM_HANDLED;
}

public HamHook_Player_Jump_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return HAM_IGNORED;
    }

    if (!GetSpellEffect(pPlayer)) {
        return HAM_IGNORED;
    }

    if (g_flPlayerEffectEnd[pPlayer] < get_gametime()) {
        return HAM_IGNORED;
    }

    new oldButton = pev(pPlayer, pev_oldbuttons);

    if (~oldButton & IN_JUMP) {
        ProcessPlayerJump(pPlayer);
    }

    return HAM_HANDLED;
}

public HamHook_Player_ItemPreFrame_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return HAM_IGNORED;
    }

    if (!GetSpellEffect(pPlayer)) {
        return HAM_IGNORED;
    }

    BoostPlayerSpeed(pPlayer);

    return HAM_HANDLED;
}

public HamHook_Player_TakeDamage(pPlayer, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (!is_user_alive(pPlayer)) {
        return HAM_IGNORED;
    }

    if (!GetSpellEffect(pPlayer)) {
        return HAM_IGNORED;
    }

    if (~iDamageBits & DMG_FALL) {
        return HAM_IGNORED;
    }

    SetHamParamFloat(4, 0.0);
    return HAM_OVERRIDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    Invoke(pPlayer);

    if (Hwn_Wof_Effect_GetCurrentSpell() != g_hWofSpell) {
        set_task(EffectTime, "Revoke", pPlayer);
        g_flPlayerEffectEnd[pPlayer] = get_gametime() + EffectTime;
    }
}

public Invoke(pPlayer) {
    Revoke(pPlayer);

    SetSpellEffect(pPlayer, true);
    Heal(pPlayer);
    JumpEffect(pPlayer);
    ExecuteHamB(Ham_Item_PreFrame, pPlayer);
    emit_sound(pPlayer, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public Revoke(pPlayer) {
    if (!GetSpellEffect(pPlayer)) {
        return;
    }

    SetSpellEffect(pPlayer, false);
    remove_task(pPlayer);

    if (is_user_connected(pPlayer)) {
        ExecuteHamB(Ham_Item_PreFrame, pPlayer);
    }
}

bool:GetSpellEffect(pPlayer) {
    return !!(g_iPlayerSpellEffectFlag & BIT(pPlayer & 31));
}

SetSpellEffect(pPlayer, bool:bValue) {
    if (bValue) {
        g_iPlayerSpellEffectFlag |= BIT(pPlayer & 31);
    } else {
        g_iPlayerSpellEffectFlag &= ~BIT(pPlayer & 31);
    }
}

ProcessPlayerJump(pPlayer) {
    new iFlags = pev(pPlayer, pev_flags);

    if (~iFlags & FL_ONGROUND) {
        if (get_gametime() - g_rgPlayerLastJump[pPlayer] < JUMP_DELAY) {
            return;
        }

        Jump(pPlayer);
    }

    JumpEffect(pPlayer);
    g_rgPlayerLastJump[pPlayer] = get_gametime();
}

Jump(pPlayer) {
    static Float:flMaxSpeed;
    pev(pPlayer, pev_maxspeed, flMaxSpeed);

    static Float:vecVelocity[3];
    GetMoveVector(pPlayer, vecVelocity);
    xs_vec_mul_scalar(vecVelocity, flMaxSpeed, vecVelocity);
    vecVelocity[2] = JUMP_SPEED;
    
    set_pev(pPlayer, pev_velocity, vecVelocity);
    set_pev(pPlayer, pev_gaitsequence, 6);

    new Float:flTimeRatio = floatclamp(1.0 - ((g_flPlayerEffectEnd[pPlayer] - get_gametime()) / EffectTime), 0.0, 1.0);
    new iPitch = PITCH_NORM + floatround(80 * flTimeRatio);
    emit_sound(pPlayer, CHAN_STATIC, g_szSndJump, VOL_NORM, ATTN_NORM, 0, iPitch);
}

public BoostWeaponShootSpeed(pEntity) {
    new Float:flMultiplier =  1.0 / WEAPON_SPEED_BOOST;

    new Float:flNextPrimaryAttack = get_member(pEntity, m_Weapon_flNextPrimaryAttack);
    new Float:flNextSecondaryAttack = get_member(pEntity, m_Weapon_flNextSecondaryAttack);

    set_member(pEntity, m_Weapon_flNextPrimaryAttack, flNextPrimaryAttack * flMultiplier);
    set_member(pEntity, m_Weapon_flNextSecondaryAttack, flNextSecondaryAttack * flMultiplier);
}

BoostPlayerSpeed(pPlayer) {
    new Float:flMaxSpeed = get_user_maxspeed(pPlayer);
    set_user_maxspeed(pPlayer, flMaxSpeed * SPEED_BOOST);
}

JumpEffect(pPlayer) {
    static Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    static Float:vecMins[3];
    pev(pPlayer, pev_mins, vecMins);

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

GetMoveVector(pPlayer, Float:vecOut[3]) {
    xs_vec_copy(Float:{0.0, 0.0, 0.0}, vecOut);

    new iButton = pev(pPlayer, pev_button);

    static Float:vecAngles[3];
    pev(pPlayer, pev_angles, vecAngles);

    static Float:vecDirectionForward[3];
    angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecDirectionForward);

    static Float:vecDirectionRight[3];
    angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecDirectionRight);

    if (iButton & IN_FORWARD) {
        xs_vec_add(vecOut, vecDirectionForward, vecOut);
    }

    if (iButton & IN_BACK) {
        xs_vec_sub(vecOut, vecDirectionForward, vecOut);
    }
    
    if (iButton & IN_MOVERIGHT) {
        xs_vec_add(vecOut, vecDirectionRight, vecOut);
    }

    if (iButton & IN_MOVELEFT) {
        xs_vec_sub(vecOut, vecDirectionRight, vecOut);
    }

    vecOut[2] = 0.0;

    xs_vec_normalize(vecOut, vecOut);
}

Heal(pPlayer) {
    new Float:flHealth;
    pev(pPlayer, pev_health, flHealth);

    if (flHealth < 100.0) {
        set_pev(pPlayer, pev_health, 100.0);
    }
}
