#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Bucket"
#define AUTHOR "Hedgehog Fog"

#define TASKID_SUM_BOIL_SOUND 1000

#define ENTITY_NAME "hwn_bucket"
#define LIQUID_ENTITY_NAME "hwn_bucket_liquid"

#define FLASH_RADIUS 32
#define FLASH_LIFETIME 10
#define FLASH_DECAY_RATE 28
#define BOIL_SOUND_DURATION 2.2

enum Team
{
    Team_Undefined = 0,
    Team_Red,
    Team_Blue,
    Team_Spectators
};

new Float:g_vTeamColor[Team][3] = {
    {0.0, 0.0, 0.0},
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

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "OnTakeDamage", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "OnTraceAttack", .Post = 1);

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Kill, ENTITY_NAME, "OnKill");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Spawn, LIQUID_ENTITY_NAME, "OnLiquidSpawn");

    g_cvarBucketHealth = register_cvar("hwn_bucket_health", "300");
    g_cvarBucketCollectFlash = register_cvar("hwn_bucket_collect_flash", "1");
    g_cvarBucketBonusHealth = register_cvar("hwn_bucket_bonus_health", "10");
    g_cvarBucketBonusArmor = register_cvar("hwn_bucket_bonus_armor", "10");
    g_cvarBucketBonusAmmo = register_cvar("hwn_bucket_bonus_ammo", "1");

    g_buckets = ArrayCreate(1, 2);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

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

public Hwn_Gamemode_Fw_RoundStart()
{
    g_roundStarted = true;
}

public Hwn_Gamemode_Fw_RoundEnd()
{
    g_roundStarted = false;
}

public Hwn_Collector_Fw_WinnerTeam(team)
{
    new count = ArraySize(g_buckets);
    for (new i = 0; i < count; ++i) {
        new ent = ArrayGetCell(g_buckets, i);

        if (pev(ent, pev_team) != team) {
            continue;
        }

        set_pev(ent, pev_body, 1);
        MagicSplashEffect(ent, 32);
    }
}

/*------------[ Hooks ]------------*/

public OnSpawn(ent)
{
    new team = pev(ent, pev_team);

    new Float:fRenderColor[3];
    for (new i = 0; i < 3; ++i) {
        fRenderColor[i] = g_vTeamColor[Team:team][i] * 1.0;
    }

    set_pev(ent, pev_solid, SOLID_BBOX);
    set_pev(ent, pev_movetype, MOVETYPE_FLY);
    set_pev(ent, pev_takedamage, DAMAGE_AIM);
    set_pev(ent, pev_renderfx, kRenderFxGlowShell);
    set_pev(ent, pev_renderamt, 0.0);
    set_pev(ent, pev_rendercolor, fRenderColor);
    set_pev(ent, pev_health, float(get_pcvar_num(g_cvarBucketHealth)));
    set_pev(ent, pev_body, 0);

    engfunc(EngFunc_DropToFloor, ent);

    if (!pev(ent, pev_iuser1)) {
        new liquidEnt = CE_Create("hwn_bucket_liquid", Float:{0.0, 0.0, 0.0}, false);
        set_pev(liquidEnt, pev_owner, ent);
        dllfunc(DLLFunc_Spawn, liquidEnt);

        set_pev(ent, pev_iuser1, liquidEnt);
    }

    ArrayPushCell(g_buckets, ent);

    set_task(g_fThinkDelay, "TaskThink", ent, _, _, "b");
    set_task(BOIL_SOUND_DURATION, "TaskBoilSound", ent + TASKID_SUM_BOIL_SOUND, _, _, "b");
}

public OnLiquidSpawn(ent)
{
    new owner = pev(ent, pev_owner);

    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_rendermode, kRenderTransAdd);
    set_pev(ent, pev_renderamt, 255.0);

    static Float:vOrigin[3];
    pev(owner, pev_origin, vOrigin);
    engfunc(EngFunc_SetOrigin, ent, vOrigin);
}

public OnRemove(ent)
{
    new liquidEnt = pev(ent, pev_iuser1);
    CE_Remove(liquidEnt);

    remove_task(ent);
    remove_task(ent + TASKID_SUM_BOIL_SOUND);
}

