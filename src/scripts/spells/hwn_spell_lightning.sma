#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_advanced_pushing_system>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Lightning Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"

#define m_iSpell "iSpell"
#define m_irgpVictims "irgpVictims"
#define m_flSpellNextVictimsUpdate "flSpellNextVictimsUpdate"
#define m_flSpellNextDamage "flSpellNextDamage"
#define m_flSpellNextEffect "flSpellNextEffect"

const Float:SpellballSpeed = 320.0;
const Float:SpellballLifeTime = 5.0;
const Float:SpellballMagnetism = 320.0;

const Float:EffectDamage = 30.0;
const Float:EffectDamageDelay = 0.5;
const Float:EffectLightningDelay = 0.1;
const Float:EffectRadius = 96.0;
const Float:EffectDamageRadiusMultiplier = 0.75;
const Float:EffectImpactRadiusMultiplier = 0.5;
new const EffectColor[3] = {32, 128, 192};

new const g_szSndCast[] = "hwn/spells/spell_lightning_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_lightning_impact.wav";
new const g_szSprSpellBall[] = "sprites/flare6.spr";

new g_iEffectModelIndex;
new g_iSpellHandler;

new Array:g_irgLightningBalls;

public plugin_precache() {
    g_irgLightningBalls = ArrayCreate();

    g_iEffectModelIndex = precache_model("sprites/lgtning.spr");
    precache_model(g_szSprSpellBall);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_iSpellHandler = Hwn_Spell_Register(
        "Lightning", 
        (
            Hwn_SpellFlag_Throwable |
            Hwn_SpellFlag_Damage |
            Hwn_SpellFlag_Radius |
            Hwn_SpellFlag_Rare
        ),
        "@Player_CastSpell"
    );
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
    register_forward(FM_Think, "FMHook_Think", ._post = 1);

    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink", .Post = 1);

    CE_RegisterHook(CEFunction_Init, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Init");
    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Killed");
    CE_RegisterHook(CEFunction_Remove, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Remove");
    CE_RegisterHook(CEFunction_Think, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Think");
}

public plugin_end() {
    ArrayDestroy(g_irgLightningBalls);
}

/*--------------------------------[ Methods ]--------------------------------*/

@SpellBall_Init(this) {
    if (CE_GetMember(this, m_iSpell) != g_iSpellHandler) return;

    CE_SetMember(this, m_irgpVictims, ArrayCreate());

    ArrayPushCell(g_irgLightningBalls, this);
}

@SpellBall_Remove(this) {
    if (CE_GetMember(this, m_iSpell) != g_iSpellHandler) return;

    new Array:irgpVictims = CE_GetMember(this, m_irgpVictims);
    ArrayDestroy(irgpVictims);

    new iGlobalId = ArrayFindValue(g_irgLightningBalls, this);
    if (iGlobalId != -1) {
        ArrayDeleteItem(g_irgLightningBalls, iGlobalId);
    }
}

@SpellBall_Killed(this) {
    if (CE_GetMember(this, m_iSpell) != g_iSpellHandler) return;

    @SpellBall_Detonate(this);
}

@SpellBall_Think(this) {
    if (CE_GetMember(this, m_iSpell) != g_iSpellHandler) return;

    static Float:flGameTime; flGameTime = get_gametime();

    static Float:flSpellNextVictimsUpdate; flSpellNextVictimsUpdate = CE_GetMember(this, m_flSpellNextVictimsUpdate);
    if (flSpellNextVictimsUpdate <= flGameTime) {
        @SpellBall_UpdateVictims(this);
        CE_SetMember(this, m_flSpellNextVictimsUpdate, flGameTime + 0.1);
    }

    static Float:flSpellNextDamage; flSpellNextDamage = CE_GetMember(this, m_flSpellNextDamage);
    if (flSpellNextDamage <= flGameTime) {
        @SpellBall_RadiusDamage(this, false);
        emit_sound(this, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        CE_SetMember(this, m_flSpellNextDamage, flGameTime + EffectDamageDelay);
    }

    static Float:flSpellNextEffect; flSpellNextEffect = CE_GetMember(this, m_flSpellNextEffect);
    if (flSpellNextEffect <= flGameTime) {
        for (new i = 0; i < 4; ++i) @SpellBall_DrawLightingBeam(this);
        CE_SetMember(this, m_flSpellNextEffect, flGameTime + EffectLightningDelay);
    }

    // Update velocity
    static Float:vecVelocity[3];
    pev(this, pev_vuser1, vecVelocity);
    set_pev(this, pev_velocity, vecVelocity);
}

@SpellBall_UpdateVictims(this) {
    new Array:irgpVictims; irgpVictims = CE_GetMember(this, m_irgpVictims);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    ArrayClear(irgpVictims);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EffectRadius)) > 0) {
        if (@SpellBall_IsValidVictim(this, pTarget)) {
            ArrayPushCell(irgpVictims, pTarget);
        }
    }
}

bool:@SpellBall_Magnetize(pEntity, pTarget) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTargetOrigin[3];
    pev(pTarget, pev_origin, vecTargetOrigin);

    new Float:flDistance = get_distance_f(vecOrigin, vecTargetOrigin);

    if (flDistance > EffectRadius) return false;

    if (flDistance > EffectRadius * EffectImpactRadiusMultiplier) {
        APS_PushFromOrigin(pTarget, -SpellballMagnetism, vecOrigin);
    } else {
        static Float:vecVelocity[3];
        pev(pEntity, pev_velocity, vecVelocity);
        set_pev(pTarget, pev_velocity, vecVelocity);
    }

    return true;
}

