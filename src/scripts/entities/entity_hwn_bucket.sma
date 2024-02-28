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

#define ENTITY_NAME "hwn_bucket"
#define LIQUID_ENTITY_NAME "hwn_bucket_liquid"

#define TASKID_SUM_BOIL_SOUND 1000
#define TASKID_SUM_REMOVE_LID 2000

#define TAKE_RANGE 256.0

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
#define EFFECT_WAVE_RADIUS TAKE_RANGE - 1.0
#define EFFECT_WAVE_LIFETIME 5
#define EFFECT_WAVE_WIDTH 32
#define EFFECT_WAVE_BRIGHTNESS 100
#define EFFECT_WAVE_DISK_BRIGHTNESS 60
#define EFFECT_SPLASH_LIFETIME 10
#define EFFECT_SPLASH_ALPHA 50

#define FLASH_RADIUS 32
#define FLASH_LIFETIME 10
#define FLASH_DECAY_RATE 28

#define BOIL_SOUND_DURATION 2.2

#define m_flNextBoil "flNextBoil"
#define m_flNextAction "flNextAction"
#define m_flNextRemoveLid "flNextRemoveLid"
#define m_iBonusChance "iBonusChance"
#define m_pLiquid "pLiquid"
#define m_flReleaseBoiling "flReleaseBoiling"

enum _:Sequence {
    Sequence_Idle = 0,
    Sequence_Bubbling,
    Sequence_Pop,
    Sequence_BigPop
};

enum Team {
    Team_Undefined = 0,
    Team_Red,
    Team_Blue,
    Team_Spectators
};

new Float:g_rgvecTeamColor[Team][3] = {
    { HWN_COLOR_GREEN_DARK_F },
    { HWN_COLOR_RED_F },
    { HWN_COLOR_BLUE_F },
    { 255.0, 255.0, 255.0}
};

new const g_szModel[] = "models/hwn/props/cauldron.mdl";
new const g_szLiquidModel[] = "models/hwn/props/cauldron_liquid.mdl";
new const g_szSndBoil[] = "hwn/misc/cauldron_boil.wav";
new const g_szSndHit[][] = { "debris/metal4.wav", "debris/metal6.wav" };

new g_pCvarBucketHealth;
new g_pCvarBucketCollectFlash;
new g_pCvarBucketBonusHealth;
new g_pCvarBucketBonusArmor;
new g_pCvarBucketBonusAmmo;
new g_pCvarBucketBonusChance;

new g_iBloodModelIndex;
new g_iSparkleModelIndex;
new g_iPotionSplashModelIndex;
new g_iPotionBeamModelIndex;

new CE:g_iCeHandler;

new Float:g_rgflPlayerNextCollectTime[MAX_PLAYERS + 1];

public plugin_precache() {
    precache_model(g_szModel);
    precache_model(g_szLiquidModel);

    g_iBloodModelIndex = precache_model("sprites/blood.spr");
    g_iSparkleModelIndex = precache_model("sprites/exit1.spr");
    g_iPotionSplashModelIndex = precache_model("sprites/bm1.spr");
    g_iPotionBeamModelIndex = precache_model("sprites/streak.spr");

    precache_sound(g_szSndBoil);

    for (new i = 0; i < sizeof(g_szSndHit); ++i) {
        precache_sound(g_szSndHit[i]);
    }

    g_iCeHandler = CE_Register(ENTITY_NAME);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_InitPhysics, "@Entity_InitPhysics");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Kill, "@Entity_Kill");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    CE_Register(LIQUID_ENTITY_NAME, CEPreset_Prop);
    CE_RegisterHook(LIQUID_ENTITY_NAME, CEFunction_Init, "@Liquid_Init");
    CE_RegisterHook(LIQUID_ENTITY_NAME, CEFunction_Spawned, "@Liquid_Spawn");
    CE_RegisterHook(LIQUID_ENTITY_NAME, CEFunction_InitPhysics, "@Liquid_InitPhysics");

    g_pCvarBucketHealth = register_cvar("hwn_bucket_health", "300");
    g_pCvarBucketCollectFlash = register_cvar("hwn_bucket_collect_flash", "1");
    g_pCvarBucketBonusHealth = register_cvar("hwn_bucket_bonus_health", "10");
    g_pCvarBucketBonusArmor = register_cvar("hwn_bucket_bonus_armor", "10");
    g_pCvarBucketBonusAmmo = register_cvar("hwn_bucket_bonus_ammo", "1");
    g_pCvarBucketBonusChance = register_cvar("hwn_bucket_bonus_chance", "5");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage", .Post = 0);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack", .Post = 0);
    RegisterHam(Ham_TakeDamage, CE_BASE_CLASSNAME, "HamHook_Base_TakeDamage_Post", .Post = 1);
    RegisterHam(Ham_TraceAttack, CE_BASE_CLASSNAME, "HamHook_Base_TraceAttack_Post", .Post = 1);
}

