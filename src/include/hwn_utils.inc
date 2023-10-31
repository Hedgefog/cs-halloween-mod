#if defined _hwn_utils_included
  #endinput
#endif
#define _hwn_utils_included

#include <reapi>

#define IS_PLAYER(%1) (%1 >= 1 && %1 <= MaxClients)

#define MENU_CHOOSEAPPEARANCE 3
#define JOIN_CHOOSEAPPEARANCE 4

#define GRAVITATIONAL_ACCELERATION_EARTH 9.807
#define GRAVITATIONAL_ACCELERATION_MOON 1.62
#define MOON_GRAVIY GRAVITATIONAL_ACCELERATION_MOON / GRAVITATIONAL_ACCELERATION_EARTH

#define HUD_HIDE_TIMER (1<<4)

stock Float:UTIL_FpsToDelay(iFps) {
    return iFps > 0 ? ((100.0 / iFps) / 100.0) : 0.0;
}

stock Float:UTIL_CalculateRadiusDamage(
    const Float:vecOrigin1[3],
    const Float:vecOrigin2[3],
    Float:flRadius,
    Float:flMaxDamage,
    bool:bIgnoreObstacles = false,
    pIgnoreEnt = 0
) {
    if (!bIgnoreObstacles && !UTIL_IsPointVisible(vecOrigin1, vecOrigin2, pIgnoreEnt)) {
        return 0.0;
    }

    new Float:flDistance = get_distance_f(vecOrigin1, vecOrigin2);
    new Float:flMultiplier = floatclamp((1.0 - ((flDistance - flRadius) / flRadius)), 0.0, 1.0);
    new Float:flDamage = flMaxDamage * flMultiplier;

    return flDamage;
}

stock bool:UTIL_IsInvisible(pEntity) {
    if (!pev_valid(pEntity)) {
        return false;
    }

    if (pev(pEntity, pev_rendermode) == kRenderNormal) {
        return false;
    }

    new Float:flRenderAmt;
    pev(pEntity, pev_renderamt, flRenderAmt);

    return (flRenderAmt < 50.0);
}

stock bool:UTIL_IsMonster(pEntity) {
    return !!(pev(pEntity, pev_flags) & FL_MONSTER);
}

stock bool:UTIL_IsTeammate(pEntity, iTeam) {
    new iTargetTeam = IS_PLAYER(pEntity) ? get_member(pEntity, m_iTeam) : pev(pEntity, pev_team);
    return iTeam == iTargetTeam;
}

stock bool:UTIL_CanTakeDamage(pEntity, pAttacker) {
    new iAttackerTeam = get_member(pAttacker, m_iTeam);

    if (IS_PLAYER(pEntity)) {
        if (!rg_is_player_can_takedamage(pEntity, pAttacker)) {
            return false;
        }
    } else {
        new pOwner = pev(pEntity, pev_owner);
        if (pOwner == pAttacker) {
            return false;
        }

        if (IS_PLAYER(pOwner)) {
            if (!rg_is_player_can_takedamage(pOwner, pAttacker)) {
                return false;
            }
        } else {
            if (pev(pEntity, pev_team) == iAttackerTeam) {
                return false;
            }
        }
    }

    return true;
}

stock Float:UTIL_GetDistanceToFloor(pEntity, const Float:vecOrigin[3]) {
    static Float:vecTarget[3];
    xs_vec_copy(vecOrigin, vecTarget);
    vecTarget[2] -= 8192.0;

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceMonsterHull, pEntity, vecOrigin, vecTarget, IGNORE_MONSTERS, pEntity, pTrace);

    static Float:flFraction;
    get_tr2(pTrace, TR_flFraction, flFraction);
    
    if (flFraction == 1.0) {
        return -1.0;
    }

    static Float:vecEnd[3];
    get_tr2(pTrace, TR_vecEndPos, vecEnd);

    free_tr2(pTrace);

    return vecOrigin[2] - vecEnd[2];
}

stock bool:UTIL_IsPointVisible(const Float:vecOrigin1[3], const Float:vecOrigin2[3], pIgnoreEnt = 0) {
    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecOrigin1, vecOrigin2, IGNORE_MONSTERS, pIgnoreEnt, pTrace);

    static Float:flFraction;
    get_tr2(pTrace, TR_flFraction, flFraction);

    free_tr2(pTrace);

    return flFraction == 1.0;
}

