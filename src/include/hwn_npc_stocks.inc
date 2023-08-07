#include <reapi>

#include <hwn_utils>

#define STEP_HEIGHT 18.0
#define HEAD_TO_MAXS_RATIO 0.21875

enum _:NPC
{
    Float:NPC_NextAttack,
    Float:NPC_NextAction,
    Float:NPC_NextVoice,
    Float:NPC_NextFootStep,
    Float:NPC_LastReachablePoint[3],
    Float:NPC_ReachTime,
    Float:NPC_ViewZOffset,
    Float:NPC_EnemyTime
}

enum NPC_Action
{
    NPC_Action_StartSequence,
    NPC_Action_EndSequence,
    Float:NPC_Action_Time
};

stock NPC_Create(pEntity, Float:flViewZOffset = -1.0) {
    new Array:npcData = ArrayCreate(1, _:NPC);
    for (new i = 0; i < _:NPC; ++i) {
        ArrayPushCell(npcData, 0);
    }

    ArraySetArray(npcData, NPC_LastReachablePoint, Float:{0.0, 0.0, 0.0});

    if (flViewZOffset == -1.0) {
        new Float:vecMaxs[3];
        pev(pEntity, pev_maxs, vecMaxs);

        ArraySetCell(npcData, NPC_ViewZOffset, vecMaxs[2] * (1.0 - HEAD_TO_MAXS_RATIO));
    } 

    set_pev(pEntity, pev_iuser1, npcData);
}

stock NPC_Destroy(pEntity) {
    new Array:npcData = NPC_GetData(pEntity);
    ArrayDestroy(npcData);
}

stock Array:NPC_GetData(pEntity) {
    return any:pev(pEntity, pev_iuser1);
}

stock NPC_PlayAction(pEntity, action[NPC_Action], bool:supercede = false) {
    new Array:npcData = NPC_GetData(pEntity);

    new Float:flGametime = get_gametime();
    if (!supercede && flGametime < ArrayGetCell(npcData, NPC_NextAction)) {
        return;
    }

    new iSequence = random_num(action[NPC_Action_StartSequence], action[NPC_Action_EndSequence]);

    if (!UTIL_SetSequence(pEntity, iSequence)) {
        return;
    }

    ArraySetCell(npcData, NPC_NextAction, flGametime + action[NPC_Action_Time]);
}

stock NPC_EmitVoice(pEntity, const szSound[], Float:flPlayTime = 1.0, bool:supercede = false, Float:flVolume = VOL_NORM) {
    new Array:npcData = NPC_GetData(pEntity);

    new Float:flGametime = get_gametime();
    if (!supercede && flGametime < ArrayGetCell(npcData, NPC_NextVoice)) {
        return;
    }

    emit_sound(pEntity, CHAN_VOICE, szSound, flVolume, ATTN_NORM, 0, PITCH_NORM);

    ArraySetCell(npcData, NPC_NextVoice, flGametime + flPlayTime);
}

stock NPC_EmitFootStep(pEntity, const szSound[]) {
    new Array:npcData = NPC_GetData(pEntity);

    new Float:flGametime = get_gametime();
    if (flGametime < ArrayGetCell(npcData, NPC_NextFootStep)) {
        return;
    }

    emit_sound(pEntity, CHAN_BODY, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    ArraySetCell(npcData, NPC_NextFootStep, flGametime + 0.25);
}

stock bool:NPC_Hit(
    pEntity,
    Float:flDamage,
    Float:flRange,
    Float:flAttackDelay,
    const Float:vecOffset[3] = {0.0, 0.0, 0.0}
) {
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

    new Array:npcData = NPC_GetData(pEntity);
    ArraySetCell(npcData, NPC_NextAttack, get_gametime() + flAttackDelay);

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

stock bool:NPC_GetTarget(pEntity, Float:flSpeed, Float:vecTarget[3], bool:reachableOnly = true, bool:visibleOnly = true) {
    new pEnemy = NPC_GetEnemy(pEntity);
    if (!pEnemy) {
        return false;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    static Float:vecEnemyMins[3];
    pev(pEnemy, pev_mins, vecEnemyMins);

    pev(pEnemy, pev_origin, vecTarget);

    vecTarget[2] = vecTarget[2] + vecEnemyMins[2] - vecMins[2];

    new Array:npcData = NPC_GetData(pEntity);

    new Float:flGameTime = get_gametime();
    if ((!visibleOnly || NPC_IsVisible(pEntity, vecTarget, pEnemy)) && (!reachableOnly || NPC_IsReachable(pEntity, vecTarget, pEnemy))) {
        new Float:flDistance = get_distance_f(vecOrigin, vecTarget);
        new Float:flReachTime = flGameTime + flDistance/flSpeed;

        ArraySetCell(npcData, NPC_ReachTime, flReachTime);
        ArraySetArray(npcData, NPC_LastReachablePoint, vecTarget);
    } else {
        new Float:flReachTime = ArrayGetCell(npcData, NPC_ReachTime);
        if (flGameTime < flReachTime) {
            ArrayGetArray(npcData, NPC_LastReachablePoint, vecTarget);
        } else {
            return false;
        }
    }

    return true;
}

stock NPC_FindEnemy(pEntity, Float:flMaxDistance = 3072.0, bool:reachableOnly = true, bool:visibleOnly = true,  bool:allowMonsters = true) {
    new nearestEnemy = 0;
    new Float:flNearestEnemyDistance = -1.0;

    new iTeam = pev(pEntity, pev_team);

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecMins[3];
    pev(pEntity, pev_mins, vecMins);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, flMaxDistance)) > 0) {
        if (pEntity == pTarget) {
            continue;
        }

        if (!NPC_IsValidEnemy(pTarget, iTeam, allowMonsters)) {
            continue;
        }

        static Float:vecTarget[3];
        pev(pTarget, pev_origin, vecTarget);

        if (visibleOnly && !NPC_IsVisible(pEntity, vecTarget, pTarget)) {
            continue;
        }

        static Float:vecEnemyMins[3];
        pev(pTarget, pev_mins, vecEnemyMins);
        vecTarget[2] = vecTarget[2] + vecEnemyMins[2] - vecMins[2];

        if (reachableOnly && !NPC_IsReachable(pEntity, vecTarget, pTarget)) {
            continue;
        }

        new Float:flDistance = get_distance_f(vecOrigin, vecTarget);
        if (flNearestEnemyDistance < 0 || flDistance < flNearestEnemyDistance) {
            nearestEnemy = pTarget;
            flNearestEnemyDistance = flDistance;
        }
    }

    if (nearestEnemy) {
        NPC_SetEnemy(pEntity, nearestEnemy);
    }

    return nearestEnemy;
}

