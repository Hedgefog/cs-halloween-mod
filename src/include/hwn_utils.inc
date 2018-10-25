#define MENU_CHOOSEAPPEARANCE 3
#define JOIN_CHOOSEAPPEARANCE 4

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

stock UTIL_TurnTo(ent, const Float:vTarget[3], const bool:lockAxis[3] = {true, false, false}) 
{
    //Get user origin
    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    
    //Get sub vector from origin and target
    xs_vec_sub(vTarget, vOrigin, vOrigin);
    
    //Convert direction vector to angle
    new Float:vAngles[3];
    engfunc(EngFunc_VecToAngles, vOrigin, vAngles);

    for (new i = 0; i < 3; ++i) {
        if (lockAxis[i]) {
            vAngles[i] = 0.0;
        }
    }
    
    //Apply new angles
    set_pev(ent, pev_angles, vAngles);
    set_pev(ent, pev_v_angle, vAngles);
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
    color[3] = {255, 255, 255},
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