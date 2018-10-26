#include <hwn_utils>

enum _:NPC
{
    Float:NPC_NextAttack,
    Float:NPC_NextAction,
    Float:NPC_NextVoice,
    Float:NPC_NextFootStep,
    Float:NPC_LastReachablePoint,
    Float:NPC_ReachTime,
    Float:NPC_LastRotation
}

enum NPC_Action
{
    NPC_Action_StartSequence,
    NPC_Action_EndSequence,
    Float:NPC_Action_Time
};

stock NPC_Create(ent)
{
    new Array:npcData = ArrayCreate(1, _:NPC);    
    for (new i = 0; i < _:NPC; ++i) {
        ArrayPushCell(npcData, 0);
    }

    new Array:lastReachablePoint = ArrayCreate(3, 1);
    ArrayPushArray(lastReachablePoint, Float:{0.0, 0.0, 0.0});
    ArraySetCell(npcData, NPC_LastReachablePoint, lastReachablePoint);
    
    set_pev(ent, pev_iuser1, npcData);
}

stock NPC_Destroy(ent)
{
    new Array:npcData = NPC_GetData(ent);
    new Array:lastReachablePoint = ArrayGetCell(npcData, NPC_LastReachablePoint);
    ArrayDestroy(lastReachablePoint);
    
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
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    if (!NPC_IsVisible(vOrigin, vTarget, ent)) {
        return false;
    }
    
    if (pev(ent, pev_movetype) == MOVETYPE_FLY) {
        return true;
    }

    static Float:vMins[3];    
    pev(ent, pev_mins, vMins);
    
    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);

    {
        if (!NPC_IsVisibleWrapper(
            vOrigin[0], vOrigin[1], vOrigin[2] + vMaxs[2],
            vTarget[0], vTarget[1], vTarget[2] + vMaxs[2],
            ent
        )) {
            return false;
        }
        
        if (
            !NPC_IsVisibleWrapper(
                vOrigin[0], vOrigin[1], vOrigin[2] - vMins[2],
                vTarget[0], vTarget[1], vTarget[2] - vMins[2],
                ent
            )
            &&
            !NPC_IsVisibleWrapper(
                vOrigin[0], vOrigin[1], vOrigin[2] - vMins[2],
                vTarget[0], vTarget[1], vOrigin[2] - vMins[2],
                ent
            )
        ) {
            return false;
        }
    }
    
    
    static Float:vSide1[3];
    static Float:vSide2[3];
    NPC_GetSideLine(ent, vSide1, vSide2, vMaxs[0]);
    {
        {
            static Float:vTargetSide1[3];
            xs_vec_sub(vSide1, vOrigin, vTargetSide1);
            xs_vec_add(vTargetSide1, vTarget, vTargetSide1);
            
            if (!NPC_IsVisible(vSide1, vTargetSide1, ent)) {
                return false;
            }
        }

        {
            static Float:vTargetSide2[3];
            xs_vec_sub(vSide2, vOrigin, vTargetSide2);
            xs_vec_add(vTargetSide2, vTarget, vTargetSide2);
            
            if (!NPC_IsVisible(vSide2, vTargetSide2, ent)) {
                return false;
            }
        }
    }
    
    new Float:fDistance = get_distance_f(vOrigin, vTarget);
    new steps = floatround(fDistance/32.0);
    
    if (steps > 1)
    {        
        new Float:zOffset = UTIL_GetDistanceToFloor(vTarget, pev(ent, pev_enemy));
        vOrigin[2] -= zOffset - UTIL_GetDistanceToFloor(vOrigin, ent);
        
        //Get direction vetor
        static Float:vDirectionVector[3]; {
            xs_vec_sub(vTarget, vOrigin, vDirectionVector);
            xs_vec_normalize(vDirectionVector, vDirectionVector);
            xs_vec_mul_scalar(vDirectionVector, 32.0, vDirectionVector);
        }
        
        new Float:fZDiff = vOrigin[2] - vTarget[2];
        for (new i = 0; i < steps; ++i)
        {
            new Float:fMax = zOffset + 8.0;
            
            if (vOrigin[2] > vTarget[2]) {
                fMax += fZDiff;
            }

            xs_vec_add(vOrigin, vDirectionVector, vOrigin);
            xs_vec_add(vSide1, vDirectionVector, vSide1);
            xs_vec_add(vSide2, vDirectionVector, vSide2);
            
            static Float:fDistanceToFloor;
            fDistanceToFloor = UTIL_GetDistanceToFloor(vOrigin, ent);
            
            if (fDistanceToFloor > fMax) {
                fDistanceToFloor = UTIL_GetDistanceToFloor(vSide1, ent);
            }
            
            if (fDistanceToFloor > fMax) {
                fDistanceToFloor = UTIL_GetDistanceToFloor(vSide2, ent);
            }

            if (fDistanceToFloor > fMax) {
                return false;
            }
            
            if (!NPC_IsVisibleWrapper(
                vOrigin[0], vOrigin[1], vOrigin[2],
                vOrigin[0], vOrigin[1], vOrigin[2] - (fDistanceToFloor - zOffset),
                ent
            )) {
                return false;
            }
            
            if (vOrigin[2] > vTarget[2]) {
                fZDiff += zOffset - fDistanceToFloor;
            }
        }
    }

    return true;
}

