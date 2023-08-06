#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <hwn>
#include <hwn_utils>
#include <api_custom_entities>

#define PLUGIN "[Hwn] Objective Marks"
#define AUTHOR "Hedgehog Fog"

#define MARK_CLASSNAME "_mark"
#define SPRITE_WIDTH 128.0
#define SPRITE_HEIGHT 128.0
#define SPRITE_SCALE 0.05
#define SPRITE_AMT 120.0
#define MARK_UPDATE_DELAY 0.01
#define MARK_MAX_VELOCITY 250.0
#define MARK_MAX_MOVE_STEP_LENGTH 800.0
#define MARK_MAX_SCALE_STEP 0.25
#define MARK_MAX_SCALE_STEP_LENGTH 100.0
#define MAX_PLAYER_MARKS 16

enum _:Frame { TopLeft, TopRight, BottomLeft, BottomRight };

enum PlayerData {
    Float:Player_Origin[3],
    Float:Player_MarkOrigin[3],
    Float:Player_MarkAngles[3],
    Float:Player_MarkUpdateTime,
    Float:Player_MarkScale
}

new Array:g_irgMarks;
new g_iMarkModelIndex;
new g_rgPlayerData[MAX_PLAYERS + 1][MAX_PLAYER_MARKS][PlayerData];

new g_pCvarEnabled;

new g_iszInfoTargetClassname;

public plugin_precache() {
    g_irgMarks = ArrayCreate(_, MAX_PLAYER_MARKS);
    g_iMarkModelIndex = precache_model("sprites/hwn/mark_cauldron.spr");

    CE_RegisterHook(CEFunction_Init, "hwn_bucket", "@Bucket_Init");
    CE_RegisterHook(CEFunction_Remove, "hwn_bucket", "@Bucket_Remove");

    g_iszInfoTargetClassname = engfunc(EngFunc_AllocString, "info_target");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack", 0);
    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack_Post", 1);
    register_forward(FM_CheckVisibility, "OnCheckVisibility");

    g_pCvarEnabled = register_cvar("hwn_objective_marks", "1");
}

public plugin_end() {
    ArrayDestroy(g_irgMarks);
}

@Bucket_Init(this) {
    if (ArraySize(g_irgMarks) >= MAX_PLAYER_MARKS) {
        log_amx("WARNING: Objective marks limit reached!");
        return;
    }

    new pMark = CreateMark(this);
    set_pev(pMark, pev_iuser1, ArraySize(g_irgMarks));
    ArrayPushCell(g_irgMarks, pMark);
    CE_SetMember(this, "pMark", pMark);
}

@Bucket_Remove(this) {
    new pMark = CE_GetMember(this, "pMark");
    if (pMark) {
        set_pev(pMark, pev_flags, pev(pMark, pev_flags) | FL_KILLME);
        dllfunc(DLLFunc_Think, pMark);
    }
}

public HamHook_Player_Spawn_Post(pPlayer) {
    new iMarkCount = ArraySize(g_irgMarks);
    for (new iMarkIndex = 0; iMarkIndex < iMarkCount; ++iMarkIndex) {
        g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkUpdateTime] = 0.0;
    }
}

public FMHook_AddToFullPack(es, e, pEntity, pHost, pHostFlags, pPlayer, pSet) {
    if (!IS_PLAYER(pHost)) {
        return FMRES_IGNORED;
    }

    if (is_user_bot(pHost)) {
        return FMRES_IGNORED;
    }

    if (!pev_valid(pEntity)) {
        return FMRES_IGNORED;
    }

    static szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    if (!equal(szClassName, MARK_CLASSNAME)) {
        return FMRES_IGNORED;
    }

    if (get_pcvar_num(g_pCvarEnabled) <= 0) {
        return FMRES_SUPERCEDE;
    }

    if (!is_user_alive(pHost)) {
        return FMRES_SUPERCEDE;
    }

    new pBucket = pev(pEntity, pev_owner);
    new iBucketTeam = pev(pBucket, pev_team);
    if (iBucketTeam && iBucketTeam != get_member(pHost, m_iTeam)) {
        return FMRES_SUPERCEDE;
    }

    new iMarkIndex = pev(pEntity, pev_iuser1);
    
    new Float:flDelta = get_gametime() - g_rgPlayerData[pHost][iMarkIndex][Player_MarkUpdateTime];
    if (!g_rgPlayerData[pHost][iMarkIndex][Player_MarkUpdateTime] || flDelta >= MARK_UPDATE_DELAY) {
        CalculateMark(pEntity, pHost);
    }

    return FMRES_HANDLED;
}

