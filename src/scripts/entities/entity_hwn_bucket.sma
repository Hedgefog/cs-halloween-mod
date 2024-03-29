#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_rounds>
#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Bucket"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_BOIL_SOUND 1000
#define TASKID_SUM_REMOVE_LID 2000

#define RANGE 256.0

#define ACTION_POP_DURATION 0.33
#define ACTION_BIG_POP_DURATION 0.365
#define ACTION_BIG_POP_FRAMERATE 0.5

#define EFFECT_MAGIC_SPLASH_PARTICLE_COUNT 32
#define EFFECT_MAGIC_SPLASH_PARTICLE_LIFETIME 1
#define EFFECT_MAGIC_SPLASH_PARTICLE_SCALE 1
#define EFFECT_MAGIC_SPLASH_PARTICLE_SPEED 16
#define EFFECT_MAGIC_SPLASH_PARTICLE_NOISE 32
#define EFFECT_SPELL_DROPS_SCALE 15
#define EFFECT_SPELL_DROPS_COLOR 242
#define EFFECT_WAVE_RADIUS RANGE - 1.0
#define EFFECT_WAVE_LIFETIME 5
#define EFFECT_WAVE_WIDTH 32
#define EFFECT_WAVE_BRIGHTNESS 100
#define EFFECT_WAVE_DISK_BRIGHTNESS 60
#define EFFECT_SPLASH_LIFETIME 10
#define EFFECT_SPLASH_ALPHA 50

#define ENTITY_NAME "hwn_bucket"
#define LIQUID_ENTITY_NAME "hwn_bucket_liquid"

#define FLASH_RADIUS 32
#define FLASH_LIFETIME 10
#define FLASH_DECAY_RATE 28
#define BOIL_SOUND_DURATION 2.2

enum _:Sequence
{
    Sequence_Idle = 0,
    Sequence_Bubbling,
    Sequence_Pop,
    Sequence_BigPop
};

enum Team
{
    Team_Undefined = 0,
    Team_Red,
    Team_Blue,
    Team_Spectators
};

new Float:g_vTeamColor[Team][3] = {
    {HWN_COLOR_GREEN_DARK_F},
    {HWN_COLOR_RED_F},
    {HWN_COLOR_BLUE_F},
    {255.0, 255.0, 255.0}
};

new Float:g_fNextCollectTime[33];

new g_sprBlood;

new const g_szSndBoil[] = "hwn/misc/cauldron_boil.wav";
new const g_szSndPointCollected[] = "hwn/misc/collected.wav";

new const g_szSndHit[][] =
{
    "debris/metal4.wav",
    "debris/metal6.wav"
};

new g_sprSparkle;
new g_sprPotionSplash;
new g_sprPotionBeam;

new g_cvarBucketHealth;
new g_cvarBucketCollectFlash;
new g_cvarBucketBonusHealth;
new g_cvarBucketBonusArmor;
new g_cvarBucketBonusAmmo;
new g_cvarBucketBonusChance;

new g_ceHandler;
new Float:g_fThinkDelay;
new Array:g_buckets;
new bool:g_roundStarted = false;
new g_maxPlayers;