stock bool:UTIL_SetSequence(pEntity, iSequence) {
    if (pev(pEntity, pev_sequence) == iSequence) {
        return false;
    }

    set_pev(pEntity, pev_frame, 0);
    set_pev(pEntity, pev_framerate, 1.0);
    set_pev(pEntity, pev_animtime, get_gametime());
    set_pev(pEntity, pev_sequence, iSequence);

    return true;
}

stock UTIL_GetDirectionVector(pEntity, Float:vecOut[3], Float:flLength = 1.0) {
    new Float:vecAngles[3];
    pev(pEntity, pev_angles, vecAngles);
    angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecOut);
    xs_vec_normalize(vecOut, vecOut);
    xs_vec_mul_scalar(vecOut, flLength, vecOut);
    vecOut[2] = -vecOut[2];
}

stock bool:UTIL_IsTraceOpen(pTrace) {   
    if (get_tr2(pTrace, TR_AllSolid)) {
        return false;
    }

    if (get_tr2(pTrace, TR_StartSolid)) {
        return false;
    }

    new Float:flFraction;
    get_tr2(pTrace, TR_flFraction, flFraction);

    if (flFraction < 1.0) {
        return false;
    }

    return true;
}

stock bool:UTIL_IsOpen(const Float:vecOrigin1[3], const Float:vecOrigin2[3], pEntity = 0, iIgnoreFlags = IGNORE_MONSTERS) {
    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecOrigin1, vecOrigin2, iIgnoreFlags, pEntity, pTrace);
    new bool:isOpen = UTIL_IsTraceOpen(pTrace);
    free_tr2(pTrace);

    return isOpen;
}

stock bool:UTIL_TurnTo(pEntity, const Float:vecTarget[3], const bool:rgbLockAxis[3] = {true, false, false}, const Float:flSpeed = -1.0) {
    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new Float:vecAngles[3];
    pev(pEntity, pev_angles, vecAngles);

    static Float:vecTargetAngles[3];
    xs_vec_sub(vecTarget, vecOrigin, vecTargetAngles);
    engfunc(EngFunc_VecToAngles, vecTargetAngles, vecTargetAngles);

    static Float:vecNewAngles[3];
    for (new i = 0; i < 3; ++i) {
        if (rgbLockAxis[i]) {
            vecNewAngles[i] = vecAngles[i];
        } else if (flSpeed >= 0.0) {
            vecNewAngles[i] = ApproachAngle(vecTargetAngles[i], vecAngles[i], flSpeed);
        } else {
            vecNewAngles[i] = vecTargetAngles[i];
        }
    }

    static Float:vecViewAngles[3];
    xs_vec_copy(vecNewAngles, vecViewAngles);
    vecViewAngles[0] = -vecViewAngles[0];

    set_pev(pEntity, pev_angles, vecNewAngles);
    set_pev(pEntity, pev_v_angle, vecViewAngles);
    set_pev(pEntity, pev_ideal_yaw, vecNewAngles[1]);

    return true;
}

stock UTIL_Message_BloodSprite(const Float:vecOrigin[3], iBloodSprayModelIndex, iBloodModelIndex, iColor, iScale) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BLOODSPRITE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(iBloodSprayModelIndex);
    write_short(iBloodModelIndex);
    write_byte(iColor);
    write_byte(iScale);
    message_end();
}

stock UTIL_Message_BreakModel(
    const Float:vecOrigin[3],
    const Float:vecSize[3] = {16.0, 16.0, 16.0},
    const Float:vecVelocity[3] = {0.0, 0.0, 0.0},
    iSpeedNoise = 0,
    iModelIndex = 0,
    iCount = 4,
    iLifeTime = 1,
    iFlags = 0
) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BREAKMODEL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, vecSize[0]);
    engfunc(EngFunc_WriteCoord, vecSize[1]);
    engfunc(EngFunc_WriteCoord, vecSize[2]);
    engfunc(EngFunc_WriteCoord, vecVelocity[0]);
    engfunc(EngFunc_WriteCoord, vecVelocity[1]);
    engfunc(EngFunc_WriteCoord, vecVelocity[2]);
    write_byte(iSpeedNoise);
    write_short(iModelIndex);
    write_byte(iCount);
    write_byte(iLifeTime);
    write_byte(iFlags);
    message_end();
}

stock UTIL_Message_ExplodeModel(
    const Float:vecOrigin[3],
    const Float:flVelocity = 0.0,
    iModelIndex = 0,
    iCount = 4,
    iLifeTime = 1
) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_EXPLODEMODEL);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, flVelocity);
    write_short(iModelIndex);
    write_short(iCount);
    write_byte(iLifeTime);
    message_end();
}

