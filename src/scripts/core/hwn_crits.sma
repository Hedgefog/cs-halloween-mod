#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <hwn>
#include <hwn_utils>

#include <api_custom_entities>

#pragma semicolon 1

#define PLUGIN "[Hwn] Crits"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

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
#define CRIT_STATUS_ICON "dmg_shock"

#define TASKID_SUM_PENALTY 1000
#define TASKID_SUM_HIT_BONUS 2000

new g_playerCritsFlag;
new Float:g_playerCritChance[MAX_PLAYERS + 1] = { 0.0, ... };
new Float:g_playerLastShot[MAX_PLAYERS + 1] = { 0.0, ... };
new Float:g_playerLastHit[MAX_PLAYERS + 1] = { 0.0, ... };
new Float:g_playerLastCrit[MAX_PLAYERS + 1] = { 0.0, ... };

new g_cvarCritsDmgMultiplier;
new g_cvarCritsEffectTrace;
new g_cvarCritsEffectSplash;
new g_cvarCritsEffectFlash;
new g_cvarCritsEffectStatucIcon;
new g_cvarCritsRandom;
new g_cvarCritsRandomChanceInitial;
new g_cvarCritsRandomChanceMax;
new g_cvarCritsRandomChanceBonus;
new g_cvarCritsRandomChancePenalty;
new g_cvarCritsSoundUse;
new g_cvarCritsSoundHit;
new g_cvarCritsSoundShoot;

new g_szSndCritHit[][32] = {
    "hwn/crits/crit_hit1.wav",
    "hwn/crits/crit_hit2.wav",
    "hwn/crits/crit_hit3.wav"
};

new g_szSndCritShot[] = "hwn/crits/crit_shoot.wav";
new g_szSndCritOn[] = "hwn/crits/crit_on.wav";
new g_szSndCritOff[] = "hwn/crits/crit_off.wav";

public plugin_precache()
{
    for (new i = 0; i < sizeof(g_szSndCritHit); ++i) {
        precache_sound(g_szSndCritHit[i]);
    }

    precache_sound(g_szSndCritShot);
    precache_sound(g_szSndCritOn);
    precache_sound(g_szSndCritOff);

    g_cvarCritsDmgMultiplier = register_cvar("hwn_crits_damage_multiplier", "2.2");
    g_cvarCritsEffectTrace = register_cvar("hwn_crits_effect_trace", "1");
    g_cvarCritsEffectSplash = register_cvar("hwn_crits_effect_splash", "1");
    g_cvarCritsEffectFlash = register_cvar("hwn_crits_effect_flash", "1");
    g_cvarCritsEffectStatucIcon = register_cvar("hwn_crits_effect_status_icon", "1");
    g_cvarCritsSoundUse = register_cvar("hwn_crits_sound_use", "1");
    g_cvarCritsSoundHit = register_cvar("hwn_crits_sound_hit", "1");
    g_cvarCritsSoundShoot = register_cvar("hwn_crits_sound_shoot", "1");
    g_cvarCritsRandom = register_cvar("hwn_crits_random", "1");
    g_cvarCritsRandomChanceInitial = register_cvar("hwn_crits_random_chance_initial", "0.0");
    g_cvarCritsRandomChanceMax = register_cvar("hwn_crits_random_chance_max", "12.0");
    g_cvarCritsRandomChanceBonus = register_cvar("hwn_crits_random_chance_bonus", "1.0");
    g_cvarCritsRandomChancePenalty = register_cvar("hwn_crits_random_chance_penalty", "2.0");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TraceAttack, "worldspawn", "OnTraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, "func_wall", "OnTraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, "func_breakable", "OnTraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, "player", "OnTraceAttack", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 0);

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);

    register_concmd("hwn_crits_toggle", "OnClCmd_CritsToggle", ADMIN_CVAR);
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Crits_Get", "Native_GetPlayerCrits");
    register_native("Hwn_Crits_Set", "Native_SetPlayerCrits");
}