public plugin_precache()
{
    g_sprBlood = precache_model("sprites/blood.spr");
    g_sprSparkle = precache_model("sprites/exit1.spr");
    g_sprPotionSplash = precache_model("sprites/bm1.spr");
    g_sprPotionBeam = precache_model("sprites/streak.spr");

    precache_sound(g_szSndBoil);
    precache_sound(g_szSndPointCollected);

    for (new i = 0; i < sizeof(g_szSndHit); ++i) {
        precache_sound(g_szSndHit[i]);
    }

    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/props/cauldron.mdl"),
        .vMins = Float:{-28.0, -28.0, 0.0},
        .vMaxs = Float:{28.0, 28.0, 56.0},
        .preset = CEPreset_Prop
    );

    CE_Register(
        .szName = LIQUID_ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/props/cauldron_liquid.mdl"),
        .vMins = Float:{-28.0, -28.0, 0.0},
        .vMaxs = Float:{28.0, 28.0, 56.0},
        .preset = CEPreset_Prop
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Spawn, LIQUID_ENTITY_NAME, "OnLiquidSpawn");

    g_cvarBucketHealth = register_cvar("hwn_bucket_health", "300");
    g_cvarBucketCollectFlash = register_cvar("hwn_bucket_collect_flash", "1");
    g_cvarBucketBonusHealth = register_cvar("hwn_bucket_bonus_health", "10");
    g_cvarBucketBonusArmor = register_cvar("hwn_bucket_bonus_armor", "10");
    g_cvarBucketBonusAmmo = register_cvar("hwn_bucket_bonus_ammo", "1");
    g_cvarBucketBonusChance = register_cvar("hwn_bucket_bonus_chance", "5");

    g_buckets = ArrayCreate(1, 2);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTakeDamagePre", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttackPre", .Post = 0);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTakeDamage", .Post = 1);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);

    g_maxPlayers = get_maxplayers();
}

public plugin_end()
{
    ArrayDestroy(g_buckets);
}

/*------------[ Forward ]------------*/

public Hwn_Fw_ConfigLoaded()
{
    g_fThinkDelay = UTIL_FpsToDelay(get_cvar_num("hwn_npc_fps"));
}

public Round_Fw_RoundStart()
{
    g_roundStarted = true;
}

public Round_Fw_RoundEnd()
{
    g_roundStarted = false;
}

public Hwn_Collector_Fw_WinnerTeam(team)
{
    new count = ArraySize(g_buckets);
    for (new i = 0; i < count; ++i) {
        new ent = ArrayGetCell(g_buckets, i);
        new bucketTeam = pev(ent, pev_team);

        if (bucketTeam && bucketTeam != team) {
            continue;
        }

        new Float:fDuration = ACTION_BIG_POP_DURATION * (1.0 / ACTION_BIG_POP_FRAMERATE);
        PlayActionSequence(ent, Sequence_BigPop, fDuration);
        set_pev(ent, pev_framerate, ACTION_BIG_POP_FRAMERATE);

        PotionExplodeEffect(ent);
        FlashEffect(ent);
        WaveEffect(ent);

        set_task(fDuration, "TaskRemoveLid", ent + TASKID_SUM_REMOVE_LID);
    }
}

/*------------[ Hooks ]------------*/

public OnSpawn(ent)
{
    new team = pev(ent, pev_team);

    set_pev(ent, pev_solid, SOLID_BBOX);
    set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP);
    set_pev(ent, pev_takedamage, DAMAGE_AIM);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 0.0);
    set_pev(ent, pev_rendercolor, g_vTeamColor[Team:team]);
    set_pev(ent, pev_health, float(get_pcvar_num(g_cvarBucketHealth)));
    set_pev(ent, pev_body, 0);
    set_pev(ent, pev_iuser4, 0);

    engfunc(EngFunc_DropToFloor, ent);

    if (!pev(ent, pev_iuser1)) {
        new liquidEnt = CE_Create("hwn_bucket_liquid", Float:{0.0, 0.0, 0.0}, false);
        set_pev(liquidEnt, pev_owner, ent);
        dllfunc(DLLFunc_Spawn, liquidEnt);

        set_pev(ent, pev_iuser1, liquidEnt);
    }

    ArrayPushCell(g_buckets, ent);

    ClearTasks(ent);

    set_task(g_fThinkDelay, "TaskThink", ent, _, _, "b");
    set_task(BOIL_SOUND_DURATION, "TaskBoilSound", ent + TASKID_SUM_BOIL_SOUND, _, _, "b");
}

public OnKill(ent)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    static Float:fHealth;
    pev(ent, pev_health, fHealth);

    new extractCount = 1;
    if (fHealth < 0) {
        extractCount += -floatround(fHealth)/get_pcvar_num(g_cvarBucketHealth);
    }

    set_pev(ent, pev_health, float(get_pcvar_num(g_cvarBucketHealth)));
    ExtractPoints(ent, extractCount);

    return HAM_HANDLED;
}