/*--------------------------------[ Methods ]--------------------------------*/

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-28.0, -28.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{28.0, 28.0, 56.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel);

    new pLiquid = CE_Create(LIQUID_ENTITY_NAME, Float:{0.0, 0.0, 0.0}, false);
    set_pev(pLiquid, pev_owner, this);
    dllfunc(DLLFunc_Spawn, pLiquid);
    CE_SetMember(this, m_pLiquid, pLiquid);
}

@Entity_Spawned(this) {
    new iTeam = pev(this, pev_team);

    CE_SetMember(this, m_flNextBoil, 0.0);
    CE_SetMember(this, m_flNextAction, 0.0);
    CE_SetMember(this, m_flNextRemoveLid, 0.0);
    CE_SetMember(this, m_flReleaseBoiling, 0.0);
    CE_SetMember(this, m_iBonusChance, 0);

    set_pev(this, pev_renderfx, kRenderFxGlowShell);
    set_pev(this, pev_renderamt, 0.0);
    set_pev(this, pev_rendercolor, g_rgvecTeamColor[Team:iTeam]);
    set_pev(this, pev_health, float(get_pcvar_num(g_pCvarBucketHealth)));
    set_pev(this, pev_body, 0);

    engfunc(EngFunc_DropToFloor, this);

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Kill(this) {
    new iMaxHealth = get_pcvar_num(g_pCvarBucketHealth);

    new iExtractsNum = 1;

    static Float:flHealth; pev(this, pev_health, flHealth);
    if (flHealth < 0) {
        iExtractsNum += floatround(-flHealth) / iMaxHealth;
    }

    set_pev(this, pev_health, float(iMaxHealth));

    @Entity_ExtractPoints(this, iExtractsNum);

    return PLUGIN_HANDLED;
}

@Entity_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_BBOX);
    set_pev(this, pev_movetype, MOVETYPE_PUSHSTEP);
    set_pev(this, pev_takedamage, DAMAGE_AIM);
}

@Entity_Remove(this) {
    new pLiquid = CE_GetMember(this, m_pLiquid);
    CE_SetMember(this, m_pLiquid, 0);
    CE_Remove(pLiquid);
}

@Entity_Think(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    new pLiquid = CE_GetMember(this, m_pLiquid);
    if (pLiquid) {
        new Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);
        engfunc(EngFunc_SetOrigin, pLiquid, vecOrigin);
    }

    static Float:flReleaseBoiling; flReleaseBoiling = CE_GetMember(this, m_flReleaseBoiling);
    if (flReleaseBoiling && flReleaseBoiling <= flGameTime) {
        CE_SetMember(this, m_flNextAction, 0.0);
        @Entity_Pop(this);
        CE_SetMember(this, m_flReleaseBoiling, 0.0);
    }

    if (@Entity_CollectPoints(this)) {
        @Entity_CollectEffect(this);
        @Entity_PlayActionSequence(this, Sequence_Pop, ACTION_POP_DURATION);
    } else {
        new iSequence = Hwn_Collector_ObjectiveBlocked() ? Sequence_Idle : Sequence_Bubbling;
        @Entity_PlayActionSequence(this, iSequence, 0.0);
    }

    new Float:flNextRemoveLid; flNextRemoveLid = CE_GetMember(this, m_flNextRemoveLid);
    if (flNextRemoveLid && flNextRemoveLid <= flGameTime) {
        set_pev(this, pev_body, 1);
        CE_SetMember(this, m_flNextRemoveLid, 0.0);
    }

    static Float:flNextBoil; flNextBoil = CE_GetMember(this, m_flNextBoil);
    if (flNextBoil <= flGameTime) {
        emit_sound(this, CHAN_STATIC, g_szSndBoil, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        CE_SetMember(this, m_flNextBoil, flGameTime + BOIL_SOUND_DURATION);
    }

    set_pev(this, pev_nextthink, flGameTime + Hwn_GetUpdateRate());
}

