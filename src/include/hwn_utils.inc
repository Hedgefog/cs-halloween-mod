#define MENU_CHOOSEAPPEARANCE 3
#define JOIN_CHOOSEAPPEARANCE 4

#define GRAVITATIONAL_ACCELERATION_EARTH 9.807
#define GRAVITATIONAL_ACCELERATION_MOON 1.62
#define MOON_GRAVIY GRAVITATIONAL_ACCELERATION_MOON / GRAVITATIONAL_ACCELERATION_EARTH

stock const XO_CMapInfo = 4;
stock const m_fClientMapZone = 235;

#if !defined _reapi_included
    stock const m_iKevlar = 112;
    stock const m_iTeam = 114;
    stock const m_iJoiningState = 121;
    stock const m_iMenu = 205;
#endif

stock UTIL_DelayToLifeTime(Float:fDelay)
{
    new lifeTime = floatround(fDelay * 10);
    if (!lifeTime) {
        return 1;
    }
    
    return lifeTime;
}

stock Float:UTIL_FpsToDelay(fps)
{
    return (100/fps) * 0.01;
}

stock UTIL_StrToVec(const string[], Float:vector[3])
{
    new strOrigin[3][8];
    
    parse(
        string, 
        strOrigin[0], 7, 
        strOrigin[1], 7,
        strOrigin[2], 7
    );
    
    for (new i = 0; i < 3; ++i) {
        vector[i] = str_to_float(strOrigin[i]);
    }
}

stock Float:UTIL_CalculateRadiusDamage(const Float:vOrigin1[3], const Float:vOrigin2[3], Float:fRadius, Float:fMaxDamage)
{        
    new Float:fDistance = get_distance_f(vOrigin1, vOrigin2);        
    new Float:fDamage = fMaxDamage * (fRadius-fDistance)/fRadius;
    
    if (fDamage <= 0) {
        return 0.0;
    }
    
    return fDamage;
}

stock bool:UTIL_IsInvisible(ent)
{
    if (!pev_valid(ent)) {
        return false;
    }

    if (pev(ent, pev_rendermode) == kRenderNormal) {
        return false;
    }

    new Float:fRenderAmt;
    pev(ent, pev_renderamt, fRenderAmt);
    
    return (fRenderAmt < 50.0);
}

stock bool:UTIL_IsPlayer(id)
{
    return (id > 0 && id < 33);
}

stock UTIL_CS_DamagePlayer(victim, Float:fDamage, dmgbits = DMG_GENERIC, attacker = 0, inflictor = 0)
{
    #if defined _reapi_included
        new armorType = get_member(victim, m_iKevlar);
        set_member(victim, m_iKevlar, 0);
    #else
        new armorType = get_pdata_int(victim, m_iKevlar);
        set_pdata_int(victim, m_iKevlar, 0);
    #endif

    ExecuteHamB(Ham_TakeDamage, victim, inflictor, attacker, fDamage, dmgbits);

    #if defined _reapi_included
        set_member(victim, m_iKevlar, armorType);
    #else
        set_pdata_int(victim, m_iKevlar, armorType);
    #endif
}

stock Float:UTIL_GetDistanceToFloor(const Float:vOrigin[3], ignoreEnt = 0)
{
    new Float:vTarget[3];
    xs_vec_copy(vOrigin, vTarget);
    vTarget[2] -= 8192.0;

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, vOrigin, vTarget, IGNORE_MONSTERS, ignoreEnt, trace);
    get_tr2(trace, TR_vecEndPos, vTarget);
    free_tr2(trace);

    return (vOrigin[2] - vTarget[2]);
}

stock UTIL_SetSequence(ent, sequence)
{
    if (pev(ent, pev_sequence) == sequence) {
        return;
    }

    set_pev(ent, pev_frame, 0);
    set_pev(ent, pev_framerate, 1.0);
    set_pev(ent, pev_animtime, get_gametime());
    set_pev(ent, pev_sequence, sequence);
}


stock UTIL_GetDirectionVector(ent, Float:vOut[3], Float:fLength = 1.0)
{
    new Float:vAngles[3];
    pev(ent, pev_angles, vAngles);
    angle_vector(vAngles, ANGLEVECTOR_FORWARD, vOut);
    xs_vec_normalize(vOut, vOut);
    xs_vec_mul_scalar(vOut, fLength, vOut);
    vOut[2] = -vOut[2];
}

