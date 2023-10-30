#include <reapi>

#include <hwn_utils>

#define STEP_HEIGHT 18.0
#define HEAD_TO_MAXS_RATIO 0.21875

enum NPC_Action {
    NPC_Action_StartSequence,
    NPC_Action_EndSequence,
    Float:NPC_Action_Time
};

stock bool:NPC_Hit(pEntity, Float:flDamage, Float:flRange, const Float:vecOffset[3] = {0.0, 0.0, 0.0}) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecDirection[3];
    UTIL_GetDirectionVector(pEntity, vecDirection);

    static Float:vecTarget[3];
    xs_vec_mul_scalar(vecDirection, flRange, vecTarget);
    xs_vec_add(vecTarget, vecOrigin, vecTarget);
    xs_vec_add(vecTarget, vecOffset, vecTarget);

    new pTrace = create_tr2();

    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, pEntity, pTrace);

    new pTarget = get_tr2(pTrace, TR_pHit);
    if (pTarget == -1) {
        engfunc(EngFunc_TraceHull, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, HULL_HEAD, pEntity, pTrace);
        pTarget = get_tr2(pTrace, TR_pHit);
    }

    new bool:bHit = pTarget != -1;

    if (bHit) {
        get_tr2(pTrace, TR_vecEndPos, vecTarget);
        xs_vec_sub(vecOrigin, vecTarget, vecDirection);
        xs_vec_normalize(vecDirection, vecDirection);

        rg_multidmg_clear();
        ExecuteHamB(Ham_TraceAttack, pTarget, pEntity, flDamage, vecDirection, pTrace, DMG_GENERIC);
        rg_multidmg_apply(pEntity, pEntity);

        bHit = IS_PLAYER(pTarget) || UTIL_IsMonster(pTarget);
    }

    free_tr2(pTrace);

    return bHit;
}