stock bool:NPC_GetTarget(ent, Float:fSpeed, Float:vTarget[3], bool:reachableOnly = true)
{
    new enemy = pev(ent, pev_enemy);
    if (!enemy) {
        return false;
    }    
    
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    
    pev(enemy, pev_origin, vTarget);
    
    new Array:npcData = NPC_GetData(ent);
    new Array:lastReachablePoint = ArrayGetCell(npcData, NPC_LastReachablePoint);    
    
    new Float:fGameTime = get_gametime();
    if (!reachableOnly || NPC_IsReachable(ent, vTarget))
    {
        new Float:fDistance = get_distance_f(vOrigin, vTarget);
        new Float:fReachTime = fGameTime + fDistance/fSpeed;    
        
        ArraySetCell(npcData, NPC_ReachTime, fReachTime);
        ArraySetArray(lastReachablePoint, 0, vTarget);
    }
    else
    {
        new Float:fReachTime = ArrayGetCell(npcData, NPC_ReachTime);
        if (fGameTime < fReachTime) {
            ArrayGetArray(lastReachablePoint, 0, vTarget);
        } else {
            return false;
        }
    }
    
    return true;
}

stock bool:NPC_FindEnemy(ent, maxplayers = 32, bool:reachableOnly = true)
{
    new Array:targets = ArrayCreate();
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
        
        static Float:vOrigin[3];
        pev(i, pev_origin, vOrigin);
        
        if (reachableOnly && !NPC_IsReachable(ent, vOrigin)) {
            continue;
        }
        
        ArrayPushCell(targets, i);
    }
    
    new size = ArraySize(targets);
    if (size > 0) {
        new index = random(size);
        new enemy = ArrayGetCell(targets, index);        
        set_pev(ent, pev_enemy, enemy);
    }
    
    ArrayDestroy(targets);

    return (size > 0);
}

stock bool:NPC_IsVisible(const Float:vOrigin1[3], const Float:vOrigin2[3], ent = 0)
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, vOrigin1, vOrigin2, IGNORE_MONSTERS, ent, trace);
    
    new Float:fraction;
    get_tr2(trace, TR_flFraction, fraction);
    
    free_tr2(trace);
    return (fraction == 1.0);
}

stock bool:NPC_IsVisibleWrapper(Float:vOriginX, Float:vOriginY, Float:vOriginZ, Float:vTargetX, Float:vTargetY, Float:vTargetZ, ent = 0)
{
    static Float:vOrigin[3];
    vOrigin[0] = vOriginX;
    vOrigin[1] = vOriginY;
    vOrigin[2] = vOriginZ;
    
    static Float:vTarget[3];
    vTarget[0] = vTargetX;
    vTarget[1] = vTargetY;
    vTarget[2] = vTargetZ;
    
    return NPC_IsVisible(vOrigin, vTarget, ent);
}

stock NPC_GetSideLine(ent, Float:vOrigin1[3], Float:vOrigin2[3], Float:fLength = 48.0)
{
    static Float:vAngles[3];
    pev(ent, pev_angles, vAngles);
    
    static Float:vDirection[3];
    angle_vector(vAngles, ANGLEVECTOR_FORWARD, vDirection);
    
    xs_vec_mul_scalar(vDirection, fLength/2, vDirection);
    vDirection[2] = 0.0;
    
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);    

    new Float:fTemp;
    fTemp = vDirection[0];
    vDirection[0] = vDirection[1];
    vDirection[1] = fTemp;

    xs_vec_sub(vOrigin, vDirection, vOrigin1);
    xs_vec_add(vOrigin, vDirection, vOrigin2);
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
    
    if (get_tr2(trace, TR_pHit) == enemy) {
        get_tr2(trace, TR_vecEndPos, vTarget);    
        return (get_distance_f(vOrigin, vTarget) <= fHitRange);
    }
    
    free_tr2(trace);
    
    return false;
}

stock NPC_IsValidEnemy(enemy)
{
    return (enemy && is_user_alive(enemy) && !UTIL_IsInvisible(enemy) && pev(enemy, pev_takedamage) != DAMAGE_NO);
}