public OnTakeDamage(ent, inflictor, attacker, Float:fDamage)
{
    if (!attacker) {
        return HAM_IGNORED;
    }

    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return HAM_IGNORED;
    }

    new team = pev(ent, pev_team);
    if (team == UTIL_GetPlayerTeam(attacker)) {
        return HAM_SUPERCEDE;
    }

    new teamPoints = Hwn_Collector_GetTeamPoints(team);
    if (teamPoints <= 0) {
        return HAM_SUPERCEDE;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    if (!UTIL_IsPointVisibleByEnt(inflictor, vOrigin)) { // block wallbangs
        return HAM_SUPERCEDE;
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

    HitEffect(ent, attacker, vEnd);
    emit_sound(ent, CHAN_BODY, g_szSndHit[random(sizeof(g_szSndHit))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return HAM_HANDLED;
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

    return PLUGIN_HANDLED;
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

    for (new id = 1; id <= g_maxPlayers; ++id)
    {
        if (!is_user_alive(id)) {
            continue;
        }

        if (fGametime < g_fNextCollectTime[id]) {
            continue;
        }

        if (UTIL_GetPlayerTeam(id) != pev(ent, pev_team)) {
            continue;
        }

        static Float:vPlayerOrigin[3];
        pev(id, pev_origin, vPlayerOrigin);

        if (get_distance_f(vOrigin, vPlayerOrigin) > 256.0) {
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

        g_fNextCollectTime[id] = fGametime + 1.0;
    }

    UpdateAction(ent);
}

public TaskBoilSound(taskID)
{
    if (Hwn_Collector_ObjectiveBlocked()) {
        return;
    }

    new ent = taskID - TASKID_SUM_BOIL_SOUND;

    emit_sound(ent, CHAN_STATIC, g_szSndBoil, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

/*------------[ Private ]------------*/

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

    PlayActionSequence(ent, 2, 0.33);
    TakePlayerPointEffect(ent, id);
    client_cmd(id, "spk %s", g_szSndPointCollected);

    return true;
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
    
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);
    vOrigin[2] += vMaxs[2];

    for (new i = 0; i < count; ++i) {
        DropPumpkin(vOrigin);
    }

    PlayActionSequence(ent, 2, 0.7);

    return true;
}

bool:DropPumpkin(const Float:vOrigin[3])
{
    new pumpkinEnt = CE_Create("hwn_item_pumpkin", vOrigin);
    if (!pumpkinEnt) {
        return false;
    }

    static Float:vVelocity[3];
    vVelocity[0] = random_float(-640.0, 640.0);
    vVelocity[1] = random_float(-640.0, 640.0);
    vVelocity[2] = random_float(0.0, 256.0);

    set_pev(pumpkinEnt, pev_velocity, vVelocity);

    dllfunc(DLLFunc_Spawn, pumpkinEnt);

    return true;
}

PlayActionSequence(ent, seq, Float:fDuration)
{
    UTIL_SetSequence(ent, seq);
    set_pev(ent, pev_fuser1, fDuration);
}

UpdateAction(ent)
{
    static Float:fDuration;
    pev(ent, pev_fuser1, fDuration);

    static Float:fAnimtime;
    pev(ent, pev_animtime, fAnimtime);

    new Float:fTimeLeft = (fAnimtime + fDuration) - get_gametime();
    if (fTimeLeft > 0) {
        return;
    }

    UTIL_SetSequence(ent, !g_roundStarted || Hwn_Collector_ObjectiveBlocked() ? 0 : 1);
}

TakePlayerPointEffect(ent, id)
{
    BucketThrowEffect(ent, id);
    PotionSplashEffect(ent);
    PotionWaveEffect(ent);

    if (get_pcvar_num(g_cvarBucketCollectFlash) > 0) {
        FlashEffect(ent);
    }
}

BucketThrowEffect(ent, id)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 24.0;
    
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

FlashEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 24.0;

    UTIL_Message_Dlight(vOrigin, FLASH_RADIUS, {HWN_COLOR_SECONDARY}, FLASH_LIFETIME, FLASH_DECAY_RATE);
}

PotionWaveEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 1.0;

    UTIL_Message_BeamCylinder(vOrigin, 255.0, g_sprPotionBeam, 0, 5, 32, 0, {HWN_COLOR_GREEN_DARK}, 100, 0);
    UTIL_Message_BeamDisk(vOrigin, 255.0, g_sprPotionBeam, 0, 5, 32, 0, {HWN_COLOR_GREEN_DARK}, 60, 0);
}

PotionSplashEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 32.0;

    UTIL_Message_Sprite(vOrigin, g_sprPotionSplash, 10, 50);
}

HitEffect(ent, attacker, const Float:vHitOrigin[3])
{
    UTIL_Message_Sparks(vHitOrigin);

    if (UTIL_IsPlayer(attacker) && UTIL_GetPlayerTeam(attacker) != pev(ent, pev_team)) {
        LiquidSplashEffect(ent);
    }
}

LiquidSplashEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 42.0;

    UTIL_Message_BloodSprite(vOrigin, 0, g_sprBlood, 242, 15);
}

MagicSplashEffect(ent, count)
{
    static Float:vStart[3];
    pev(ent, pev_origin, vStart);
    vStart[2] += 8.0;

    static Float:vEnd[3];
    xs_vec_copy(vStart, vEnd);
    vEnd[2] += 16.0;

    UTIL_Message_SpriteTrail(vStart, vEnd, g_sprSparkle, count, 1, 1, 16, 32);
}
