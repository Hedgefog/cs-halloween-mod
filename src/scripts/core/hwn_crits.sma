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

new g_flagPlayerCrits;
new Array:g_playerCritChance;
new Array:g_playerLastShot;
new Array:g_playerLastHit;
new Array:g_playerLastCrit;

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

new g_maxPlayers;

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

    g_maxPlayers = get_maxplayers();

    g_playerCritChance = ArrayCreate(1, g_maxPlayers+1);
    g_playerLastShot = ArrayCreate(1, g_maxPlayers+1);
    g_playerLastHit = ArrayCreate(1, g_maxPlayers+1);
    g_playerLastCrit = ArrayCreate(1, g_maxPlayers+1);

    for (new id = 0; id <= g_maxPlayers; ++id) {
        ArrayPushCell(g_playerCritChance, 0);
        ArrayPushCell(g_playerLastShot, 0);
        ArrayPushCell(g_playerLastHit, 0);
        ArrayPushCell(g_playerLastCrit, 0);
    }
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Crits_Get", "Native_GetPlayerCrits");
    register_native("Hwn_Crits_Set", "Native_SetPlayerCrits");
}

public plugin_end()
{
    ArrayDestroy(g_playerCritChance);
    ArrayDestroy(g_playerLastShot);
    ArrayDestroy(g_playerLastHit);
    ArrayDestroy(g_playerLastCrit);
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

    static szArgs[4];
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
        if (get_pcvar_num(g_cvarCritsSoundShoot)) {
            emit_sound(attacker, CHAN_BODY, g_szSndCritShot, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }

        static Float:vAttackerOrigin[3];
        pev(attacker, pev_origin, vAttackerOrigin);

        static Float:vHitOrigin[3];
        get_tr2(trace, TR_vecEndPos, vHitOrigin);

        CritEffect(vHitOrigin, vAttackerOrigin, vDirection);

        if (get_pcvar_num(g_cvarCritsSoundHit)) {
            UTIL_Message_Sound(vHitOrigin, g_szSndCritHit[random(sizeof(g_szSndCritHit))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        }

        ArraySetCell(g_playerLastCrit, attacker, fGameTime);

        SetHamParamFloat(3, fDamage * get_pcvar_float(g_cvarCritsDmgMultiplier));
        SetHamParamInteger(6, damageBits | DMG_ALWAYSGIB);
    }

    if (isHit) {
        ArraySetCell(g_playerLastHit, attacker, fGameTime);
    }

    ArraySetCell(g_playerLastShot, attacker, fGameTime);

    return HAM_OVERRIDE;
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:GetPlayerCrits(id)
{
    return !!(g_flagPlayerCrits & (1 << (id & 31)));
}

SetPlayerCrits(id, bool:value)
{
    if (is_user_connected(id)) {
        if (GetPlayerCrits(id) != value && get_pcvar_num(g_cvarCritsSoundUse)) {
            client_cmd(id, "spk %s", value ? g_szSndCritOn : g_szSndCritOff);
        }
    }

    if (value) {
        g_flagPlayerCrits |= (1 << (id & 31));
    } else {
        g_flagPlayerCrits &= ~(1 << (id & 31));
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

    new Float:fLastShot = ArrayGetCell(g_playerLastShot, id);
    new bool:isNewShot = fLastShot != get_gametime();
    new bool:isCrit = ArrayGetCell(g_playerLastCrit, id) == get_gametime();

    if (isNewShot) { // exclude multiple bullets and wallbangs
        new Float:fCritChance = GetCritChance(id);
        if (fCritChance && fCritChance >= random_float(0.0, 100.0)) {
            ResetCritChance(id);
            isCrit = true;
        }
    }

    if (isHit) {
        if (ArrayGetCell(g_playerLastHit, id) != get_gametime()) { // only new hit
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
    return ArrayGetCell(g_playerCritChance, id);
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

    ArraySetCell(g_playerCritChance, id, fValue);
}

ResetCrits(id)
{
    SetPlayerCrits(id, false);
    ArraySetCell(g_playerCritChance, id, 0);
}

UpdateStatusIcon(id)
{
        new value = any:(get_pcvar_float(g_cvarCritsEffectStatucIcon) > 0) && GetPlayerCrits(id);
        UTIL_Message_StatusIcon(id, value, CRIT_STATUS_ICON, {HWN_COLOR_PRIMARY});
}

CritEffect(const Float:vOrigin[3], const Float:vAttackerOrigin[3], const Float:vDirection[3])
{
    new color = EFFECT_COLOR_BYTE;

    if (get_pcvar_float(g_cvarCritsEffectTrace) > 0) {
        TraceEffect(vAttackerOrigin, vOrigin, color);
    }

    if (get_pcvar_float(g_cvarCritsEffectSplash) > 0) {
        SplashEffect(vOrigin, vDirection, color);
    }

    if (get_pcvar_float(g_cvarCritsEffectFlash) > 0) {
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