stock bool:NPC_IsReachable(pEntity, const Float:vecTarget[3], pIgnoreEnt = 0, Float:flStepLength = 32.0) {
    if ((~pev(pEntity, pev_flags) & FL_ONGROUND) && pev(pEntity, pev_movetype) != MOVETYPE_FLY) {
        return false;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:_vTarget[3];
    xs_vec_copy(vecTarget, _vTarget);
    if (_vTarget[2] < vecOrigin[2]) {
        _vTarget[2] = vecOrigin[2];
    }

    new ignoreEntSolidType = SOLID_NOT;
    if (pIgnoreEnt) {
        ignoreEntSolidType = pev(pIgnoreEnt, pev_solid);
        set_pev(pIgnoreEnt, pev_solid, SOLID_NOT);
    }

    new bool:isReachable = true;

    if (isReachable) {
        isReachable = UTIL_IsOpen(vecOrigin, _vTarget, pEntity);
    }

    if (isReachable) {
        static Float:vecMins[3];
        pev(pEntity, pev_mins, vecMins);

        static Float:vecLeftSide[3];
        vecLeftSide[0] = vecOrigin[0] + vecMins[0];
        vecLeftSide[1] = vecOrigin[1] + vecMins[1];
        vecLeftSide[2] = vecOrigin[2];

        static Float:vecTargetLeftSide[3];
        vecTargetLeftSide[0] = _vTarget[0] + vecMins[0];
        vecTargetLeftSide[1] = _vTarget[1] + vecMins[1];
        vecTargetLeftSide[2] = _vTarget[2];

        isReachable = UTIL_IsOpen(vecLeftSide, vecTargetLeftSide, pEntity);
    }

    if (isReachable) {
        static Float:vecMaxs[3];
        pev(pEntity, pev_maxs, vecMaxs);

        static Float:vecRightSide[3];
        vecRightSide[0] = vecOrigin[0] + vecMaxs[0];
        vecRightSide[1] = vecOrigin[1] + vecMaxs[1];
        vecRightSide[2] = vecOrigin[2];

        static Float:vecTargetRightSide[3];
        vecTargetRightSide[0] = _vTarget[0] + vecMaxs[0];
        vecTargetRightSide[1] = _vTarget[1] + vecMaxs[1];
        vecTargetRightSide[2] = _vTarget[2];

        isReachable = UTIL_IsOpen(vecRightSide, vecTargetRightSide, pEntity);
    }

    if (isReachable && pev(pEntity, pev_movetype) != MOVETYPE_FLY) {
        new Float:flDistance = get_distance_f(vecOrigin, _vTarget);
        new steps = floatround(flDistance / flStepLength);

        if (steps) {
            //Get iDirection vetor
            static Float:vecStep[3];
            xs_vec_sub(_vTarget, vecOrigin, vecStep);
            
            static Float:vecStepOrigin[3];
            isReachable = NPC_TestStep(pEntity, vecOrigin, vecStep, vecStepOrigin);

            if (isReachable) {
                xs_vec_normalize(vecStep, vecStep);
                xs_vec_mul_scalar(vecStep, flStepLength, vecStep);

                xs_vec_copy(vecOrigin, vecStepOrigin);

                for (new i = 0; i < steps; ++i) {
                    if (!NPC_TestStep(pEntity, vecStepOrigin, vecStep, vecStepOrigin)) {
                        isReachable = false;
                        break;
                    }
                }
            }
        }
    }

    if (pIgnoreEnt) {
        set_pev(pIgnoreEnt, pev_solid, ignoreEntSolidType);
    }

    return isReachable;
}

stock bool:NPC_TestStep(pEntity, const Float:vecOrigin[3], const Float:vecStep[3], Float:vecStepOrigin[3]) {
    static Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);
    
    static Float:_vStepOrigin[3];
    xs_vec_copy(vecStepOrigin, _vStepOrigin);
    xs_vec_add(vecOrigin, vecStep, _vStepOrigin);

    // check wall
    static Float:vecStepStart[3];
    xs_vec_copy(vecOrigin, vecStepStart);
    vecStepStart[2] += vecMins[2] + STEP_HEIGHT;

    static Float:vecStepEnd[3];
    xs_vec_copy(_vStepOrigin, vecStepEnd);
    vecStepEnd[2] += vecMins[2] + STEP_HEIGHT;

    if (!UTIL_IsOpen(vecStepStart, vecStepEnd, pEntity)) {
        return false;
    }

    _vStepOrigin[2] += STEP_HEIGHT; // add height to the step

    new Float:flDistanceToFloor = UTIL_GetDistanceToFloor(pEntity, _vStepOrigin);
    if (flDistanceToFloor < 0.0) { // check if falling or solid
        static Float:vecEnd[3];
        xs_vec_copy(_vStepOrigin, vecEnd);
        vecEnd[2] -= -vecMins[2] + STEP_HEIGHT;
        return false;
    }

    if (flDistanceToFloor >= STEP_HEIGHT) { // subtract step height if not needed
        flDistanceToFloor -= STEP_HEIGHT;
        _vStepOrigin[2] -= STEP_HEIGHT;
    }

    _vStepOrigin[2] -= flDistanceToFloor; // apply possible height change

    xs_vec_copy(_vStepOrigin, vecStepOrigin); // copy result

    return true;
}

stock NPC_StopMovement(pEntity) {
    static Float:vecVelocity[3];
    pev(pEntity, pev_velocity, vecVelocity);

    vecVelocity[0] = 0.0;
    vecVelocity[1] = 0.0;

    set_pev(pEntity, pev_velocity, vecVelocity);
}

stock NPC_MoveForward(pEntity, Float:flSpeed) {
    static Float:vecDirection[3];
    UTIL_GetDirectionVector(pEntity, vecDirection, flSpeed);

    static Float:vecOrigin[3];
    pev(pEntity, pev_velocity, vecOrigin);

    static Float:vecVelocity[3];
    pev(pEntity, pev_velocity, vecVelocity);
    vecVelocity[0] = vecDirection[0];
    vecVelocity[1] = vecDirection[1];

    static Float:vecTarget[3];
    xs_vec_add(vecOrigin, vecVelocity, vecTarget);

    static Float:vecAngles[3];
    pev(pEntity, pev_angles, vecAngles);
    set_pev(pEntity, pev_ideal_yaw, vecAngles[1]);

    if (pev(pEntity, pev_movetype) != MOVETYPE_FLY) {
        engfunc(EngFunc_WalkMove, pEntity, vecAngles[1], 0.5, WALKMOVE_NORMAL);
    }

    set_pev(pEntity, pev_velocity, vecVelocity);
}