stock UTIL_Message_Dlight(
    const Float:vecOrigin[3],
    iRadius = 16,
    const iColor[3] = {255, 255, 255},
    iLifeTime = 1,
    iDecayRate = 0
) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_DLIGHT);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_byte(iRadius);
    write_byte(iColor[0]);
    write_byte(iColor[1]);
    write_byte(iColor[2]);
    write_byte(iLifeTime);
    write_byte(iDecayRate);
    message_end();
}

stock UTIL_Message_FireField(const Float:vecOrigin[3], iRadius, iModelIndex, iCount, iFlags, iLifeTime) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_FIREFIELD);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(iRadius);
    write_short(iModelIndex);
    write_byte(iCount);
    write_byte(iFlags);
    write_byte(iLifeTime);
    message_end();
}

stock UTIL_RandomVector(Float:flMin, Float:flMax, Float:vecOut[3]) {
    for (new i = 0; i < 3; ++i) {
        vecOut[i] = random_float(flMin, flMax);
    }
}

stock UTIL_FindUsersNearby(pStartPlayer = 0, Float:vecOrigin[3], Float:flDistance, iTeam = 0, bool:bAlive = true) {
    for (new pPlayer = pStartPlayer + 1; pPlayer <= MaxClients; ++pPlayer)
    {
        if (!is_user_connected(pPlayer)) {
            continue;
        }

        if (bAlive && !is_user_alive(pPlayer)) {
            continue;
        }

        if (iTeam && iTeam != get_member(pPlayer, m_iTeam)) {
            continue;
        }

        static Float:vecUserOrigin[3];
        pev(pPlayer, pev_origin, vecUserOrigin);

        if (get_distance_f(vecOrigin, vecUserOrigin) > flDistance) {
            continue;
        }

        return pPlayer;
    }

    return 0;
}

stock UTIL_FixedUnsigned16(const Float:flValue, const iScale) {
    return clamp(floatround(flValue * iScale), 0, 0xFFFF);
}

stock UTIL_SetPlayerTeamChange(pPlayer, bool: bValue) {
    new iCurrentValue = get_pdata_int(pPlayer, 125, 5);

    if (bValue) {
        set_pdata_int(pPlayer, 125, iCurrentValue &  ~(1<<8), 5);
    } else {
        set_pdata_int(pPlayer, 125, iCurrentValue | (1<<8), 5);
    }
}

stock UTIL_FindEntityNearby(startEnt = 0, const Float:vecOrigin[3], const Float:flRadius) {
    new pTarget = engfunc(EngFunc_FindEntityInSphere, startEnt, vecOrigin, flRadius);
    if (pTarget <= startEnt) {
        return 0; // infinite loop fix
    }

    if (!pev_valid(pTarget)) {
        return 0;
    }

    return pTarget;
}

stock bool:UTIL_FindPlaceToTeleport(pEntity, const Float:vecTarget[3], Float:vecOut[3], iHull = HULL_POINT, iIgnoreFlags = DONT_IGNORE_MONSTERS) {
    static Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    static Float:vecMaxs[3];
    pev(pEntity, pev_maxs, vecMaxs);

    if (UTIL_IsOpenHull(vecTarget, iHull, pEntity, iIgnoreFlags)) {
        xs_vec_copy(vecTarget, vecOut);
        return true;
    }

    static const Float:vecDirections[][3] = {
        { 1.0, 0.0, 0.0 },
        { 0.0, 1.0, 0.0 },
        { 0.0, 0.0, 1.0 },
        { 1.0, 1.0, 0.0 },
        { 0.0, 1.0, 1.0 },
        { 1.0, 0.0, 1.0 },
        { 1.0, 1.0, 1.0 }
    };
    
    new iDirectionsNum = sizeof(vecDirections);

    for (new i = 0; i < iDirectionsNum; ++i) {
        static Float:vecNewTarget[3];
        xs_vec_copy(vecTarget, vecNewTarget);

        for (new j = 0; j < 3; ++j) {
            vecNewTarget[j] = vecTarget[j] + (vecMins[j] * vecDirections[i][j]);
        }

        if (UTIL_IsOpenHull(vecNewTarget, iHull, pEntity, iIgnoreFlags)) {
            xs_vec_copy(vecNewTarget, vecOut);
            return true;
        }

        for (new j = 0; j < 3; ++j) {
            vecNewTarget[j] = vecTarget[j] + (vecMaxs[j] * vecDirections[i][j]);
        }

        if (UTIL_IsOpenHull(vecNewTarget, iHull, pEntity, iIgnoreFlags)) {
            xs_vec_copy(vecNewTarget, vecOut);
            return true;
        }
    }

    return false;
}