public FMHook_AddToFullPack_Post(es, e, pEntity, pHost, pHostFlags, pPlayer, pSet) {
    if (!IS_PLAYER(pHost)) {
        return FMRES_IGNORED;
    }

    if (!is_user_alive(pHost)) {
        return FMRES_IGNORED;
    }

    if (!pev_valid(pEntity)) {
        return FMRES_IGNORED;
    }

    static szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    if (!equal(szClassName, MARK_CLASSNAME)) {
        return FMRES_IGNORED;
    }

    if (get_pcvar_num(g_pCvarEnabled) <= 0) {
        return FMRES_IGNORED;
    }

    if (Hwn_Collector_ObjectiveBlocked()) {
        return FMRES_IGNORED;
    }

    if (!Hwn_Collector_GetPlayerPoints(pHost)) {
        return FMRES_IGNORED;
    }

    new iMarkIndex = pev(pEntity, pev_iuser1);
    if (g_rgPlayerData[pHost][iMarkIndex][Player_MarkUpdateTime] > 0.0) {
        set_es(es, ES_Angles, g_rgPlayerData[pHost][iMarkIndex][Player_MarkAngles]);
        set_es(es, ES_Origin, g_rgPlayerData[pHost][iMarkIndex][Player_MarkOrigin]);
        set_es(es, ES_Scale, g_rgPlayerData[pHost][iMarkIndex][Player_MarkScale]);
    }

    return FMRES_HANDLED;
}

public OnCheckVisibility(pEntity) {
    if (!pev_valid(pEntity)) {
        return FMRES_IGNORED;
    }

    static szClassName[32];
    pev(pEntity, pev_classname, szClassName, charsmax(szClassName));

    if (!equal(szClassName, MARK_CLASSNAME)) {
        return FMRES_IGNORED;
    }

    forward_return(FMV_CELL, 1);
    return FMRES_SUPERCEDE;
}

CreateMark(pButton) {
    new pMark = engfunc(EngFunc_CreateNamedEntity, g_iszInfoTargetClassname);
    
    set_pev(pMark, pev_classname, MARK_CLASSNAME);
    set_pev(pMark, pev_scale, SPRITE_SCALE);
    set_pev(pMark, pev_modelindex, g_iMarkModelIndex);
    set_pev(pMark, pev_rendermode, kRenderTransAdd);
    set_pev(pMark, pev_renderamt, SPRITE_AMT);
    set_pev(pMark, pev_movetype, MOVETYPE_FLYMISSILE);
    set_pev(pMark, pev_solid, SOLID_NOT);
    set_pev(pMark, pev_spawnflags, SF_SPRITE_STARTON);
    set_pev(pMark, pev_owner, pButton);

    dllfunc(DLLFunc_Spawn, pMark);

    static Float:vecOrigin[3];
    ExecuteHam(Ham_BodyTarget, pButton, 0, vecOrigin);
    engfunc(EngFunc_SetOrigin, pMark, vecOrigin);

    return pMark;
}