@Entity_Pop(this) {
    new Float:flDuration = ACTION_BIG_POP_DURATION * (1.0 / ACTION_BIG_POP_FRAMERATE);
    @Entity_PlayActionSequence(this, Sequence_BigPop, flDuration);
    set_pev(this, pev_framerate, ACTION_BIG_POP_FRAMERATE);

    @Entity_PotionExplodeEffect(this);
    @Entity_FlashEffect(this);
    @Entity_WaveEffect(this);

    CE_SetMember(this, m_flNextRemoveLid, get_gametime() + flDuration);
}

bool:@Entity_CollectPoints(this) {
    if (!Round_IsRoundStarted()) return false;
    if (Round_IsRoundEnd()) return false;
    
    new Float:flGameTime = get_gametime();
    new bool:bIsCollected = false;

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_alive(pPlayer)) continue;
        if (flGameTime < g_rgflPlayerNextCollectTime[pPlayer]) continue;

        new iTeam = pev(this, pev_team);
        if (iTeam && get_member(pPlayer, m_iTeam) != iTeam) continue;

        static Float:vecPlayerOrigin[3]; pev(pPlayer, pev_origin, vecPlayerOrigin);
        if (get_distance_f(vecOrigin, vecPlayerOrigin) > TAKE_RANGE) continue;

        if (!UTIL_IsPointVisible(vecOrigin, vecPlayerOrigin, this)) continue;
        if (!@Entity_TakePlayerPoint(this, pPlayer)) continue;

        bIsCollected = true;

        g_rgflPlayerNextCollectTime[pPlayer] = flGameTime + 1.0;
    }

    return bIsCollected;
}

bool:@Entity_TakePlayerPoint(this, pPlayer) {
    if (!Hwn_Collector_ScorePlayerPointsToTeam(pPlayer, 1)) {
        return false;
    }

    @Entity_PumpkinThrowEffect(this, pPlayer);

    Hwn_PEquipment_GiveHealth(pPlayer, get_pcvar_num(g_pCvarBucketBonusHealth));
    Hwn_PEquipment_GiveArmor(pPlayer, get_pcvar_num(g_pCvarBucketBonusArmor));
    Hwn_PEquipment_GiveAmmo(pPlayer, get_pcvar_num(g_pCvarBucketBonusAmmo));

    @Entity_LuckyDrop(this);

    return true;
}

bool:@Entity_LuckyDrop(this) {
    new iBonusChance = CE_GetMember(this, m_iBonusChance);

    if (random(100) < iBonusChance) {
        @Entity_DropSpellbook(this);
        CE_SetMember(this, m_iBonusChance, 0);
    } else {
        CE_SetMember(this, m_iBonusChance, get_pcvar_num(g_pCvarBucketBonusChance));
    }
}

bool:@Entity_ExtractPoints(this, iNum) {
    if (Hwn_Collector_ObjectiveBlocked()) return false;
    if (iNum <= 0) return false;

    new iTeam = pev(this, pev_team);
    new iTeamPoints = Hwn_Collector_GetTeamPoints(iTeam);
    new iNumFixed = min(iNum, iTeamPoints);

    Hwn_Collector_SetTeamPoints(iTeam, iTeamPoints - iNumFixed);

    for (new i = 0; i < iNumFixed; ++i) @Entity_DropPumpkin(this);

    @Entity_PlayActionSequence(this, Sequence_Pop, ACTION_POP_DURATION);

    return true;
}

bool:@Entity_DropPumpkin(this) {
    new pPumpkin = CE_Create("hwn_item_pumpkin");
    if (!pPumpkin) return false;

    dllfunc(DLLFunc_Spawn, pPumpkin);
    @Entity_DropEntity(this, pPumpkin);

    return true;
}