stock bool:UTIL_IsOpenHull(const Float:vecOrigin[3], iHull, pIgnoreEnt = 0, iIgnoreFlags = DONT_IGNORE_MONSTERS) {
    new pTrace = create_tr2();
    engfunc(EngFunc_TraceHull, vecOrigin, vecOrigin, iIgnoreFlags, iHull, pIgnoreEnt, pTrace);
    new bool:bIsVacant = !!get_tr2(pTrace, TR_InOpen);
    free_tr2(pTrace);

    return bIsVacant;
}

stock UTIL_GetViewOrigin(pPlayer, Float:vecOut[3]) {
    static Float:vecStart[3];
    pev(pPlayer, pev_origin, vecStart);

    static Float:vecViewOfs[3];
    pev(pPlayer, pev_view_ofs, vecViewOfs);

    xs_vec_copy(vecStart, vecOut);
    vecOut[2] += vecViewOfs[2];
}

stock bool:UTIL_IsStuck(pEntity) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceMonsterHull, pEntity, vecOrigin, vecOrigin, DONT_IGNORE_MONSTERS, pEntity, pTrace);
    new bool:bIsStuck = !get_tr2(pTrace, TR_InOpen);
    free_tr2(pTrace);

    return bIsStuck;
}

stock UTIL_Message_StatusIcon(pPlayer, iStatus = 0, const szIcon[], const iColor[3]) {
    static iMsgId = 0;
    if(!iMsgId) {
        iMsgId = get_user_msgid("StatusIcon");
    }

    message_begin(pPlayer ? MSG_ONE : MSG_ALL, iMsgId, _, pPlayer);
    write_byte(iStatus);
    write_string(szIcon);

    if (iStatus) {
        write_byte(iColor[0]);
        write_byte(iColor[1]);
        write_byte(iColor[2]);
    }

    message_end();
}

stock UTIL_Message_HideWeapon(pPlayer, iFlags) {
    static iMsgId = 0;
    if(!iMsgId) {
        iMsgId = get_user_msgid("HideWeapon");
    }

    message_begin(pPlayer ? MSG_ONE : MSG_ALL, iMsgId, _, pPlayer);
    write_byte(iFlags);
    message_end();
}

stock UTIL_Message_StreakSplash(const Float:vecOrigin[3], const Float:vecDirection[3], iColor, iCount, iSpeed, iSpeedNoise = 0) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, vecDirection[0]);
    engfunc(EngFunc_WriteCoord, vecDirection[1]);
    engfunc(EngFunc_WriteCoord, vecDirection[2]);
    write_byte(iColor);
    write_short(iCount);
    write_short(iSpeed);
    write_short(iSpeedNoise);
    message_end();
}

stock UTIL_Message_UserTracer(const Float:vecOrigin[3], const Float:vecDirection[3], iLifeTime, iColor, iLength) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_USERTRACER);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, vecDirection[0]);
    engfunc(EngFunc_WriteCoord, vecDirection[1]);
    engfunc(EngFunc_WriteCoord, vecDirection[2]);
    write_byte(iLifeTime);
    write_byte(iColor);
    write_byte(iLength);
    message_end();
}

stock UTIL_Message_Sound(const Float:vecOrigin[3], const szSound[], Float:flVolume = VOL_NORM, Float:flAttn = ATTN_NORM, iFlags = 0, pitch = PITCH_NORM, pEntity = 0) {
    new iSoundIndex = engfunc(EngFunc_PrecacheSound, szSound);

    engfunc(EngFunc_MessageBegin, MSG_ALL, SVC_SPAWNSTATICSOUND, vecOrigin, 0);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(iSoundIndex);
    write_byte(floatround(flVolume * 255));
    write_byte(floatround(flAttn * 64));
    write_short(pEntity);
    write_byte(pitch);
    write_byte(iFlags);
    message_end();
}