@SpellBall_Detonate(pEntity) {
    @SpellBall_RadiusDamage(pEntity, true);
    @SpellBall_DetonateEffect(pEntity);
}

@SpellBall_RadiusDamage(this, bool:bPush) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    new pOwner = pev(this, pev_owner);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EffectRadius)) != 0) {
        if (@SpellBall_IsValidVictim(this, pTarget)) {
            if (bPush) {
                if (IS_PLAYER(pTarget) || pev(pTarget, pev_flags) & FL_MONSTER) {
                    APS_PushFromOrigin(pTarget, SpellballMagnetism, vecOrigin);
                }
            }

            static Float:vecTargetOrigin[3];
            pev(pTarget, pev_origin, vecTargetOrigin);

            new Float:flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, EffectRadius * EffectDamageRadiusMultiplier, EffectDamage, false, pTarget);
            ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, flDamage, DMG_SHOCK);
        }
    }
}

@SpellBall_DrawLightingBeam(this) {
    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    // Generate random offset
    static Float:vecTarget[3];
    for (new i = 0; i < 3; ++i) vecTarget[i] = random_float(-16.0, 16.0);

    xs_vec_normalize(vecTarget, vecTarget);
    xs_vec_mul_scalar(vecTarget, EffectRadius, vecTarget);
    xs_vec_add(vecOrigin, vecTarget, vecTarget);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, vecTarget[0]);
    engfunc(EngFunc_WriteCoord, vecTarget[1]);
    engfunc(EngFunc_WriteCoord, vecTarget[2]);
    write_short(g_iEffectModelIndex);
    write_byte(0);
    write_byte(30);
    write_byte(5);
    write_byte(20);
    write_byte(192);
    write_byte(EffectColor[0]);
    write_byte(EffectColor[1]);
    write_byte(EffectColor[2]);
    write_byte(100);
    write_byte(100);
    message_end();
}

@SpellBall_DetonateEffect(this) {
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    UTIL_Message_BeamCylinder(vecOrigin, EffectRadius * 3, g_iEffectModelIndex, 0, 3, 32, 255, EffectColor, 100, 0);
    emit_sound(this, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@SpellBall_IsValidVictim(this, pVictim) {
    if (!pev_valid(pVictim)) return false;
    if (this == pVictim) return false;

    static Float:flTakeDamage; pev(pVictim, pev_takedamage, flTakeDamage);
    if (flTakeDamage == DAMAGE_NO) return false;

    static pOwner; pOwner = pev(this, pev_owner);
    if (pVictim == pOwner) return false;

    if (!UTIL_CanTakeDamage(pVictim, pOwner)) return false;
    if (!UTIL_IsMonster(pVictim) && (!IS_PLAYER(pVictim) || !is_user_alive(pVictim))) return false;
    if (UTIL_GetWeight(pVictim) > 1.0) return false;

    return true;
}

@Player_CastSpell(this) {
    new pSpellBall = UTIL_HwnSpawnPlayerSpellball(this, g_iSpellHandler, EffectColor, floatround(SpellballSpeed), g_szSprSpellBall, _, _, 10.0);
    if (!pSpellBall) return PLUGIN_HANDLED;

    CE_SetMember(pSpellBall, CE_MEMBER_NEXTKILL, get_gametime() + SpellballLifeTime);

    new Float:vecVelocity[3];
    pev(pSpellBall, pev_velocity, vecVelocity);
    set_pev(pSpellBall, pev_vuser1, vecVelocity);
    set_pev(pSpellBall, pev_groupinfo, 128);

    emit_sound(this, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    dllfunc(DLLFunc_Think, pSpellBall);

    return PLUGIN_CONTINUE;
}

@Base_FindLightningMaster(pEntity, &iIndex) {
    new iLightningBallsNum = ArraySize(g_irgLightningBalls);

    for (new i = 0; i < iLightningBallsNum; ++i) {
        new pLightningBall = ArrayGetCell(g_irgLightningBalls, i);
        new Array:irgpVictims = CE_GetMember(pLightningBall, m_irgpVictims);
        new iVictimsNum = ArraySize(irgpVictims);

        for (new j = 0; j < iVictimsNum; ++j) {
            new pVictim = ArrayGetCell(irgpVictims, j);
            
            if (pEntity == pVictim) {
                iIndex = j;
                return pLightningBall;
            }
        }
    }

    return 0;
}

@Base_ReleaseFromLightningMaster(this) {
    static iIndex;
    new pLightningBall = @Base_FindLightningMaster(this, iIndex);

    if (!pLightningBall) return;

    new Array:irgpVictims = CE_GetMember(pLightningBall, m_irgpVictims);
    ArrayDeleteItem(irgpVictims, iIndex);
}

@Base_ProcessLightningMasterThink(this) {
    static iIndex;
    new pLightningBall = @Base_FindLightningMaster(this, iIndex);

    if (!pLightningBall) return;

    @SpellBall_Magnetize(pLightningBall, this);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_OnFreeEntPrivateData(pEntity) {
    @Base_ReleaseFromLightningMaster(pEntity);
}

public FMHook_Think(pEntity) {
    if (!IS_PLAYER(pEntity)) {
        @Base_ProcessLightningMasterThink(pEntity);
    }
}

public HamHook_Player_PostThink(pPlayer) {
    if (is_user_alive(pPlayer)) {
        @Base_ProcessLightningMasterThink(pPlayer);
    }
}