public OnRemove(ent)
{
    new liquidEnt = pev(ent, pev_iuser1);
    CE_Remove(liquidEnt);

    ClearTasks(ent);
}

public OnLiquidSpawn(ent)
{
    new owner = pev(ent, pev_owner);

    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_rendermode, kRenderTransAdd);
    set_pev(ent, pev_renderamt, 255.0);

    new Float:vOrigin[3];
    pev(owner, pev_origin, vOrigin);
    engfunc(EngFunc_SetOrigin, ent, vOrigin);
}

public OnTraceAttackPre(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    static Float:vStart[3];
    UTIL_GetViewOrigin(attacker, vStart);

    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);

    if (!UTIL_IsPointVisible(vStart, vEnd, ent)) {
        return HAM_SUPERCEDE; // ignore wallbang damage
    }

    return HAM_HANDLED;
}

public OnTraceAttack(ent, attacker, Float:fDamage, Float:vDirection[3], trace, damageBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);

    UTIL_Message_Sparks(vEnd);
    emit_sound(ent, CHAN_BODY, g_szSndHit[random(sizeof(g_szSndHit))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return HAM_HANDLED;
}

public OnTakeDamagePre(ent, inflictor, attacker, Float:fDamage, dmgBits)
{
    if (!attacker) {
        return HAM_IGNORED;
    }

    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    if (~dmgBits & DMG_BULLET) { // explosions, etc.
        static Float:vStart[3];
        pev(inflictor, pev_origin, vStart);

        static Float:vEnd[3];
        pev(ent, pev_origin, vEnd);

        if (!UTIL_IsPointVisible(vStart, vEnd, ent)) {
            return HAM_SUPERCEDE; // ignore wallbang damage
        }
    }

    new team = pev(ent, pev_team);
    if (team == UTIL_GetPlayerTeam(attacker)) {
        return HAM_SUPERCEDE;
    }

    new teamPoints = Hwn_Collector_GetTeamPoints(team);
    if (teamPoints <= 0) {
        return HAM_SUPERCEDE;
    }

    return HAM_HANDLED;
}

public OnTakeDamage(ent, inflictor, attacker, Float:fDamage, dmgBits)
{
    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    new team = pev(ent, pev_team);
    if (!Hwn_Collector_ObjectiveBlocked() && UTIL_IsPlayer(attacker) && team && UTIL_GetPlayerTeam(attacker) != team) {
        DamageEffect(ent);
    }

    return HAM_HANDLED;
}

/*------------[ Tasks ]------------*/

public TaskThink(ent)
{
    if (!pev_valid(ent)) {
        return;
    }

    if (!g_roundStarted) {
        return;
    }

    new Float:fGametime = get_gametime();

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new bool:isCollected = false;
    for (new id = 1; id <= g_maxPlayers; ++id)
    {
        if (!is_user_alive(id)) {
            continue;
        }

        if (fGametime < g_fNextCollectTime[id]) {
            continue;
        }

        new team = pev(ent, pev_team);
        if (team && UTIL_GetPlayerTeam(id) != team) {
            continue;
        }

        static Float:vPlayerOrigin[3];
        pev(id, pev_origin, vPlayerOrigin);

        if (get_distance_f(vOrigin, vPlayerOrigin) > RANGE) {
            continue;
        }

        if (!UTIL_IsPointVisible(vOrigin, vPlayerOrigin, ent)) {
            continue;
        }

        if (!TakePlayerPoint(ent, id)) {
            continue;
        }

        Hwn_PEquipment_GiveHealth(id, get_pcvar_num(g_cvarBucketBonusHealth));
        Hwn_PEquipment_GiveArmor(id, get_pcvar_num(g_cvarBucketBonusArmor));
        Hwn_PEquipment_GiveAmmo(id, get_pcvar_num(g_cvarBucketBonusAmmo));

        LuckyDrop(ent);
        isCollected = true;
        g_fNextCollectTime[id] = fGametime + 1.0;
    }

    if (isCollected) {
        CollectEffect(ent);
        PlayActionSequence(ent, Sequence_Pop, ACTION_POP_DURATION);
    } else {
        new sequence = !g_roundStarted || Hwn_Collector_ObjectiveBlocked() ? Sequence_Idle : Sequence_Bubbling;
        PlayActionSequence(ent, sequence, 0.0);
    }
}

public TaskBoilSound(taskID)
{
    if (!g_roundStarted || Hwn_Collector_ObjectiveBlocked()) {
        return;
    }

    new ent = taskID - TASKID_SUM_BOIL_SOUND;

    emit_sound(ent, CHAN_STATIC, g_szSndBoil, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

public TaskRemoveLid(taskID)
{
    new ent = taskID - TASKID_SUM_REMOVE_LID;

    set_pev(ent, pev_body, 1);
}

/*------------[ Private ]------------*/

ClearTasks(ent)
{
    remove_task(ent);
    remove_task(ent + TASKID_SUM_BOIL_SOUND);
    remove_task(ent + TASKID_SUM_REMOVE_LID);
}

bool:TakePlayerPoint(ent, id)
{
    if (Hwn_Collector_ObjectiveBlocked()) {
        return false;
    }

    new playerPoints = Hwn_Collector_GetPlayerPoints(id);
    if (playerPoints <= 0) {
        return false;
    }

    new team = UTIL_GetPlayerTeam(id);
    new teamPoints = Hwn_Collector_GetTeamPoints(team);

    Hwn_Collector_SetPlayerPoints(id, playerPoints-  1);
    Hwn_Collector_SetTeamPoints(team, teamPoints + 1);

    ExecuteHamB(Ham_AddPoints, id, 1, false);

    PumpkinThrowEffect(ent, id);
    client_cmd(id, "spk %s", g_szSndPointCollected);

    return true;
}

bool:LuckyDrop(ent) {
    new chance = pev(ent, pev_iuser4);

    if (random(100) < chance) {
        DropSpellbook(ent);
        set_pev(ent, pev_iuser4, 0);
    } else {
        set_pev(ent, pev_iuser4, chance + get_pcvar_num(g_cvarBucketBonusChance));
    }
}

bool:ExtractPoints(ent, count = 1)
{
    if (Hwn_Collector_ObjectiveBlocked()) {
        return false;
    }

    if (count <= 0) {
        return false;
    }

    new team = pev(ent, pev_team);

    new teamPoints = Hwn_Collector_GetTeamPoints(team);
    count = teamPoints > count ? count : teamPoints;

    Hwn_Collector_SetTeamPoints(team, teamPoints - count);

    for (new i = 0; i < count; ++i) {
        DropPumpkin(ent);
    }

    PlayActionSequence(ent, Sequence_Pop, ACTION_POP_DURATION);

    return true;
}

bool:DropPumpkin(ent)
{
    new pumpkinEnt = CE_Create("hwn_item_pumpkin", Float:{0.0, 0.0, 0.0});
    if (!pumpkinEnt) {
        return false;
    }

    dllfunc(DLLFunc_Spawn, pumpkinEnt);
    DropEntity(ent, pumpkinEnt);

    return true;
}

bool:DropSpellbook(ent)
{
    new spellbookEnt = CE_Create("hwn_item_spellbook", Float:{0.0, 0.0, 0.0});
    if (!spellbookEnt) {
        return false;
    }

    dllfunc(DLLFunc_Spawn, spellbookEnt);
    DropEntity(ent, spellbookEnt);

    return true;
}

bool:DropEntity(ent, other, Float:fSpeed = 320.0, Float:fNoise = 0.3725)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);
    vOrigin[2] += vMaxs[2];

    static Float:vOtherMins[3];
    pev(ent, pev_mins, vOtherMins);
    vOrigin[2] -= vOtherMins[2];

    static Float:vVelocity[3];
    vVelocity[0] = random_float(-1.0, 1.0);
    vVelocity[1] = random_float(-1.0, 1.0);
    vVelocity[2] = 0.0;

    new Float:fSpeedMaxError = fSpeed * fNoise;

    xs_vec_normalize(vVelocity, vVelocity);
    xs_vec_mul_scalar(vVelocity, fSpeed + random_float(-fSpeedMaxError, fSpeedMaxError), vVelocity);
    vVelocity[2] = 150.0;

    engfunc(EngFunc_SetOrigin, other, vOrigin);
    set_pev(other, pev_velocity, vVelocity);
}

PlayActionSequence(ent, sequence, Float:fDuration)
{
    static Float:fNextAction;
    pev(ent, pev_fuser1, fNextAction);

    if (fNextAction > get_gametime()) {
        return false;
    }

    UTIL_SetSequence(ent, sequence);
    set_pev(ent, pev_fuser1, get_gametime() + fDuration);

    return true;
}

PumpkinThrowEffect(ent, id)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 42.0;
    
    static Float:vUserOrigin[3];
    pev(id, pev_origin, vUserOrigin);

    static Float:vVelocity[3];
    xs_vec_sub(vOrigin, vUserOrigin, vVelocity);
    xs_vec_normalize(vVelocity, vVelocity);
    xs_vec_mul_scalar(vVelocity, 1024.0, vVelocity);

    static modelIndex;
    if (!modelIndex) {
        modelIndex = CE_GetModelIndex("hwn_item_pumpkin");
    }

    UTILS_Message_Projectile(vUserOrigin, vVelocity, modelIndex, 10, id);
}