stock UTIL_Message_BeamCylinder(
    const Float:vecOrigin[3],
    Float:flRadius,
    iModelIndex = 0,
    iStartFrame = 0,
    iLifeTime = 1,
    iWidth = 0,
    iNoise = 0,
    const iColor[3] = {255, 255, 255},
    iBrightness = 255,
    iSpeed = 255
) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BEAMCYLINDER);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, vecOrigin[2] + flRadius);
    write_short(iModelIndex);
    write_byte(iStartFrame);
    write_byte(0);
    write_byte(iLifeTime);
    write_byte(iWidth);
    write_byte(iNoise);
    write_byte(iColor[0]);
    write_byte(iColor[1]);
    write_byte(iColor[2]);
    write_byte(iBrightness);
    write_byte(iSpeed);
    message_end();
}

stock UTIL_Message_BeamTorus(
    const Float:vecOrigin[3],
    Float:flRadius,
    iModelIndex = 0,
    iStartFrame = 0,
    iLifeTime = 1,
    iWidth = 0,
    iNoise = 0,
    const iColor[3] = {255, 255, 255},
    iBrightness = 255,
    iSpeed = 255
) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BEAMTORUS);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, vecOrigin[2] + flRadius);
    write_short(iModelIndex);
    write_byte(iStartFrame);
    write_byte(0);
    write_byte(iLifeTime);
    write_byte(iWidth);
    write_byte(iNoise);
    write_byte(iColor[0]);
    write_byte(iColor[1]);
    write_byte(iColor[2]);
    write_byte(iBrightness);
    write_byte(iSpeed);
    message_end();
}

stock UTIL_Message_BeamDisk(
    const Float:vecOrigin[3],
    Float:flRadius,
    iModelIndex = 0,
    iStartFrame = 0,
    iLifeTime = 1,
    iWidth = 0,
    iNoise = 0,
    const iColor[3] = {255, 255, 255},
    iBrightness = 255,
    iSpeed = 255
) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BEAMDISK);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, vecOrigin[2] + flRadius);
    write_short(iModelIndex);
    write_byte(iStartFrame);
    write_byte(0);
    write_byte(iLifeTime);
    write_byte(iWidth);
    write_byte(iNoise);
    write_byte(iColor[0]);
    write_byte(iColor[1]);
    write_byte(iColor[2]);
    write_byte(iBrightness);
    write_byte(iSpeed);
    message_end();
}

stock UTIL_Message_BeamEnts(
    pStartEnt,
    pEndEnt,
    iModelIndex,
    iStartFrame = 0,
    iFrameRate = 0,
    iLifeTime = 1,
    iWidth = 0,
    iNoise = 0,
    const iColor[3] = {255, 255, 255},
    iBrightness = 255,
    iSpeed = 0
) {
    static Float:vecOrigin[3];
    pev(pStartEnt, pev_origin, vecOrigin);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BEAMENTS);
    write_short(pStartEnt);
    write_short(pEndEnt);
    write_short(iModelIndex);
    write_byte(iStartFrame);
    write_byte(iFrameRate);
    write_byte(iLifeTime);
    write_byte(iWidth);
    write_byte(iNoise);
    write_byte(iColor[0]);
    write_byte(iColor[1]);
    write_byte(iColor[2]);
    write_byte(iBrightness);
    write_byte(iSpeed);
    message_end();
}

stock UTIL_Message_ParticleBurst(const Float:vecOrigin[3], iRadius, iColor, iLifeTime = 1) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_PARTICLEBURST);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(iRadius);
    write_byte(iColor);
    write_byte(iLifeTime);
    message_end();
}

stock UTIL_Message_Blood(const Float:vecOrigin[3], const Float:vecDirection[3], iColor = 0, iSpeed = 255) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_BLOOD);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, vecDirection[0]);
    engfunc(EngFunc_WriteCoord, vecDirection[1]);
    engfunc(EngFunc_WriteCoord, vecDirection[2]);
    write_byte(iColor);
    write_byte(iSpeed);
    message_end();
}

stock UTIL_Message_Sprite(const Float:vecOrigin[3], iModelIndex, iScale, alpha) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SPRITE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(iModelIndex);
    write_byte(iScale);
    write_byte(alpha);
    message_end();
}

stock UTIL_Message_Sparks(const Float:vecOrigin[3]) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SPARKS);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    message_end();
}

stock UTIL_Message_SpriteTrail(const Float:vecStart[3], const Float:vecEnd[3], iModelIndex, iCount, iLifeTime, iScale, iSpeed, iNoise) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecStart, 0);
    write_byte(TE_SPRITETRAIL);
    engfunc(EngFunc_WriteCoord, vecStart[0]);
    engfunc(EngFunc_WriteCoord, vecStart[1]);
    engfunc(EngFunc_WriteCoord, vecStart[2]);
    engfunc(EngFunc_WriteCoord, vecEnd[0]);
    engfunc(EngFunc_WriteCoord, vecEnd[1]);
    engfunc(EngFunc_WriteCoord, vecEnd[2]);
    write_short(iModelIndex);
    write_byte(iCount);
    write_byte(iLifeTime);
    write_byte(iScale);
    write_byte(iSpeed);
    write_byte(iNoise);
    message_end();
}

