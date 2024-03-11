#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_advanced_pushing>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Entity] Hwn Lightning"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_projectile_lightning"

#define m_iSpell "iSpell"
#define m_irgpVictims "irgpVictims"
#define m_flSpellNextVictimsUpdate "flSpellNextVictimsUpdate"
#define m_flSpellNextDamage "flSpellNextDamage"
#define m_flSpellNextEffect "flSpellNextEffect"

const Float:ProjectileMagnetism = 320.0;
const Float:ProjectileDamage = 30.0;
const Float:ProjectileDamageDelay = 0.5;
const Float:ProjectileLightningDelay = 0.1;
const Float:ProjectileRadius = 96.0;
const Float:ProjectileDamageRadiusMultiplier = 0.75;
const Float:ProjectileImpactRadiusMultiplier = 0.5;
new const ProjectileColor[3] = {32, 128, 192};
new const Float:ProjectileColorF[3] = {32.0, 128.0, 192.0};

new const g_szEffectModel[] = "sprites/flare6.spr";
new const g_szDetonateSound[] = "hwn/spells/spell_lightning_impact.wav";

new g_iEffectModelIndex;

new Array:g_irgLightningBalls;

public plugin_precache() {
    g_irgLightningBalls = ArrayCreate();

    g_iEffectModelIndex = precache_model("sprites/lgtning.spr");
    precache_model(g_szEffectModel);

    precache_sound(g_szDetonateSound);
    
    CE_RegisterDerived(ENTITY_NAME, "hwn_projectile_magicball");

    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Kill, "@Entity_Kill");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");

    CE_RegisterMethod(ENTITY_NAME, "Launch", "@Entity_Launch", CE_MP_FloatArray, 3);
    CE_RegisterMethod(ENTITY_NAME, "Detonate", "@Entity_Detonate", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, "TouchKill", "@Entity_TouchKill", CE_MP_Cell);
    CE_RegisterMethod(ENTITY_NAME, "StopKill", "@Entity_StopKill");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_forward(FM_OnFreeEntPrivateData, "FMHook_OnFreeEntPrivateData");
    register_forward(FM_Think, "FMHook_Think", ._post = 1);

    RegisterHamPlayer(Ham_Player_PostThink, "HamHook_Player_PostThink", .Post = 1);
}

public plugin_end() {
    ArrayDestroy(g_irgLightningBalls);
}

@Entity_Init(this) {
    CE_SetMember(this, m_irgpVictims, ArrayCreate());
    CE_SetMember(this, CE_MEMBER_LIFETIME, 5.0);

    ArrayPushCell(g_irgLightningBalls, this);
}

@Entity_Spawned(this) {
    // set_pev(this, pev_rendercolor, DetonateColor);
    CE_CallMethod(this, "SpawnEffect", g_szEffectModel, ProjectileColorF, 255.0, 0.75, 10.0);
}

@Entity_Kill(this, pKiller) {
    CE_CallMethod(this, "Detonate", pKiller);
}

@Entity_Remove(this) {
    new Array:irgpVictims = CE_GetMember(this, m_irgpVictims);
    ArrayDestroy(irgpVictims);

    new iGlobalId = ArrayFindValue(g_irgLightningBalls, this);
    if (iGlobalId != -1) {
        ArrayDeleteItem(g_irgLightningBalls, iGlobalId);
    }
}

