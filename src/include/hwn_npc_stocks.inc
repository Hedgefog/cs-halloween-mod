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
    Float:NPC_LastRotation,
    Float:NPC_ViewZOffset,
    Float:NPC_EnemyTime
}

enum NPC_Action
{
    NPC_Action_StartSequence,
    NPC_Action_EndSequence,
    Float:NPC_Action_Time
};

stock NPC_Create(ent, Float:fViewZOffset = -1.0)
{
    new Array:npcData = ArrayCreate(1, _:NPC);
    for (new i = 0; i < _:NPC; ++i) {
        ArrayPushCell(npcData, 0);
    }

    ArraySetArray(npcData, NPC_LastReachablePoint, Float:{0.0, 0.0, 0.0});

    if (fViewZOffset == -1.0) {
        new Float:vMaxs[3];
        pev(ent, pev_maxs, vMaxs);

        ArraySetCell(npcData, NPC_ViewZOffset, vMaxs[2] * (1.0 - HEAD_TO_MAXS_RATIO));
    } 

    set_pev(ent, pev_iuser1, npcData);
}

stock NPC_Destroy(ent)
{
    new Array:npcData = NPC_GetData(ent);
    ArrayDestroy(npcData);
}

stock Array:NPC_GetData(ent)
{
    return any:pev(ent, pev_iuser1);
}

stock NPC_PlayAction(ent, action[NPC_Action], bool:supercede = false)
{
    new Array:npcData = NPC_GetData(ent);

    new Float:fGametime = get_gametime();
    if (!supercede && fGametime < ArrayGetCell(npcData, NPC_NextAction)) {
        return;
    }

    new sequence = random_num(action[NPC_Action_StartSequence], action[NPC_Action_EndSequence]);
    UTIL_SetSequence(ent, sequence);

    ArraySetCell(npcData, NPC_NextAction, fGametime + action[NPC_Action_Time]);
}

stock NPC_EmitVoice(ent, const szSound[], Float:fPlayTime = 1.0, bool:supercede = false)
{
    new Array:npcData = NPC_GetData(ent);

    new Float:fGametime = get_gametime();
    if (!supercede && fGametime < ArrayGetCell(npcData, NPC_NextVoice)) {
        return;
    }

    emit_sound(ent, CHAN_VOICE, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    ArraySetCell(npcData, NPC_NextVoice, fGametime + fPlayTime);
}

stock NPC_EmitFootStep(ent, const szSound[])
{
    new Array:npcData = NPC_GetData(ent);

    new Float:fGametime = get_gametime();
    if (fGametime < ArrayGetCell(npcData, NPC_NextFootStep)) {
        return;
    }

    emit_sound(ent, CHAN_BODY, szSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    ArraySetCell(npcData, NPC_NextFootStep, fGametime + 0.25);
}

stock bool:NPC_Hit(
    ent,
    Float:fDamage,
    Float:fRange,
    Float:fAttackDelay,
    const Float:vOffset[3] = {0.0, 0.0, 0.0},
    bool:correctByEnemy = true
)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vDirection[3];
    UTIL_GetDirectionVector(ent, vDirection);

    // correction of z axis by enemy origin
    new enemy = pev(ent, pev_enemy);
    if (correctByEnemy && enemy) {
        static Float:vTemp[3];
        pev(enemy, pev_origin, vTemp);
        xs_vec_sub(vTemp, vOrigin, vTemp);
        xs_vec_normalize(vTemp, vTemp);

        vDirection[2] = vTemp[2];
        xs_vec_normalize(vDirection, vDirection);
    }

    xs_vec_mul_scalar(vDirection, fRange, vDirection);

    static Float:vTarget[3];
    xs_vec_add(vOrigin, vDirection, vTarget);
    xs_vec_add(vTarget, vOffset, vTarget);

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, vOrigin, vTarget, DONT_IGNORE_MONSTERS, ent, trace);

    new bool:hit = false;

    new target = get_tr2(trace, TR_pHit);
    if (target != -1) {
        if (is_user_alive(target)) {
            UTIL_CS_DamagePlayer(target, fDamage, DMG_PARALYZE, ent, ent);
            hit = true;
        } else {
            ExecuteHamB(Ham_TakeDamage, target, ent, ent, fDamage, DMG_PARALYZE);
        }
    }

    free_tr2(trace);

    new Array:npcData = NPC_GetData(ent);
    ArraySetCell(npcData, NPC_NextAttack, get_gametime() + fAttackDelay);

    return hit;
}