stock UTILS_Message_Projectile(const Float:vecOrigin[3], const Float:vecVelocity[3], iModelIndex, iLifeTime, pOwner) {
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_PROJECTILE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    engfunc(EngFunc_WriteCoord, vecVelocity[0]);
    engfunc(EngFunc_WriteCoord, vecVelocity[1]);
    engfunc(EngFunc_WriteCoord, vecVelocity[2]);
    write_short(iModelIndex);
    write_byte(iLifeTime);
    write_byte(pOwner);
    message_end();
}

stock UTIL_CreateDictKey(const szName[], const szPrefix[] = "", szOut[], iLen) {
    copy(szOut, iLen, szName);
    strtoupper(szOut);
    replace_all(szOut, iLen, " ", "_");
    format(szOut, iLen, "%s%s", szPrefix, szOut);
}

stock bool:UTIL_IsLocalizationExists(const szKey[]) {
    new szBuffer[16];
    format(szBuffer, charsmax(szBuffer), "%L", LANG_SERVER, szKey);

    new szNotFound[] = "ML_NOTFOUND:";

    return !equali(szBuffer, szNotFound, sizeof(szNotFound) - 1);
}

stock UTIL_PushFromOrigin(const Float:vecOrigin[3], pEntity, Float:flImpulse, const bool:rgbLockAxis[3] = {false, false, false}) {
    static Float:vecTargetOrigin[3];
    pev(pEntity, pev_origin, vecTargetOrigin);

    static Float:vecVelocity[3];
    xs_vec_sub(vecTargetOrigin, vecOrigin, vecVelocity);

    for (new i = 0; i < 3; ++i) {
        if (rgbLockAxis[i]) {
            vecVelocity[i] = 0.0;
        }
    }

    xs_vec_normalize(vecVelocity, vecVelocity);
    xs_vec_mul_scalar(vecVelocity, flImpulse, vecVelocity);

    static Float:vecTargetVelocity[3];
    pev(pEntity, pev_velocity, vecTargetVelocity);
    xs_vec_add(vecTargetVelocity, vecVelocity, vecTargetVelocity);
    set_pev(pEntity, pev_velocity, vecTargetVelocity);
}

stock UTIL_DrawArrow(pPlayer, const Float:vecSrc[3], const Float:vecTarget[3], const irgColor[3] = {255, 255, 255}, iBrightness = 255, iLifeTime = 10, iWidth = 64) {
    new iModelIndex = engfunc(EngFunc_ModelIndex, "sprites/arrow1.spr");
    
    engfunc(EngFunc_MessageBegin, pPlayer ? MSG_ONE : MSG_ALL, SVC_TEMPENTITY, vecSrc, pPlayer);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, vecTarget[0]);
    engfunc(EngFunc_WriteCoord, vecTarget[1]);
    engfunc(EngFunc_WriteCoord, vecTarget[2]);
    engfunc(EngFunc_WriteCoord, vecSrc[0]);
    engfunc(EngFunc_WriteCoord, vecSrc[1]);
    engfunc(EngFunc_WriteCoord, vecSrc[2]);
    write_short(iModelIndex);
    write_byte(0);
    write_byte(0);
    write_byte(iLifeTime);
    write_byte(iWidth);
    write_byte(0);
    write_byte(irgColor[0]);
    write_byte(irgColor[1]);
    write_byte(irgColor[2]);
    write_byte(iBrightness);
    write_byte(0);
    message_end();
}

stock Float:ApproachAngle(Float:target, Float:value, Float:speed) {
  target = anglemod( target );
  value = anglemod( value );

  new Float:delta = target - value;

  // Speed is assumed to be positive
  if ( speed < 0 )
    speed = -speed;

  if ( delta < -180 )
    delta += 360;
  else if ( delta > 180 )
    delta -= 360;

  if ( delta > speed )
    value += speed;
  else if ( delta < -speed )
    value -= speed;
  else 
    value = target;

  return value;
}

stock Float:anglemod(Float:a) {
  return (360.0/65536) * (floatround(a * (65536.0/360.0), floatround_floor) & 65535);
}