stock bool:NPC_CanHit(pEntity, pEnemy, Float:flHitRange, const Float:vecOffset[3] = {0.0, 0.0, 0.0}) {
    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    pev(pEnemy, pev_origin, vecTarget);
    xs_vec_add(vecTarget, vecOffset, vecTarget);

    if (!NPC_IsInViewCone(pEntity, vecTarget, 5.0)) {
        return false;
    }

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, pEntity, pTrace);

    static Float:flFraction;
    get_tr2(pTrace, TR_flFraction, flFraction);

    new bool:bResult = flFraction == 1.0 && get_distance_f(vecOrigin, vecTarget) <= flHitRange;

    if (!bResult) {
        if (get_tr2(pTrace, TR_pHit) == pEnemy) {
            get_tr2(pTrace, TR_vecEndPos, vecTarget);
            bResult = (get_distance_f(vecOrigin, vecTarget) <= flHitRange);
        }
    }

    free_tr2(pTrace);

    return bResult;
}

stock bool:NPC_IsValidEnemy(pEnemy, iTeam = 0, bool:allowMonsters = true) {
    if (!pEnemy || !pev_valid(pEnemy)) {
        return false;
    }

    new enemyTeam = 0;
    if (IS_PLAYER(pEnemy)) {
        if (!is_user_alive(pEnemy)) {
            return false;
        }

        enemyTeam = get_member(pEnemy, m_iTeam);
    } else if (allowMonsters && UTIL_IsMonster(pEnemy)) {
        enemyTeam = pev(pEnemy, pev_team);
    } else {
        return false;
    }

    if (iTeam == enemyTeam) {
        return false;
    }

    if (pev(pEnemy, pev_takedamage) == DAMAGE_NO) {
        return false;
    }

    if (pev(pEnemy, pev_solid) < SOLID_BBOX) {
        return false;
    }
    
    if (UTIL_IsInvisible(pEnemy)) {
        return false;
    }

    return true;
}

stock NPC_IsVisible(pEntity, const Float:vecTarget[3], pIgnoreEnt = 0) {
    static Float:vecOrigin[3];
    ExecuteHamB(Ham_EyePosition, pEntity, vecOrigin);
    // pev(pEntity, pev_origin, vecOrigin);

    new ignoreEntSolidType = SOLID_NOT;
    if (pIgnoreEnt) {
        ignoreEntSolidType = pev(pIgnoreEnt, pev_solid);
        set_pev(pIgnoreEnt, pev_solid, SOLID_NOT);
    }

    new bool:isOpen = UTIL_IsOpen(vecOrigin, vecTarget, pEntity);

    if (pIgnoreEnt) {
        set_pev(pIgnoreEnt, pev_solid, ignoreEntSolidType);
    }

    return isOpen;
}

stock NPC_GetEnemy(pEntity) {
    new pEnemy = pev(pEntity, pev_enemy);

    if (!NPC_IsValidEnemy(pEnemy, pev(pEntity, pev_team))) {
        pEnemy = 0;
    }

    return pEnemy;
}

stock bool:NPC_IsInViewCone(pEntity, const Float:vecTarget[3], Float:fMaxAngle) {
    static Float:vecOrigin[3];
    ExecuteHamB(Ham_EyePosition, pEntity, vecOrigin);

    static Float:vecDir[3];
    xs_vec_sub(vecTarget, vecOrigin, vecDir);
    xs_vec_normalize(vecDir, vecDir);

    static Float:vecForward[3];
    pev(pEntity, pev_v_angle, vecForward);
    angle_vector(vecForward, ANGLEVECTOR_FORWARD, vecForward);

    static Float:flAngle; flAngle = xs_vec_dot(vecDir, vecForward);

    return flAngle < fMaxAngle;
}