bool:@Entity_DropSpellbook(this) {
    new pSpellbook = CE_Create("hwn_item_spellbook");
    if (!pSpellbook) return false;

    dllfunc(DLLFunc_Spawn, pSpellbook);
    @Entity_DropEntity(this, pSpellbook);

    return true;
}

bool:@Entity_DropEntity(this, pEntity) {
    new Float:flSpeed = 320.0;
    new Float:flNoise = 0.3725;

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static Float:vecMaxs[3];
    pev(this, pev_maxs, vecMaxs);
    vecOrigin[2] += vecMaxs[2];

    static Float:vecOtherMins[3];
    pev(this, pev_mins, vecOtherMins);
    vecOrigin[2] -= vecOtherMins[2];

    static Float:vecVelocity[3];
    vecVelocity[0] = random_float(-1.0, 1.0);
    vecVelocity[1] = random_float(-1.0, 1.0);
    vecVelocity[2] = 0.0;

    new Float:flSpeedMaxError = flSpeed * flNoise;

    xs_vec_normalize(vecVelocity, vecVelocity);
    xs_vec_mul_scalar(vecVelocity, flSpeed + random_float(-flSpeedMaxError, flSpeedMaxError), vecVelocity);
    vecVelocity[2] = 150.0;

    engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);
    set_pev(pEntity, pev_velocity, vecVelocity);
}

@Entity_PlayActionSequence(this, iSequence, Float:flDuration) {
    static Float:flGameTime; flGameTime = get_gametime();

    if (CE_GetMember(this, m_flNextAction) > flGameTime) return false;

    UTIL_SetSequence(this, iSequence);

    CE_SetMember(this, m_flNextAction, flGameTime + flDuration);

    return true;
}

@Entity_PumpkinThrowEffect(this, pPlayer) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 42.0;
    
    static Float:vecUserOrigin[3];
    pev(pPlayer, pev_origin, vecUserOrigin);

    static Float:vecVelocity[3];
    xs_vec_sub(vecOrigin, vecUserOrigin, vecVelocity);
    xs_vec_normalize(vecVelocity, vecVelocity);
    xs_vec_mul_scalar(vecVelocity, 1024.0, vecVelocity);

    static iModelIndex = 0;
    if (!iModelIndex) {
        iModelIndex = engfunc(EngFunc_ModelIndex, "models/hwn/items/pumpkin_loot_v3.mdl");
    }

    UTILS_Message_Projectile(vecUserOrigin, vecVelocity, iModelIndex, 10, pPlayer);
}

@Entity_CollectEffect(this) {
    @Entity_PotionSplashEffect(this);
    @Entity_WaveEffect(this);

    if (get_pcvar_num(g_pCvarBucketCollectFlash) > 0) {
        @Entity_FlashEffect(this);
    }
}

@Entity_PotionSplashEffect(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 32.0;

    UTIL_Message_Sprite(vecOrigin, g_iPotionSplashModelIndex, EFFECT_SPLASH_LIFETIME, EFFECT_SPLASH_ALPHA);
}

@Entity_FlashEffect(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 24.0;

    UTIL_Message_Dlight(vecOrigin, FLASH_RADIUS, {HWN_COLOR_SECONDARY}, FLASH_LIFETIME, FLASH_DECAY_RATE);
}

@Entity_WaveEffect(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 1.0;

    UTIL_Message_BeamCylinder(
        vecOrigin,
        EFFECT_WAVE_RADIUS,
        g_iPotionBeamModelIndex,
        0,
        EFFECT_WAVE_LIFETIME,
        EFFECT_WAVE_WIDTH,
        0,
        {HWN_COLOR_GREEN_DARK},
        EFFECT_WAVE_BRIGHTNESS,
        0
    );

    UTIL_Message_BeamDisk(
        vecOrigin,
        EFFECT_WAVE_RADIUS,
        g_iPotionBeamModelIndex,
        0,
        EFFECT_WAVE_LIFETIME,
        EFFECT_WAVE_WIDTH,
        0,
        {HWN_COLOR_GREEN_DARK},
        EFFECT_WAVE_DISK_BRIGHTNESS,
        0
    );
}