stock NPC_MoveToTarget(pEntity, const Float:vecTarget[3], Float:flSpeed, Float:flAngleSpeed = 180.0) {
    new bool:rgbLockAxis[3] = {true, false, true};
    rgbLockAxis[0] = pev(pEntity, pev_movetype) != MOVETYPE_FLY;

    new Float:flGameTime = get_gametime();

    static Float:flLastThink;
    pev(pEntity, pev_ltime, flLastThink);

    new Float:flDelta = flGameTime - flLastThink;
    new Float:flMaxAngle = flAngleSpeed * floatmin(flDelta, 0.1);

    UTIL_TurnTo(pEntity, vecTarget, rgbLockAxis, flMaxAngle);

    if (NPC_IsInViewCone(pEntity, vecTarget, 45.0)) {
        static Float:vecOrigin[3];
        pev(pEntity, pev_origin, vecOrigin);

        if (flSpeed > 0.0 && get_distance_f(vecOrigin, vecTarget) > 1.0) {
            set_pev(pEntity, pev_speed, flSpeed);
            NPC_MoveForward(pEntity, flSpeed);
        }
    }
}

stock NPC_StopMovement(pEntity) {
    static Float:vecVelocity[3];
    pev(pEntity, pev_velocity, vecVelocity);

    vecVelocity[0] = 0.0;
    vecVelocity[1] = 0.0;

    set_pev(pEntity, pev_velocity, vecVelocity);
}

stock NPC_MoveForward(pEntity, Float:flSpeed) {
    new Float:flGameTime = get_gametime();

    static Float:flLastThink;
    pev(pEntity, pev_ltime, flLastThink);

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
    new Array:npcData = NPC_GetData(pEntity);
    if (get_gametime() < ArrayGetCell(npcData, NPC_NextAttack)) {
        return false;
    }

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);

    static Float:vecTarget[3];
    pev(pEnemy, pev_origin, vecTarget);
    xs_vec_add(vecTarget, vecOffset, vecTarget);

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, pEntity, pTrace);

    static Float:flFraction;
    get_tr2(pTrace, TR_flFraction, flFraction);

    if (flFraction == 1.0 && get_distance_f(vecOrigin, vecTarget) <= flHitRange) {
        return true;
    }

    new bool:result = false;
    if (get_tr2(pTrace, TR_pHit) == pEnemy) {
        get_tr2(pTrace, TR_vecEndPos, vecTarget);
        result = (get_distance_f(vecOrigin, vecTarget) <= flHitRange);
    }

    free_tr2(pTrace);

    return result;
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
    pev(pEntity, pev_origin, vecOrigin);

    new ignoreEntSolidType = SOLID_NOT;
    if (pIgnoreEnt) {
        ignoreEntSolidType = pev(pIgnoreEnt, pev_solid);
        set_pev(pIgnoreEnt, pev_solid, SOLID_NOT);
    }

    new Array:npcData = NPC_GetData(pEntity);
    vecOrigin[2] += Float:ArrayGetCell(npcData, NPC_ViewZOffset);

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

stock NPC_SetEnemy(pEntity, pEnemy) {
    set_pev(pEntity, pev_enemy, pEnemy);

    if (pEnemy) {
        new Array:npcData = NPC_GetData(pEntity);
        ArraySetCell(npcData, NPC_EnemyTime, get_gametime());
    }
}

stock Float:NPC_GetEnemyTime(pEntity) {
    new Array:npcData = NPC_GetData(pEntity);
    return ArrayGetCell(npcData, NPC_EnemyTime);
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

    new Float:flAngle = xs_rad2deg(xs_acos((vecDir[0] * vecForward[0]) + (vecDir[1] * vecForward[1]), radian));

    return flAngle < fMaxAngle;
}