stock bool:UTIL_TurnTo(ent, const Float:vTarget[3], const bool:lockAxis[3] = {true, false, false}, const Float:fMaxAngle = -1.0) 
{
    //Get user origin
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new Float:vAngles[3];
    pev(ent, pev_angles, vAngles);

    static Float:vDiffAngles[3];
    {
        static Float:vSub[3];
        xs_vec_sub(vTarget, vOrigin, vSub);

        static Float:vSubAngles[3];
        engfunc(EngFunc_VecToAngles, vSub, vSubAngles);
        
        for (new i = 0; i < 3; ++i) {
            if (lockAxis[i]) {
                vDiffAngles[i] = 0.0;
                continue;
            }

            new Float:fDiff = vSubAngles[i] - vAngles[i];
            new direction = fDiff > 0 ? 1 : -1;
            new Float:fAbs = fDiff * direction;

            if (fAbs > 180.0) {
                vDiffAngles[i] = (180.0 - (fAbs - 180.0)) * -direction;
            } else {
                vDiffAngles[i] = fDiff;
            }
        }
    }
    

    new bool:turnResult = true;
    if (fMaxAngle >= 0.0) {
        new Float:fAngle = xs_vec_len(vDiffAngles);
        if (fAngle > fMaxAngle) {
            xs_vec_normalize(vDiffAngles, vDiffAngles);
            xs_vec_mul_scalar(vDiffAngles, fMaxAngle, vDiffAngles);
            turnResult = false;
        }
    }

    xs_vec_add(vAngles, vDiffAngles, vAngles);

    //Apply new angles
    set_pev(ent, pev_angles, vAngles);
    set_pev(ent, pev_v_angle, vAngles);

    return turnResult;
}

stock UTIL_Message_BloodSprite(const Float:vOrigin[3], sprBloodSpray, sprBlood, color, scale)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BLOODSPRITE);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_short(sprBloodSpray);
    write_short(sprBlood);
    write_byte(color);
    write_byte(scale);
    message_end();
}

stock UTIL_Message_BreakModel
(
    const Float:vOrigin[3], 
    const Float:vSize[3] = {16.0, 16.0, 16.0},
    const Float:vVelocity[3] = {0.0, 0.0, 0.0},
    speedNoise = 0,
    model = 0,
    count = 4,
    lifeTime = 1,
    flags = 0
)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BREAKMODEL);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, vSize[0]);
    engfunc(EngFunc_WriteCoord, vSize[1]);
    engfunc(EngFunc_WriteCoord, vSize[2]);
    engfunc(EngFunc_WriteCoord, vVelocity[0]);
    engfunc(EngFunc_WriteCoord, vVelocity[1]);
    engfunc(EngFunc_WriteCoord, vVelocity[2]);
    write_byte(speedNoise);
    write_short(model);
    write_byte(count);
    write_byte(lifeTime);
    write_byte(flags);
    message_end();
}

stock UTIL_Message_ExplodeModel
(
    const Float:vOrigin[3],
    const Float:fVelocity = 0.0,
    model = 0,
    count = 4,
    lifeTime = 1
)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_EXPLODEMODEL);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, fVelocity);
    write_short(model);
    write_short(count);
    write_byte(lifeTime);
    message_end();
}

stock UTIL_Message_Dlight
(
    const Float:vOrigin[3],
    radius = 16,
    const color[3] = {255, 255, 255},
    lifeTime = 1,
    decayRate = 0
)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_DLIGHT);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_byte(radius);
    write_byte(color[0]);
    write_byte(color[1]);
    write_byte(color[2]);
    write_byte(lifeTime);
    write_byte(decayRate);
    message_end();
}

stock UTIL_RandomVector(Float:min, Float:max, Float:vOut[3])
{
    for (new i = 0; i < 3; ++i) {
        vOut[i] = random_float(min, max);
    }
}

stock Array:UTIL_FindUsersNearby(Float:vOrigin[3], Float:fDistance, team = 0, bool:alive = true, maxPlayers = 32)
{
    new Array:users = ArrayCreate(1, maxPlayers);
    
    for (new id = 1; id <= maxPlayers; ++id)
    {
        if (!is_user_connected(id)) {
            continue;
        }
        
        if (alive && !is_user_alive(id)) {
            continue;
        }
        
        if (team && team != UTIL_GetPlayerTeam(id)) {
            continue;
        }
        
        static Float:vUserOrigin[3];
        pev(id, pev_origin, vUserOrigin);
        
        if (get_distance_f(vOrigin, vUserOrigin) > fDistance) {
            continue;
        }
        
        ArrayPushCell(users, id);
    }
    
    return users;
}

stock UTIL_FixedUnsigned16(const Float:fValue, const scale)
{
    return clamp(floatround(fValue * scale), 0, 0xFFFF);
}

stock UTIL_GetPlayerTeam(id)
{
    #if defined _reapi_included
        return get_member(id, m_iTeam);
    #else
        return get_pdata_int(id, m_iTeam);
    #endif
}

stock Array:UTIL_FindEntityNearby(const Float:vOrigin[3], const Float:fRadius)
{
    new Array:arr = ArrayCreate();

    new target;
    new prevTarget;
    while ((target = engfunc(EngFunc_FindEntityInSphere, target, vOrigin, fRadius)) != 0)
    {
        if (prevTarget >= target) {
            break; // infinite loop fix
        }

        prevTarget = target;

        if (!pev_valid(target)) {
            continue;
        }

        ArrayPushCell(arr, target);
    }

    return arr;
}