stock bool:NPC_IsReachable(ent, const Float:vTarget[3])
{
    if ((~pev(ent, pev_flags) & FL_ONGROUND) && pev(ent, pev_movetype) != MOVETYPE_FLY) {
        return false;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:_vTarget[3];
    xs_vec_copy(vTarget, _vTarget);
    if (_vTarget[2] < vOrigin[2]) {
        _vTarget[2] = vOrigin[2];
    }

    if (!UTIL_IsOpen(vOrigin, _vTarget, ent)) {
        return false;
    }

    static Float:vMins[3];
    pev(ent, pev_mins, vMins);

    static Float:vLeftSide[3];
    vLeftSide[0] = vOrigin[0] + vMins[0];
    vLeftSide[1] = vOrigin[1] + vMins[1];
    vLeftSide[2] = vOrigin[2];

    static Float:vTargetLeftSide[3];
    vTargetLeftSide[0] = _vTarget[0] + vMins[0];
    vTargetLeftSide[1] = _vTarget[1] + vMins[1];
    vTargetLeftSide[2] = _vTarget[2];

    if (!UTIL_IsOpen(vLeftSide, vTargetLeftSide, ent)) {
        return false;
    }

    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);

    static Float:vRightSide[3];
    vRightSide[0] = vOrigin[0] + vMaxs[0];
    vRightSide[1] = vOrigin[1] + vMaxs[1];
    vRightSide[2] = vOrigin[2];

    static Float:vTargetRightSide[3];
    vTargetRightSide[0] = _vTarget[0] + vMaxs[0];
    vTargetRightSide[1] = _vTarget[1] + vMaxs[1];
    vTargetRightSide[2] = _vTarget[2];

    if (!UTIL_IsOpen(vRightSide, vTargetRightSide, ent)) {
        return false;
    }

    if (pev(ent, pev_movetype) == MOVETYPE_FLY) {
        return true;
    }

    new Float:fDistance = get_distance_f(vOrigin, _vTarget);
    new steps = floatround(fDistance / 32.0);

    if (steps < 1) {
        return true;
    }

    //Get direction vetor
    static Float:vStep[3];
    xs_vec_sub(_vTarget, vOrigin, vStep);
    
    static Float:vStepOrigin[3];
    if (!NPC_TestStep(ent, vOrigin, vStep, vStepOrigin)) {
        return false;
    }
    
    xs_vec_normalize(vStep, vStep);
    xs_vec_mul_scalar(vStep, 32.0, vStep);

    xs_vec_copy(vOrigin, vStepOrigin);

    for (new i = 0; i < steps; ++i) {
        if (!NPC_TestStep(ent, vStepOrigin, vStep, vStepOrigin)) {
            return false;
        }
    }

    return true;
}