CollectEffect(ent)
{
    PotionSplashEffect(ent);
    WaveEffect(ent);

    if (get_pcvar_num(g_cvarBucketCollectFlash) > 0) {
        FlashEffect(ent);
    }
}

PotionSplashEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 32.0;

    UTIL_Message_Sprite(vOrigin, g_sprPotionSplash, EFFECT_SPLASH_LIFETIME, EFFECT_SPLASH_ALPHA);
}

FlashEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 24.0;

    UTIL_Message_Dlight(vOrigin, FLASH_RADIUS, {HWN_COLOR_SECONDARY}, FLASH_LIFETIME, FLASH_DECAY_RATE);
}

WaveEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 1.0;

    UTIL_Message_BeamCylinder(
        vOrigin,
        EFFECT_WAVE_RADIUS,
        g_sprPotionBeam,
        0,
        EFFECT_WAVE_LIFETIME,
        EFFECT_WAVE_WIDTH,
        0,
        {HWN_COLOR_GREEN_DARK},
        EFFECT_WAVE_BRIGHTNESS,
        0
    );

    UTIL_Message_BeamDisk(
        vOrigin,
        EFFECT_WAVE_RADIUS,
        g_sprPotionBeam,
        0,
        EFFECT_WAVE_LIFETIME,
        EFFECT_WAVE_WIDTH,
        0,
        {HWN_COLOR_GREEN_DARK},
        EFFECT_WAVE_DISK_BRIGHTNESS,
        0
    );
}

DamageEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 42.0;

    UTIL_Message_BloodSprite(vOrigin, 0, g_sprBlood, EFFECT_SPELL_DROPS_COLOR, EFFECT_SPELL_DROPS_SCALE);
}

PotionExplodeEffect(ent)
{
    new Float:vStart[3];
    pev(ent, pev_origin, vStart);
    vStart[2] += 8.0;

    new Float:vEnd[3];
    xs_vec_copy(vStart, vEnd);
    vEnd[2] += 16.0;

    UTIL_Message_SpriteTrail(
        vStart,
        vEnd,
        g_sprSparkle,
        EFFECT_MAGIC_SPLASH_PARTICLE_COUNT,
        EFFECT_MAGIC_SPLASH_PARTICLE_LIFETIME,
        EFFECT_MAGIC_SPLASH_PARTICLE_SCALE,
        EFFECT_MAGIC_SPLASH_PARTICLE_SPEED,
        EFFECT_MAGIC_SPLASH_PARTICLE_NOISE
    );
}