stock Float:NPC_GetPathCost(pEntity, NavArea:newArea, NavArea:prevArea) {
    new NavAttributeType:iAttributes = Nav_Area_GetAttributes(newArea);

    // NPC can't jump or crouch
    if (iAttributes & NAV_JUMP || iAttributes & NAV_CROUCH) {
        return -1.0;
    }

    static Float:vecTarget[3];
    Nav_Area_GetCenter(newArea, vecTarget);

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecSrc[3];
    if (prevArea != Invalid_NavArea) {
        Nav_Area_GetCenter(prevArea, vecSrc);
    } else {
        xs_vec_copy(vecOrigin, vecSrc);
    }

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecSrc, vecTarget, IGNORE_MONSTERS, 0, pTrace);
    new pHit = get_tr2(pTrace, TR_pHit);
    free_tr2(pTrace);

    // cancel if there is a wall
    if (!pHit) {
        return -1.0;
    }

    // cancel path if there is a obstacle
    if (pHit != -1 && !IS_PLAYER(pHit) && !UTIL_IsMonster(pHit)) {
        return -1.0;
    }

    // don't go through spawn area, path cost penalty for going through the spawn area in case we already in the spawn area
    new iSpawnAreaTeam = Hwn_Gamemode_GetSpawnAreaTeam(vecTarget);
    if (iSpawnAreaTeam) {
        return iSpawnAreaTeam == Hwn_Gamemode_GetSpawnAreaTeam(vecOrigin) ? 100.0 : -1.0;
    }

    new pTarget = 0;
    while ((pTarget = engfunc(EngFunc_FindEntityInSphere, pTarget, vecTarget, 4.0)) > 0) {
        static szClassName[32];
        pev(pTarget, pev_classname, szClassName, charsmax(szClassName));

        // don't go through the hurt entities
        if (equal(szClassName, "trigger_hurt")) {
            return -1.0;
        }
    }

    return 1.0;
}

stock NPC_UpdateEnemy(pEntity, Float:flMaxDistance, Float:flMinPriority) {
    new pEnemy = pev(pEntity, pev_enemy);
    if (!NPC_IsValidEnemy(pEnemy)) {
        set_pev(pEntity, pev_enemy, 0);
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static iTeam; iTeam = pev(pEntity, pev_team);
    static pClosestTarget; pClosestTarget = 0;
    static Float:flClosestTargetPriority; flClosestTargetPriority = 0.0;

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, flMaxDistance)) > 0) {
        if (pEntity == pTarget) {
            continue;
        }

        if (!NPC_IsValidEnemy(pTarget, iTeam)) {
            continue;
        }

        static Float:vecTarget[3];
        pev(pTarget, pev_origin, vecTarget);

        static Float:flDistance; flDistance = xs_vec_distance(vecOrigin, vecTarget);
        static Float:flTargetPriority; flTargetPriority = 1.0 - (flDistance / flMaxDistance);

        if (IS_PLAYER(pTarget)) {
            flTargetPriority *= 1.0;
        } else if (UTIL_IsMonster(pTarget)) {
            flTargetPriority *= 0.075;
        } else {
            flTargetPriority *= 0.0;
        }

        if (flTargetPriority >= flMinPriority && !NPC_IsReachable(pEntity, vecTarget, pTarget)) {
            flTargetPriority *= 0.1;
        }

        if (flTargetPriority >= flMinPriority && flTargetPriority > flClosestTargetPriority) {
            pClosestTarget = pTarget;
            flClosestTargetPriority = flTargetPriority;
        }
    }

    if (pClosestTarget) {
        set_pev(pEntity, pev_enemy, pClosestTarget);
    }

    return pClosestTarget;
}

stock NPC_MoveTo(pEntity, const Float:vecTarget[3]) {
    static Float:flGameTime; flGameTime = get_gametime();
    static Float:flMaxSpeed; pev(pEntity, pev_maxspeed, flMaxSpeed);
    static Float:flLastThink; pev(pEntity, pev_ltime, flLastThink);
    static iMoveType; iMoveType = pev(pEntity, pev_movetype);
    static Float:flDelta; flDelta = flGameTime - flLastThink;
    static Float:flMaxAngle; flMaxAngle = 180.0 * floatmin(flDelta, 0.1);
    static bool:rgbLockAxis[3]; rgbLockAxis = bool:{true, false, true};

    if (iMoveType == MOVETYPE_FLY) {
        rgbLockAxis[0] = false;
    }

    UTIL_TurnTo(pEntity, vecTarget, rgbLockAxis, flMaxAngle);

    if (NPC_IsInViewCone(pEntity, vecTarget, 15.0)) {
        static Float:vecOrigin[3];
        pev(pEntity, pev_origin, vecOrigin);

        if (flMaxSpeed > 0.0 && get_distance_f(vecOrigin, vecTarget) > 1.0) {
            set_pev(pEntity, pev_speed, flMaxSpeed);
            NPC_MoveForward(pEntity, flMaxSpeed);
        }
    }
}