stock bool:NPC_TestStep(ent, const Float:vOrigin[3], const Float:vStep[3], Float:vStepOrigin[3])
{
    static Float:vMins[3];
    pev(ent, pev_mins, vMins);
    
    static Float:_vStepOrigin[3];
    xs_vec_copy(vStepOrigin, _vStepOrigin);
    xs_vec_add(vOrigin, vStep, _vStepOrigin);

    // check wall
    static Float:vStepStart[3];
    xs_vec_copy(vOrigin, vStepStart);
    vStepStart[2] += vMins[2] + STEP_HEIGHT;

    static Float:vStepEnd[3];
    xs_vec_copy(_vStepOrigin, vStepEnd);
    vStepEnd[2] += vMins[2] + STEP_HEIGHT;

    if (!UTIL_IsOpen(vStepStart, vStepEnd, ent)) {
        return false;
    }

    _vStepOrigin[2] += STEP_HEIGHT; // add height to the step

    new Float:fDistanceToFloor = UTIL_GetDistanceToFloor(ent, _vStepOrigin);
    if (fDistanceToFloor < 0.0) { // check if falling or solid
        static Float:vEnd[3];
        xs_vec_copy(_vStepOrigin, vEnd);
        vEnd[2] -= -vMins[2] + STEP_HEIGHT;
        return false;
    }

    if (fDistanceToFloor >= STEP_HEIGHT) { // subtract step height if not needed
        fDistanceToFloor -= STEP_HEIGHT;
        _vStepOrigin[2] -= STEP_HEIGHT;
    }

    _vStepOrigin[2] -= fDistanceToFloor; // apply possible height change

    xs_vec_copy(_vStepOrigin, vStepOrigin); // copy result

    return true;
}

