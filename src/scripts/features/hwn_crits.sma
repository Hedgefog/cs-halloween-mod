#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <reapi>

#include <hwn>
#include <hwn_utils>

#include <api_custom_entities>

#pragma semicolon 1

#define PLUGIN "[Hwn] Crits"
#define AUTHOR "Hedgehog Fog"

#define CRIT_EFFECT_SPLASH_LENGTH 128.0
#define CRIT_EFFECT_SPLASH_SPEEDNOISE 255
#define CRIT_EFFECT_SPLASH_COUNT 18
#define CRIT_EFFECT_SPLASH_SPEED 3
#define CRIT_EFFECT_TRACE_LIFETIME 1
#define CRIT_EFFECT_TRACE_LENGTH 32
#define CRIT_EFFECT_FLASH_RADIUS 8
#define CRIT_EFFECT_FLASH_LIFETIME 1
#define CRIT_EFFECT_FLASH_DECAYRATE 80

#define EFFECT_COLOR_BYTE HWN_COLOR_PRIMARY_PALETTE2

#define TASKID_SUM_PENALTY 1000
#define TASKID_SUM_HIT_BONUS 2000

new g_rgiPlayerCritsFlag;
new Float:g_rgflPlayerCritChance[MAX_PLAYERS + 1];
new Float:g_rgflPlayerLastShot[MAX_PLAYERS + 1];
new Float:g_rgflPlayerLastHit[MAX_PLAYERS + 1];
new Float:g_rgflPlayerLastCrit[MAX_PLAYERS + 1];

new g_pCvarCritsDmgMultiplier;
new g_pCvarCritsEffectTrace;
new g_pCvarCritsEffectSplash;
new g_pCvarCritsEffectFlash;
new g_pCvarCritsRandom;
new g_pCvarCritsRandomChanceInitial;
new g_pCvarCritsRandomChanceMax;
new g_pCvarCritsRandomChanceBonus;
new g_pCvarCritsRandomChancePenalty;
new g_pCvarCritsSoundUse;
new g_pCvarCritsSoundHit;
new g_pCvarCritsSoundShoot;

new g_szSndCritHit[][32] = {
    "hwn/crits/crit_hit1.wav",
    "hwn/crits/crit_hit2.wav",
    "hwn/crits/crit_hit3.wav"
};

new g_szSndCritShot[] = "hwn/crits/crit_shoot.wav";
new g_szSndCritOn[] = "hwn/crits/crit_on.wav";
new g_szSndCritOff[] = "hwn/crits/crit_off.wav";

public plugin_precache() {
    for (new i = 0; i < sizeof(g_szSndCritHit); ++i) {
        precache_sound(g_szSndCritHit[i]);
    }

    precache_sound(g_szSndCritShot);
    precache_sound(g_szSndCritOn);
    precache_sound(g_szSndCritOff);

    g_pCvarCritsDmgMultiplier = register_cvar("hwn_crits_damage_multiplier", "2.2");
    g_pCvarCritsEffectTrace = register_cvar("hwn_crits_effect_trace", "1");
    g_pCvarCritsEffectSplash = register_cvar("hwn_crits_effect_splash", "1");
    g_pCvarCritsEffectFlash = register_cvar("hwn_crits_effect_flash", "1");
    g_pCvarCritsSoundUse = register_cvar("hwn_crits_sound_use", "1");
    g_pCvarCritsSoundHit = register_cvar("hwn_crits_sound_hit", "1");
    g_pCvarCritsSoundShoot = register_cvar("hwn_crits_sound_shoot", "1");
    g_pCvarCritsRandom = register_cvar("hwn_crits_random", "1");
    g_pCvarCritsRandomChanceInitial = register_cvar("hwn_crits_random_chance_initial", "0.0");
    g_pCvarCritsRandomChanceMax = register_cvar("hwn_crits_random_chance_max", "12.0");
    g_pCvarCritsRandomChanceBonus = register_cvar("hwn_crits_random_chance_bonus", "1.0");
    g_pCvarCritsRandomChancePenalty = register_cvar("hwn_crits_random_chance_penalty", "2.0");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TraceAttack, "worldspawn", "HamHook_TraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, "func_wall", "HamHook_TraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, "func_breakable", "HamHook_TraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_TraceAttack", .Post = 0);
    RegisterHamPlayer(Ham_TraceAttack, "HamHook_TraceAttack", .Post = 0);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

    register_concmd("hwn_crits_toggle", "Command_CritsToggle", ADMIN_CVAR);
}