@Entity_DamageEffect(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 42.0;

    UTIL_Message_BloodSprite(vecOrigin, 0, g_iBloodModelIndex, EFFECT_SPELL_DROPS_COLOR, EFFECT_SPELL_DROPS_SCALE);
}

@Entity_PotionExplodeEffect(this) {
    new Float:vecStart[3];
    pev(this, pev_origin, vecStart);
    vecStart[2] += 8.0;

    new Float:vecEnd[3];
    xs_vec_copy(vecStart, vecEnd);
    vecEnd[2] += 16.0;

    UTIL_Message_SpriteTrail(
        vecStart,
        vecEnd,
        g_iSparkleModelIndex,
        EFFECT_MAGIC_SPLASH_PARTICLE_COUNT,
        EFFECT_MAGIC_SPLASH_PARTICLE_LIFETIME,
        EFFECT_MAGIC_SPLASH_PARTICLE_SCALE,
        EFFECT_MAGIC_SPLASH_PARTICLE_SPEED,
        EFFECT_MAGIC_SPLASH_PARTICLE_NOISE
    );
}

@Liquid_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-28.0, -28.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{28.0, 28.0, 56.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szLiquidModel);
}

@Liquid_Spawn(this) {
    set_pev(this, pev_rendermode, kRenderTransAdd);
    set_pev(this, pev_renderamt, 255.0);
}

@Liquid_InitPhysics(this) {
    set_pev(this, pev_solid, SOLID_NOT);
    set_pev(this, pev_movetype, MOVETYPE_FLY);
    set_pev(this, pev_takedamage, DAMAGE_NO);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_TraceAttack(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) return HAM_IGNORED;

    static Float:vecStart[3]; UTIL_GetViewOrigin(pAttacker, vecStart);
    static Float:vecEnd[3]; get_tr2(pTrace, TR_vecEndPos, vecEnd);

    // Ignore wallbang damage
    if (!UTIL_IsPointVisible(vecStart, vecEnd, pEntity)) return HAM_SUPERCEDE;

    return HAM_HANDLED;
}

public HamHook_Base_TraceAttack_Post(pEntity, pAttacker, Float:flDamage, Float:vecDirection[3], pTrace, iDamageBits) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) return HAM_IGNORED;

    static Float:vecEnd[3]; get_tr2(pTrace, TR_vecEndPos, vecEnd);

    UTIL_Message_Sparks(vecEnd);
    emit_sound(pEntity, CHAN_BODY, g_szSndHit[random(sizeof(g_szSndHit))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return HAM_HANDLED;
}

public HamHook_Base_TakeDamage(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (!pAttacker) return HAM_IGNORED;

    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) return HAM_IGNORED;

    if (~iDamageBits & DMG_BULLET) { // explosions, etc.
        static Float:vecStart[3]; pev(pInflictor, pev_origin, vecStart);
        static Float:vecEnd[3]; pev(pEntity, pev_origin, vecEnd);

        // Ignore wallbang damage
        if (!UTIL_IsPointVisible(vecStart, vecEnd, pEntity)) return HAM_SUPERCEDE; 
    }

    new iTeam = pev(pEntity, pev_team);
    if (iTeam == get_member(pAttacker, m_iTeam)) return HAM_SUPERCEDE;

    new iiTeamPoints = Hwn_Collector_GetTeamPoints(iTeam);
    if (iiTeamPoints <= 0) return HAM_SUPERCEDE;

    return HAM_HANDLED;
}

public HamHook_Base_TakeDamage_Post(pEntity, pInflictor, pAttacker, Float:flDamage, iDamageBits) {
    if (g_iCeHandler != CE_GetHandlerByEntity(pEntity)) return HAM_IGNORED;

    new iTeam = pev(pEntity, pev_team);
    if (!Hwn_Collector_ObjectiveBlocked() && IS_PLAYER(pAttacker) && iTeam && get_member(pAttacker, m_iTeam) != iTeam) {
        @Entity_DamageEffect(pEntity);
    }

    return HAM_HANDLED;
}