stock bool:NPC_GetTarget(ent, Float:fSpeed, Float:vTarget[3], bool:reachableOnly = true, bool:visibleOnly = true)
{
    new enemy = pev(ent, pev_enemy);
    if (!enemy) {
        return false;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vMins[3];
    pev(ent, pev_mins, vMins);

    static Float:vEnemyMins[3];
    pev(enemy, pev_mins, vEnemyMins);

    pev(enemy, pev_origin, vTarget);

    vTarget[2] = vTarget[2] + vEnemyMins[2] - vMins[2];

    new Array:npcData = NPC_GetData(ent);

    new Float:fGameTime = get_gametime();
    if ((!visibleOnly || NPC_IsVisible(ent, vTarget)) && (!reachableOnly || NPC_IsReachable(ent, vTarget))) {
        new Float:fDistance = get_distance_f(vOrigin, vTarget);
        new Float:fReachTime = fGameTime + fDistance/fSpeed;

        ArraySetCell(npcData, NPC_ReachTime, fReachTime);
        ArraySetArray(npcData, NPC_LastReachablePoint, vTarget);
    } else {
        new Float:fReachTime = ArrayGetCell(npcData, NPC_ReachTime);
        if (fGameTime < fReachTime) {
            ArrayGetArray(npcData, NPC_LastReachablePoint, vTarget);
        } else {
            return false;
        }
    }

    return true;
}

stock bool:NPC_FindEnemy(ent, maxplayers = 32, Float:fMaxDistance = 3072.0, bool:reachableOnly = true, bool:visibleOnly = true, team = 0)
{
    new nearestPlayer = 0;
    new Float:fNearestPlayerDistance = -1.0;

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vMins[3];
    pev(ent, pev_mins, vMins);

    for (new i = 1; i <= maxplayers; ++i)
    {
        if (!is_user_connected(i)) {
            continue;
        }

        if (!is_user_alive(i)) {
            continue;
        }

        if (UTIL_IsInvisible(i)) {
            continue;
        }

        if (UTIL_GetPlayerTeam(i) == team) {
            continue;
        }

        static Float:vTarget[3];
        pev(i, pev_origin, vTarget);

        new Float:fDistance = get_distance_f(vOrigin, vTarget);
        if (fMaxDistance > 0 && fDistance > fMaxDistance) {
            continue;
        }

        if (visibleOnly && !NPC_IsVisible(ent, vTarget)) {
            continue;
        }

        static Float:vEnemyMins[3];
        pev(i, pev_mins, vEnemyMins);
        vTarget[2] = vTarget[2] + vEnemyMins[2] - vMins[2];

        if (reachableOnly && !NPC_IsReachable(ent, vTarget)) {
            continue;
        }

        if (fNearestPlayerDistance < 0 || fDistance < fNearestPlayerDistance) {
            nearestPlayer = i;
            fNearestPlayerDistance = fDistance;
        }
    }

    if (nearestPlayer) {
        NPC_SetEnemy(ent, nearestPlayer);
    }

    return !!nearestPlayer;
}

stock NPC_MoveToTarget(ent, const Float:vTarget[3], Float:fSpeed, Float:fMaxAnglePerSecond = 180.0)
{
    new bool:lockAxis[3] = {true, false, true};
    lockAxis[0] = pev(ent, pev_movetype) != MOVETYPE_FLY;

    new Array:npcData = NPC_GetData(ent);
    new Float:fLastRotation = ArrayGetCell(npcData, NPC_LastRotation);
    new Float:fGameTime = get_gametime();

    new Float:fTimePassed = fGameTime - fLastRotation;
    new Float:fMaxAngle = (fTimePassed > 1.0)
            ? 0.0 // skip first rotation
            : fMaxAnglePerSecond * fTimePassed;

    new bool:turnResult = UTIL_TurnTo(ent, vTarget, lockAxis, fMaxAngle);

    if (fSpeed > 0.0 && turnResult) {
        set_pev(ent, pev_speed, fSpeed);
        NPC_MoveForward(ent, fSpeed);
    }

    ArraySetCell(npcData, NPC_LastRotation, fGameTime);
}

stock NPC_MoveForward(ent, Float:fSpeed)
{
    static Float:vDirection[3];
    UTIL_GetDirectionVector(ent, vDirection, fSpeed);

    static Float:vVelocity[3];
    pev(ent, pev_velocity, vVelocity);
    vDirection[2] = vVelocity[2];

    static Float:vAngles[3];
    pev(ent, pev_angles, vAngles);

    if (pev(ent, pev_movetype) != MOVETYPE_FLY) {
        engfunc(EngFunc_WalkMove, ent, vAngles[1], 0.5, WALKMOVE_NORMAL);
    }

    set_pev(ent, pev_velocity, vDirection);
}

stock bool:NPC_CanHit(ent, enemy, Float:fHitRange)
{
    new Array:npcData = NPC_GetData(ent);
    if (get_gametime() < ArrayGetCell(npcData, NPC_NextAttack)) {
        return false;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vTarget[3];
    pev(enemy, pev_origin, vTarget);

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, vOrigin, vTarget, DONT_IGNORE_MONSTERS, ent, trace);

    static Float:fFraction;
    get_tr2(trace, TR_flFraction, fFraction);

    if (fFraction == 1.0 && get_distance_f(vOrigin, vTarget) <= fHitRange) {
        return true;
    }

    new bool:result = false;
    if (get_tr2(trace, TR_pHit) == enemy) {
        get_tr2(trace, TR_vecEndPos, vTarget);
        result = (get_distance_f(vOrigin, vTarget) <= fHitRange);
    }

    free_tr2(trace);

    return result;
}

stock bool:NPC_IsValidEnemy(enemy)
{
    return (enemy && is_user_alive(enemy) && !UTIL_IsInvisible(enemy) && pev(enemy, pev_takedamage) != DAMAGE_NO);
}

stock NPC_IsVisible(ent, const Float:vTarget[3])
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new Array:npcData = NPC_GetData(ent);
    vOrigin[2] += Float:ArrayGetCell(npcData, NPC_ViewZOffset);

    return UTIL_IsOpen(vOrigin, vTarget, ent);
}

stock NPC_SetEnemy(ent, enemy)
{
    set_pev(ent, pev_enemy, enemy);

    if (enemy) {
        new Array:npcData = NPC_GetData(ent);
        ArraySetCell(npcData, NPC_EnemyTime, get_gametime());
    }
}

stock Float:NPC_GetEnemyTime(ent)
{
    new Array:npcData = NPC_GetData(ent);
    return ArrayGetCell(npcData, NPC_EnemyTime);
}