@Entity_Think(this) {
    static Float:flGameTime; flGameTime = get_gametime();

    static Float:flSpellNextVictimsUpdate; flSpellNextVictimsUpdate = CE_GetMember(this, m_flSpellNextVictimsUpdate);
    if (flSpellNextVictimsUpdate <= flGameTime) {
        @Entity_UpdateVictims(this);
        CE_SetMember(this, m_flSpellNextVictimsUpdate, flGameTime + 0.1);
    }

    static Float:flSpellNextDamage; flSpellNextDamage = CE_GetMember(this, m_flSpellNextDamage);
    if (flSpellNextDamage <= flGameTime) {
        @Entity_RadiusDamage(this, false);
        emit_sound(this, CHAN_BODY, g_szDetonateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
        CE_SetMember(this, m_flSpellNextDamage, flGameTime + ProjectileDamageDelay);
    }

    static Float:flSpellNextEffect; flSpellNextEffect = CE_GetMember(this, m_flSpellNextEffect);
    if (flSpellNextEffect <= flGameTime) {
        for (new i = 0; i < 4; ++i) @Entity_DrawLightingBeam(this);
        CE_SetMember(this, m_flSpellNextEffect, flGameTime + ProjectileLightningDelay);
    }

    // Update velocity
    static Float:vecVelocity[3];
    CE_GetMemberVec(this, "vecVelocity", vecVelocity);
    set_pev(this, pev_velocity, vecVelocity);
}

@Entity_Launch(this, const Float:vecVelocity[3]) {
    CE_CallBaseMethod(vecVelocity);
    CE_SetMemberVec(this, "vecVelocity", vecVelocity);
}

@Entity_TouchKill(this, pDetonator) {}
@Entity_StopKill(this, pDetonator) {}

@Entity_Detonate(this, pDetonator) {
    @Entity_RadiusDamage(this, true);
    @Entity_DetonateEffect(this);

    CE_CallBaseMethod(pDetonator);
}

bool:@Entity_Magnetize(this, pTarget) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecTargetOrigin[3]; pev(pTarget, pev_origin, vecTargetOrigin);
    static Float:flDistance; flDistance = get_distance_f(vecOrigin, vecTargetOrigin);

    if (flDistance > ProjectileRadius) return false;

    if (flDistance > ProjectileRadius * ProjectileImpactRadiusMultiplier) {
        APS_PushFromOrigin(pTarget, -ProjectileMagnetism, vecOrigin);
    } else {
        static Float:vecVelocity[3];
        pev(this, pev_velocity, vecVelocity);
        set_pev(pTarget, pev_velocity, vecVelocity);
    }

    return true;
}

@Entity_UpdateVictims(this) {
    static Array:irgpVictims; irgpVictims = CE_GetMember(this, m_irgpVictims);
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    ArrayClear(irgpVictims);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, ProjectileRadius)) > 0) {
        if (@Entity_IsValidVictim(this, pTarget)) {
            ArrayPushCell(irgpVictims, pTarget);
        }
    }
}

@Entity_RadiusDamage(this, bool:bPush) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static pOwner; pOwner = pev(this, pev_owner);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, ProjectileRadius)) != 0) {
        if (@Entity_IsValidVictim(this, pTarget)) {
            if (bPush) {
                if (IS_PLAYER(pTarget) || pev(pTarget, pev_flags) & FL_MONSTER) {
                    APS_PushFromOrigin(pTarget, ProjectileMagnetism, vecOrigin);
                }
            }

            static Float:vecTargetOrigin[3]; pev(pTarget, pev_origin, vecTargetOrigin);
            static Float:flDamage; flDamage = UTIL_CalculateRadiusDamage(vecOrigin, vecTargetOrigin, ProjectileRadius * ProjectileDamageRadiusMultiplier, ProjectileDamage, false, pTarget);

            ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, flDamage, DMG_SHOCK);
        }
    }
}

@Entity_DrawLightingBeam(this) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);

    // Generate random offset
    static Float:vecTarget[3];
    for (new i = 0; i < 3; ++i) vecTarget[i] = random_float(-16.0, 16.0);

    xs_vec_normalize(vecTarget, vecTarget);
    xs_vec_add_scaled(vecOrigin, vecTarget, ProjectileRadius, vecTarget);

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
    write_byte(ProjectileColor[0]);
    write_byte(ProjectileColor[1]);
    write_byte(ProjectileColor[2]);
    write_byte(100);
    write_byte(100);
    message_end();
}

@Entity_DetonateEffect(this) {
    new Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    UTIL_Message_BeamCylinder(vecOrigin, ProjectileRadius * 3, g_iEffectModelIndex, 0, 3, 32, 255, ProjectileColor, 100, 0);
    emit_sound(this, CHAN_BODY, g_szDetonateSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

@Entity_IsValidVictim(this, pVictim) {
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

@Base_FindLightningMaster(this, &iIndex) {
    new iLightningBallsNum = ArraySize(g_irgLightningBalls);

    for (new i = 0; i < iLightningBallsNum; ++i) {
        new pLightningBall = ArrayGetCell(g_irgLightningBalls, i);
        new Array:irgpVictims = CE_GetMember(pLightningBall, m_irgpVictims);
        new iVictimsNum = ArraySize(irgpVictims);

        for (new j = 0; j < iVictimsNum; ++j) {
            new pVictim = ArrayGetCell(irgpVictims, j);
            
            if (this == pVictim) {
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

    @Entity_Magnetize(pLightningBall, this);
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