stock bool:UTIL_EntityIntersects(ent1, ent2)
{
    new Float:vAbsMin1[3];
    pev(ent1, pev_absmin, vAbsMin1);

    new Float:vAbsMax1[3];
    pev(ent1, pev_absmax, vAbsMax1);

    new Float:vAbsMin2[3];
    pev(ent2, pev_absmin, vAbsMin2);

    new Float:vAbsMax2[3];
    pev(ent2, pev_absmax, vAbsMax2);

    if (vAbsMin2[0] > vAbsMax1[0]
        || vAbsMin2[1] > vAbsMax1[1]
        || vAbsMin2[2] > vAbsMax1[2]
        || vAbsMax2[0] < vAbsMin1[0]
        || vAbsMax2[1] < vAbsMin1[1]
        || vAbsMax2[2] < vAbsMin1[2]) {
        return false;
    }

    return true;
}

stock bool:UTIL_FindPlaceToTeleport(ent, const Float:vTarget[3], Float:vOut[3], hull = HULL_POINT)
{
    static Float:vMins[3];
    pev(ent, pev_mins, vMins);

    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);

    if (UTIL_IsOpenHull(vTarget, hull, ent)) {
        xs_vec_copy(vTarget, vOut);
        return true;
    }

    for (new i = 0; i < 3; ++i) {
        static Float:vNewTarget[3];
        xs_vec_copy(vTarget, vNewTarget);

        vNewTarget[i] = vTarget[i] - vMins[i];
        if (UTIL_IsOpenHull(vNewTarget, hull, ent)) {
            xs_vec_copy(vNewTarget, vOut);
            return true;
        }

        vNewTarget[i] = vTarget[i] - vMaxs[i];
        if (UTIL_IsOpenHull(vNewTarget, hull, ent)) {
            xs_vec_copy(vNewTarget, vOut);
            return true;
        }
    }

    return false;
}

stock bool:UTIL_IsOpenHull(const Float:vOrigin[3], hull, ignoreEnt = 0)
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceHull, vOrigin, vOrigin, 0, hull, ignoreEnt, trace);
    new bool:isVacant = !!get_tr2(trace, TR_InOpen);
    free_tr2(trace);

    return isVacant;
}

stock bool:UTIL_IsStuck(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new trace = create_tr2();
    engfunc(EngFunc_TraceMonsterHull, ent, vOrigin, vOrigin, DONT_IGNORE_MONSTERS, ent, trace);
    new bool:isStuck = !get_tr2(trace, TR_InOpen);
    free_tr2(trace);

    return isStuck;
}

stock UTIL_Message_StatusIcon(id, status = 0, const szIcon[], const color[3])
{
    static msgid = 0;
    if(!msgid) {
        msgid = get_user_msgid("StatusIcon");
    }

    message_begin(id ? MSG_ONE : MSG_ALL, msgid, _, id);
    write_byte(status);
    write_string(szIcon);

    if (status) {
        write_byte(color[0]);
        write_byte(color[1]);
        write_byte(color[2]);
    }

    message_end();
}

stock UTIL_Message_StreakSplash(const Float:vOrigin[3], const Float:vDirection[3], color, count, speed, speedNoise = 0)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_STREAK_SPLASH);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, vDirection[0]);
    engfunc(EngFunc_WriteCoord, vDirection[1]);
    engfunc(EngFunc_WriteCoord, vDirection[2]);
    write_byte(color);
    write_short(count);
    write_short(speed);
    write_short(speedNoise);
    message_end();
}

stock UTIL_Message_UserTracer(const Float:vOrigin[3], const Float:vDirection[3], lifeTime, color, length)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_USERTRACER);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, vDirection[0]);
    engfunc(EngFunc_WriteCoord, vDirection[1]);
    engfunc(EngFunc_WriteCoord, vDirection[2]);
    write_byte(lifeTime);
    write_byte(color);
    write_byte(length);
    message_end();
}

stock UTIL_Message_Sound(const Float:vOrigin[3], const szSound[], Float:fVolume = VOL_NORM, Float:fAttn = ATTN_NORM, flags = 0, pitch = PITCH_NORM, ent = 0)
{
    new sndIndex = engfunc(EngFunc_PrecacheSound, szSound);

    engfunc(EngFunc_MessageBegin, MSG_ALL, SVC_SPAWNSTATICSOUND, vOrigin, 0);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_short(sndIndex);
    write_byte(floatround(fVolume * 255));
    write_byte(floatround(fAttn * 64));
    write_short(ent);        
    write_byte(pitch); 
    write_byte(flags);
    message_end();
}