CalculateMark(pMark, pPlayer) {
    new iMarkIndex = pev(pMark, pev_iuser1);
    new Float:flDelta = get_gametime() - g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkUpdateTime];

    static Float:vecOrigin[3];
    ExecuteHam(Ham_Player_GetGunPosition, pPlayer, vecOrigin);

    static Float:vecTarget[3];
    pev(pMark, pev_origin, vecTarget);

    // ANCHOR: Smooth movement
    if (g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkUpdateTime] > 0.0) {
        new Float:flMaxStep = MARK_MAX_VELOCITY * flDelta;
        new Float:flDirLen = xs_vec_distance(vecOrigin, g_rgPlayerData[pPlayer][iMarkIndex][Player_Origin]);

        if (flDirLen > flMaxStep && flDirLen < MARK_MAX_MOVE_STEP_LENGTH) {
            for (new i = 0; i < 3; ++i) {
                vecOrigin[i] = g_rgPlayerData[pPlayer][iMarkIndex][Player_Origin][i] + (((vecOrigin[i] - g_rgPlayerData[pPlayer][iMarkIndex][Player_Origin][i]) / flDirLen) * flMaxStep);
            }
        }
    }

    // ANCHOR: Caclulate angles
    static Float:vecDir[3];
    xs_vec_sub(vecTarget, vecOrigin, vecDir);

    static Float:vecAngles[3];
    xs_vec_normalize(vecDir, vecAngles);
    vector_to_angle(vecAngles, vecAngles);
    vecAngles[0] = -vecAngles[0];

    // ANCHOR: Calculate new pTarget
    static Float:vecForward[3];
    angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecForward);

    static Float:vecUp[3];
    angle_vector(vecAngles, ANGLEVECTOR_UP, vecUp);

    static Float:vecRight[3];
    angle_vector(vecAngles, ANGLEVECTOR_RIGHT, vecRight);

    static Float:rgvecFrameEnd[Frame][3];
    CreateFrame(vecTarget, SPRITE_WIDTH * SPRITE_SCALE, SPRITE_HEIGHT * SPRITE_SCALE, vecUp, vecRight, rgvecFrameEnd);
    TraceFrame(vecOrigin, rgvecFrameEnd, pPlayer, rgvecFrameEnd);

    for (new i = 0; i < 3; ++i) {
        vecTarget[i] = (rgvecFrameEnd[TopLeft][i] + rgvecFrameEnd[BottomRight][i]) * 0.5;
    }

    // ANCHOR: Calculate scale
    new Float:flScale = SPRITE_SCALE * (xs_vec_distance(vecOrigin, vecTarget) / 100);
    
    // ANCHOR: Smooth scale
    if (g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkUpdateTime] > 0.0) {
        new Float:flLastDistance = xs_vec_distance(g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkOrigin], g_rgPlayerData[pPlayer][iMarkIndex][Player_Origin]);
        new Float:flDistance = xs_vec_distance(vecTarget, vecOrigin);

        if (floatabs(flLastDistance - flDistance) < MARK_MAX_SCALE_STEP_LENGTH) {
            new Float:flScaleRatio = flScale / g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkScale];
            new Float:flMaxStep = 1 + ((MARK_MAX_SCALE_STEP / g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkScale]) * flDelta);

            if (flScaleRatio > flMaxStep) {
                flScale = g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkScale] * flMaxStep;
            } else if (flScaleRatio < (1.0 / flMaxStep)) {
                flScale = g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkScale] * (1.0 / flMaxStep);
            }
        } else {
            flScale = 0.005;
        }
    }

    // ANCHOR: Fix frame position using scale
    CreateFrame(vecTarget, SPRITE_WIDTH * flScale, SPRITE_HEIGHT * flScale, vecUp, vecRight, rgvecFrameEnd);
    for (new i = 0; i < Frame; ++i) {
        for (new j = 0; j < 3; ++j) {
            rgvecFrameEnd[i][j] -= (vecForward[j] * ((SPRITE_WIDTH * flScale) / 2.0));
        }
    }

    // ANCHOR: Get pTarget point
    for (new i = 0; i < 3; ++i) {
        vecTarget[i] = (rgvecFrameEnd[TopLeft][i] + rgvecFrameEnd[BottomRight][i]) * 0.5;
    }

    xs_vec_copy(vecOrigin, g_rgPlayerData[pPlayer][iMarkIndex][Player_Origin]);
    xs_vec_copy(vecTarget, g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkOrigin]);
    xs_vec_copy(vecAngles, g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkAngles]);
    g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkScale] = flScale;
    g_rgPlayerData[pPlayer][iMarkIndex][Player_MarkUpdateTime] = get_gametime();
}

CreateFrame(const Float:vecOrigin[3], Float:flWidth, Float:flHeight, const Float:vecUp[3], const Float:vecRight[3], Float:rgvecFrameOut[Frame][3]) {
    new Float:flHalfWidth = flWidth / 2.0;
    new Float:flHalfHeight = flHeight / 2.0;

    for (new i = 0; i < 3; ++i) {
        rgvecFrameOut[TopLeft][i] = vecOrigin[i] + (vecRight[i] * -flHalfWidth) +    (vecUp[i] * flHalfHeight);
        rgvecFrameOut[TopRight][i] = vecOrigin[i] + (vecRight[i] * flHalfWidth) + (vecUp[i] * flHalfHeight);
        rgvecFrameOut[BottomLeft][i] = vecOrigin[i] + (vecRight[i] * -flHalfWidth) + (vecUp[i] * -flHalfHeight);
        rgvecFrameOut[BottomRight][i] = vecOrigin[i] + (vecRight[i] * flHalfWidth) + (vecUp[i] * -flHalfHeight);
    }
}

Float:TraceFrame(const Float:vecSrc[3], const Float:rgvecFrame[Frame][3], pIgnore, Float:rgvecFrameOut[Frame][3]) {
    new pTr = create_tr2();

    new Float:flMinFraction = 1.0;

    for (new i = 0; i < Frame; ++i) {
        engfunc(EngFunc_TraceLine, vecSrc, rgvecFrame[i], IGNORE_GLASS | IGNORE_MONSTERS, pIgnore, pTr);

        static Float:flFraction;
        get_tr2(pTr, TR_flFraction, flFraction);

        if (flFraction < flMinFraction) {
            flMinFraction = flFraction;
        }
    }

    free_tr2(pTr);

    if (flMinFraction < 1.0) {
        for (new i = 0; i < Frame; ++i) {
            for (new j = 0; j < 3; ++j) {
                rgvecFrameOut[i][j] = vecSrc[j] + ((rgvecFrame[i][j] - vecSrc[j]) * flMinFraction);
            }
        }
    }

    return flMinFraction;
}