/*--------------------------------[ Natives ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
        public client_disconnect(id)
#else
        public client_disconnected(id)
#endif
{
     ResetCrits(id);
}

public bool:Native_GetPlayerCrits(plugin_id, argc)
{
    new id = get_param(1);

    return GetPlayerCrits(id);
}

public Native_SetPlayerCrits(plugin_id, argc)
{
    new id = get_param(1);
    new bool:value = bool:get_param(2);

    SetPlayerCrits(id, value);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnClCmd_CritsToggle(id, level, cid)
{
    if(!cmd_access(id, level, cid, 1)) {
        return PLUGIN_HANDLED;
    }

    new szArgs[4];
    read_args(szArgs, charsmax(szArgs));

    new targetId = szArgs[0] == '^0' ? id : str_to_num(szArgs);
    if (!targetId) {
        return PLUGIN_HANDLED;
    }

    new bool:value = !GetPlayerCrits(targetId);
    SetPlayerCrits(targetId, value);

    log_amx("Set crits for %d to %s", targetId, value ? "true" : "false");

    return PLUGIN_HANDLED;
}

public OnPlayerSpawn(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    ResetCritChance(id);
    UpdateStatusIcon(id);
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (!UTIL_IsPlayer(attacker)) {
        return HAM_IGNORED;
    }

    new Float:fGameTime = get_gametime();
    new bool:isHit = (UTIL_IsPlayer(ent) && !IsTeammate(attacker, ent)) || pev(ent, pev_flags) & FL_MONSTER;

    if (ProcessCrit(attacker, isHit)) {
        new bool:isNewShot = g_playerLastShot[attacker] != get_gametime();
        new Float:fVolume = isNewShot ? VOL_NORM : VOL_NORM * 0.3525;

        if (isNewShot && get_pcvar_num(g_cvarCritsSoundShoot)) {
            emit_sound(attacker, CHAN_STATIC, g_szSndCritShot, fVolume, ATTN_NORM, 0, PITCH_NORM);
        }

        static Float:vViewOrigin[3];
        UTIL_GetViewOrigin(attacker, vViewOrigin);

        static Float:vHitOrigin[3];
        get_tr2(trace, TR_vecEndPos, vHitOrigin);

        CritEffect(vHitOrigin, vViewOrigin, vDirection, isHit);

        if (get_pcvar_num(g_cvarCritsSoundHit)) {
            UTIL_Message_Sound(vHitOrigin, g_szSndCritHit[random(sizeof(g_szSndCritHit))], fVolume, ATTN_NORM, 0, PITCH_NORM);
        }

        g_playerLastCrit[attacker] = fGameTime;

        // apply crit only on hit
        if (isHit) {
            SetHamParamFloat(3, fDamage * get_pcvar_float(g_cvarCritsDmgMultiplier));
            SetHamParamInteger(6, damageBits | DMG_ALWAYSGIB);
        }
    }

    if (isHit) {
        g_playerLastHit[attacker] = fGameTime;
    }

    g_playerLastShot[attacker] = fGameTime;

    return HAM_OVERRIDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:GetPlayerCrits(id)
{
    return !!(g_playerCritsFlag & (1 << (id & 31)));
}

SetPlayerCrits(id, bool:value)
{
    if (is_user_connected(id)) {
        if (GetPlayerCrits(id) != value && get_pcvar_num(g_cvarCritsSoundUse)) {
            client_cmd(id, "spk %s", value ? g_szSndCritOn : g_szSndCritOff);
        }
    }

    if (value) {
        g_playerCritsFlag |= (1 << (id & 31));
    } else {
        g_playerCritsFlag &= ~(1 << (id & 31));
    }

    if (is_user_connected(id)) {
        UpdateStatusIcon(id);
    }
}

ProcessCrit(id, bool:isHit)
{
    if (GetPlayerCrits(id)) {
        return true;
    }

    if (get_pcvar_float(g_cvarCritsRandom) <= 0) {
        return false;
    }

    new Float:fLastShot = g_playerLastShot[id];
    new bool:isNewShot = fLastShot != get_gametime();
    new bool:isCrit = g_playerLastCrit[id] == get_gametime();

    if (isNewShot) { // exclude multiple bullets and wallbangs
        new Float:fCritChance = GetCritChance(id);
        if (fCritChance && fCritChance >= random_float(0.0, 100.0)) {
            ResetCritChance(id);
            isCrit = true;
        }
    }

    if (isHit) {
        if (g_playerLastHit[id] != get_gametime()) { // only new hit
            set_task(0.0, "TaskHitBonus", id + TASKID_SUM_HIT_BONUS);
        }

        remove_task(id + TASKID_SUM_PENALTY); // remove penalty task on hit
    } else {
        if (isNewShot) { // only new shot
            set_task(0.0, "TaskPenalty", id + TASKID_SUM_PENALTY);
        }
    }

    return isCrit;
}

Float:GetCritChance(id)
{
    return g_playerCritChance[id];
}

ResetCritChance(id)
{
    SetCritChance(id, get_pcvar_float(g_cvarCritsRandomChanceInitial));
}

SetCritChance(id, Float:fValue)
{
    new Float:fMaxChance = get_pcvar_float(g_cvarCritsRandomChanceMax);

    if (fValue > fMaxChance) {
        fValue = fMaxChance;
    } else if (fValue < 0.0) {
        fValue = 0.0;
    }

    g_playerCritChance[id] = fValue;
}

ResetCrits(id)
{
    SetPlayerCrits(id, false);
    g_playerCritChance[id] = 0.0;
}

UpdateStatusIcon(id)
{
        new value = any:(get_pcvar_float(g_cvarCritsEffectStatucIcon) > 0) && GetPlayerCrits(id);
        UTIL_Message_StatusIcon(id, value, CRIT_STATUS_ICON, {HWN_COLOR_PRIMARY});
}

CritEffect(const Float:vOrigin[3], const Float:vAttackerOrigin[3], const Float:vDirection[3], bool:isHit)
{
    new color = EFFECT_COLOR_BYTE;

    if (get_pcvar_num(g_cvarCritsEffectTrace) > 0
        && (get_pcvar_num(g_cvarCritsEffectTrace) != 2 || isHit)) {
        TraceEffect(vAttackerOrigin, vOrigin, color);
    }

    if (get_pcvar_num(g_cvarCritsEffectSplash) > 0
        && (get_pcvar_num(g_cvarCritsEffectSplash) != 2 || isHit)) {
        SplashEffect(vOrigin, vDirection, color);
    }

    if (get_pcvar_num(g_cvarCritsEffectFlash) > 0
        && (get_pcvar_num(g_cvarCritsEffectFlash) != 2 || isHit)) {
        FlashEffect(vOrigin);
    }
}

TraceEffect(const Float:vStart[3], const Float:vEnd[3], color)
{
    static Float:vDirection[3];
    xs_vec_sub(vEnd, vStart, vDirection);

    UTIL_Message_UserTracer(vStart, vDirection, CRIT_EFFECT_TRACE_LIFETIME, color, CRIT_EFFECT_TRACE_LENGTH);
}

SplashEffect(const Float:vStart[3], const Float:vDirection[3], color)
{
    static Float:vSplashDirection[3];
    xs_vec_normalize(vDirection, vSplashDirection);
    xs_vec_mul_scalar(vDirection, -CRIT_EFFECT_SPLASH_LENGTH, vSplashDirection);

    UTIL_Message_StreakSplash(vStart, vSplashDirection, color, CRIT_EFFECT_SPLASH_COUNT, CRIT_EFFECT_SPLASH_SPEED, CRIT_EFFECT_SPLASH_SPEEDNOISE);
}

FlashEffect(const Float:vOrigin[3])
{
    UTIL_Message_Dlight(vOrigin, CRIT_EFFECT_FLASH_RADIUS, {HWN_COLOR_PRIMARY}, CRIT_EFFECT_FLASH_LIFETIME, CRIT_EFFECT_FLASH_DECAYRATE);
}

bool:IsTeammate(id, ent)
{
    return UTIL_IsPlayer(id)
        && UTIL_IsPlayer(ent)
        && UTIL_GetPlayerTeam(id) == UTIL_GetPlayerTeam(ent);
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskHitBonus(taskID)
{
    new id = taskID - TASKID_SUM_HIT_BONUS;

    new Float:fCitChance = GetCritChance(id);
    new Float:fHitBonus = get_pcvar_float(g_cvarCritsRandomChanceBonus);

    SetCritChance(id, fCitChance + fHitBonus);
}

public TaskPenalty(taskID)
{
    new id = taskID - TASKID_SUM_PENALTY;

    new Float:fCitChance = GetCritChance(id);
    new Float:fMissPenalty = get_pcvar_float(g_cvarCritsRandomChancePenalty);

    SetCritChance(id, fCitChance - fMissPenalty);
}