public plugin_natives() {
    register_library("hwn_crits");
    register_native("Hwn_Crits_Get", "Native_GetPlayerCrits");
    register_native("Hwn_Crits_Set", "Native_SetPlayerCrits");
}

/*--------------------------------[ Natives ]--------------------------------*/

public client_disconnected(pPlayer) {
     ResetCrits(pPlayer);
}

public bool:Native_GetPlayerCrits(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    return GetPlayerCrits(pPlayer);
}

public Native_SetPlayerCrits(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new bool:bValue = bool:get_param(2);

    SetPlayerCrits(pPlayer, bValue);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Command_CritsToggle(pPlayer, iLevel, iCId) {
    if (!cmd_access(pPlayer, iLevel, iCId, 1)) {
        return PLUGIN_HANDLED;
    }

    new szArgs[4];
    read_args(szArgs, charsmax(szArgs));

    new pTarget = equal(szArgs, NULL_STRING) ? pPlayer : str_to_num(szArgs);
    if (!pTarget) {
        return PLUGIN_HANDLED;
    }

    new bool:bValue = !GetPlayerCrits(pTarget);
    SetPlayerCrits(pTarget, bValue);

    log_amx("Set crits for %d to %s", pTarget, bValue ? "true" : "false");

    return PLUGIN_HANDLED;
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    ResetCritChance(pPlayer);
}

public HamHook_TraceAttack(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (!IS_PLAYER(pAttacker)) {
        return HAM_IGNORED;
    }

    new Float:flGameTime = get_gametime();
    new bool:bIsHit = (IS_PLAYER(pEntity) && rg_is_player_can_takedamage(pEntity, pAttacker)) || pev(pEntity, pev_flags) & FL_MONSTER;

    if (ProcessCrit(pAttacker, bIsHit)) {
        new bool:bIsNewShot = g_rgflPlayerLastShot[pAttacker] != get_gametime();
        new Float:flVolume = bIsNewShot ? VOL_NORM : VOL_NORM * 0.3525;

        if (bIsNewShot && get_pcvar_num(g_pCvarCritsSoundShoot)) {
            emit_sound(pAttacker, CHAN_STATIC, g_szSndCritShot, flVolume, ATTN_NORM, 0, PITCH_NORM);
        }

        static Float:vecViewOrigin[3];
        UTIL_GetViewOrigin(pAttacker, vecViewOrigin);

        static Float:vecHitOrigin[3];
        get_tr2(pTrace, TR_vecEndPos, vecHitOrigin);

        CritEffect(vecHitOrigin, vecViewOrigin, vecDirection, bIsHit);

        if (get_pcvar_num(g_pCvarCritsSoundHit)) {
            UTIL_Message_Sound(vecHitOrigin, g_szSndCritHit[random(sizeof(g_szSndCritHit))], flVolume, ATTN_NORM, 0, PITCH_NORM);
        }

        g_rgflPlayerLastCrit[pAttacker] = flGameTime;

        // apply crit only on hit
        if (bIsHit) {
            SetHamParamFloat(3, flDamage * get_pcvar_float(g_pCvarCritsDmgMultiplier));
            SetHamParamInteger(6, iDamageBits | DMG_ALWAYSGIB);
        }
    }

    if (bIsHit) {
        g_rgflPlayerLastHit[pAttacker] = flGameTime;
    }

    g_rgflPlayerLastShot[pAttacker] = flGameTime;

    return HAM_OVERRIDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:GetPlayerCrits(pPlayer) {
    return !!(g_rgiPlayerCritsFlag & BIT(pPlayer & 31));
}

SetPlayerCrits(pPlayer, bool:bValue) {
    if (is_user_connected(pPlayer)) {
        if (GetPlayerCrits(pPlayer) != bValue && get_pcvar_num(g_pCvarCritsSoundUse)) {
            client_cmd(pPlayer, "spk %s", bValue ? g_szSndCritOn : g_szSndCritOff);
        }
    }

    if (bValue) {
        g_rgiPlayerCritsFlag |= BIT(pPlayer & 31);
    } else {
        g_rgiPlayerCritsFlag &= ~BIT(pPlayer & 31);
    }
}

ProcessCrit(pPlayer, bool:bIsHit) {
    if (GetPlayerCrits(pPlayer)) {
        return true;
    }

    if (get_pcvar_float(g_pCvarCritsRandom) <= 0) {
        return false;
    }

    new Float:flLastShot = g_rgflPlayerLastShot[pPlayer];
    new bool:bIsNewShot = flLastShot != get_gametime();
    new bool:bIsCrit = g_rgflPlayerLastCrit[pPlayer] == get_gametime();

    if (bIsNewShot) { // exclude multiple bullets and wallbangs
        new Float:flCritChance = GetCritChance(pPlayer);
        if (flCritChance && flCritChance >= random_float(0.0, 100.0)) {
            ResetCritChance(pPlayer);
            bIsCrit = true;
        }
    }

    if (bIsHit) {
        if (g_rgflPlayerLastHit[pPlayer] != get_gametime()) { // only new hit
            set_task(0.0, "Task_HitBonus", pPlayer + TASKID_SUM_HIT_BONUS);
        }

        remove_task(pPlayer + TASKID_SUM_PENALTY); // remove penalty task on hit
    } else {
        if (bIsNewShot) { // only new shot
            set_task(0.0, "Task_Penalty", pPlayer + TASKID_SUM_PENALTY);
        }
    }

    return bIsCrit;
}

Float:GetCritChance(pPlayer) {
    return g_rgflPlayerCritChance[pPlayer];
}

ResetCritChance(pPlayer) {
    SetCritChance(pPlayer, get_pcvar_float(g_pCvarCritsRandomChanceInitial));
}

SetCritChance(pPlayer, Float:flValue) {
    new Float:flMaxChance = get_pcvar_float(g_pCvarCritsRandomChanceMax);

    if (flValue > flMaxChance) {
        flValue = flMaxChance;
    } else if (flValue < 0.0) {
        flValue = 0.0;
    }

    g_rgflPlayerCritChance[pPlayer] = flValue;
}

ResetCrits(pPlayer) {
    SetPlayerCrits(pPlayer, false);
    g_rgflPlayerCritChance[pPlayer] = 0.0;
}

CritEffect(const Float:vecOrigin[3], const Float:vecAttackerOrigin[3], const Float:vecDirection[3], bool:bIsHit) {
    new iColor = EFFECT_COLOR_BYTE;

    if (get_pcvar_num(g_pCvarCritsEffectTrace) > 0
        && (get_pcvar_num(g_pCvarCritsEffectTrace) != 2 || bIsHit)) {
        TraceEffect(vecAttackerOrigin, vecOrigin, iColor);
    }

    if (get_pcvar_num(g_pCvarCritsEffectSplash) > 0
        && (get_pcvar_num(g_pCvarCritsEffectSplash) != 2 || bIsHit)) {
        SplashEffect(vecOrigin, vecDirection, iColor);
    }

    if (get_pcvar_num(g_pCvarCritsEffectFlash) > 0
        && (get_pcvar_num(g_pCvarCritsEffectFlash) != 2 || bIsHit)) {
        FlashEffect(vecOrigin);
    }
}

TraceEffect(const Float:vecStart[3], const Float:vecEnd[3], iColor) {
    static Float:vecDirection[3];
    xs_vec_sub(vecEnd, vecStart, vecDirection);

    UTIL_Message_UserTracer(vecStart, vecDirection, CRIT_EFFECT_TRACE_LIFETIME, iColor, CRIT_EFFECT_TRACE_LENGTH);
}

SplashEffect(const Float:vecStart[3], const Float:vecDirection[3], iColor) {
    static Float:vecSplashDirection[3];
    xs_vec_normalize(vecDirection, vecSplashDirection);
    xs_vec_mul_scalar(vecDirection, -CRIT_EFFECT_SPLASH_LENGTH, vecSplashDirection);

    UTIL_Message_StreakSplash(vecStart, vecSplashDirection, iColor, CRIT_EFFECT_SPLASH_COUNT, CRIT_EFFECT_SPLASH_SPEED, CRIT_EFFECT_SPLASH_SPEEDNOISE);
}

FlashEffect(const Float:vecOrigin[3]) {
    UTIL_Message_Dlight(vecOrigin, CRIT_EFFECT_FLASH_RADIUS, {HWN_COLOR_PRIMARY}, CRIT_EFFECT_FLASH_LIFETIME, CRIT_EFFECT_FLASH_DECAYRATE);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_HitBonus(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_HIT_BONUS;

    new Float:flCitChance = GetCritChance(pPlayer);
    new Float:flHitBonus = get_pcvar_float(g_pCvarCritsRandomChanceBonus);

    SetCritChance(pPlayer, flCitChance + flHitBonus);
}

public Task_Penalty(iTaskId) {
    new pPlayer = iTaskId - TASKID_SUM_PENALTY;

    new Float:flCitChance = GetCritChance(pPlayer);
    new Float:flMissPenalty = get_pcvar_float(g_pCvarCritsRandomChancePenalty);

    SetCritChance(pPlayer, flCitChance - flMissPenalty);
}
