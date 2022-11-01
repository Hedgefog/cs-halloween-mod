#tryinclude <reapi>

#define MENU_CHOOSEAPPEARANCE 3
#define JOIN_CHOOSEAPPEARANCE 4

#define GRAVITATIONAL_ACCELERATION_EARTH 9.807
#define GRAVITATIONAL_ACCELERATION_MOON 1.62
#define MOON_GRAVIY GRAVITATIONAL_ACCELERATION_MOON / GRAVITATIONAL_ACCELERATION_EARTH

#define HUD_HIDE_TIMER (1<<4)

#if AMXX_VERSION_NUM < 183
    #define CSW_NONE                0
    #define CSW_LAST_WEAPON         CSW_P90
    #define CSW_ALL_WEAPONS         (~(1<<CSW_VEST))
    #define CSW_ALL_PISTOLS         (1<<CSW_P228  | 1<<CSW_ELITE | 1<<CSW_FIVESEVEN | 1<<CSW_USP | 1<<CSW_GLOCK18 | 1<<CSW_DEAGLE)
    #define CSW_ALL_SHOTGUNS        (1<<CSW_M3    | 1<<CSW_XM1014)
    #define CSW_ALL_SMGS            (1<<CSW_MAC10 | 1<<CSW_UMP45 | 1<<CSW_MP5NAVY | 1<<CSW_TMP  | 1<<CSW_P90)
    #define CSW_ALL_RIFLES          (1<<CSW_AUG   | 1<<CSW_GALIL | 1<<CSW_FAMAS   | 1<<CSW_M4A1 | 1<<CSW_AK47 | 1<<CSW_SG552)
    #define CSW_ALL_SNIPERRIFLES    (1<<CSW_SCOUT | 1<<CSW_AWP   | 1<<CSW_G3SG1   | 1<<CSW_SG550)
    #define CSW_ALL_MACHINEGUNS     (1<<CSW_M249)
    #define CSW_ALL_GRENADES        (1<<CSW_HEGRENADE | 1<<CSW_SMOKEGRENADE | 1<<CSW_FLASHBANG)
    #define CSW_ALL_ARMORS          (1<<CSW_VEST | 1<<CSW_VESTHELM)
    #define CSW_ALL_GUNS            (CSW_ALL_PISTOLS | CSW_ALL_SHOTGUNS | CSW_ALL_SMGS | CSW_ALL_RIFLES | CSW_ALL_SNIPERRIFLES | CSW_ALL_MACHINEGUNS)
#endif

stock const XO_CMapInfo = 4;
stock const m_fClientMapZone = 235;

#if !defined _reapi_included
    stock const m_iKevlar = 112;
    stock const m_iTeam = 114;
    stock const m_iJoiningState = 121;
    stock const m_iMenu = 205;
    stock const m_flNextPrimaryAttack = 46;
    stock const m_flNextSecondaryAttack = 47;
    stock const m_pActiveItem = 373;
    stock const m_pPlayer = 41;
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

stock Float:UTIL_CalculateRadiusDamage(
    const Float:vOrigin1[3],
    const Float:vOrigin2[3],
    Float:fRadius,
    Float:fMaxDamage,
    bool:ignoreObstacles = false,
    ignoreEnt = 0
)
{
    if (!ignoreObstacles && !UTIL_IsPointVisible(vOrigin1, vOrigin2, ignoreEnt)) {
        return 0.0;
    }

    new Float:fDistance = get_distance_f(vOrigin1, vOrigin2);

    new Float:fMultiplier = floatclamp((1.0 - ((fDistance - fRadius) / fRadius)), 0.0, 1.0);

    new Float:fDamage = fMaxDamage * fMultiplier;

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

stock bool:UTIL_IsTeammate(ent, team) {
    new targetTeam = UTIL_IsPlayer(ent) ? UTIL_GetPlayerTeam(ent) : pev(ent, pev_team);
    return team == targetTeam;
}

stock Float:UTIL_GetDistanceToFloor(ent, const Float:vOrigin[3])
{
    static Float:vTarget[3];
    xs_vec_copy(vOrigin, vTarget);
    vTarget[2] -= 8192.0;

    new trace = create_tr2();
    engfunc(EngFunc_TraceMonsterHull, ent, vOrigin, vTarget, IGNORE_MONSTERS, ent, trace);

    static Float:fFraction;
    get_tr2(trace, TR_flFraction, fFraction);
    
    if (fFraction == 1.0) {
        return -1.0;
    }

    static Float:vEnd[3];
    get_tr2(trace, TR_vecEndPos, vEnd);

    free_tr2(trace);

    return vOrigin[2] - vEnd[2];
}

stock bool:UTIL_IsPointVisible(const Float:vOrigin1[3], const Float:vOrigin2[3], ignoreEnt = 0)
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, vOrigin1, vOrigin2, IGNORE_MONSTERS, ignoreEnt, trace);

    static Float:fFraction;
    get_tr2(trace, TR_flFraction, fFraction);

    free_tr2(trace);

    return fFraction == 1.0;
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

stock bool:UTIL_IsTraceOpen(trace)
{   
    if (get_tr2(trace, TR_AllSolid)) {
        return false;
    }

    if (get_tr2(trace, TR_StartSolid)) {
        return false;
    }

    new Float:fFraction;
    get_tr2(trace, TR_flFraction, fFraction);

    if (fFraction < 1.0) {
        return false;
    }

    return true;
}

stock bool:UTIL_IsOpen(const Float:vOrigin1[3], const Float:vOrigin2[3], ent = 0, ignoreFlags = IGNORE_MONSTERS)
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, vOrigin1, vOrigin2, ignoreFlags, ent, trace);
    new bool:isOpen = UTIL_IsTraceOpen(trace);
    free_tr2(trace);

    return isOpen;
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
            } else {
                vDiffAngles[i] = UTIL_NormalizeAngle(vSubAngles[i] - vAngles[i]);
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

    for (new i = 0; i < 3; ++i) {
        vAngles[i] = UTIL_NormalizeAngle(vAngles[i]);
    }

    //Apply new angles
    set_pev(ent, pev_angles, vAngles);
    set_pev(ent, pev_v_angle, vAngles);

    return turnResult;
}

stock Float:UTIL_NormalizeAngle(Float:fAngle)
{
    new direction = fAngle > 0 ? 1 : -1;
    new Float:fAbsAngle = fAngle * direction;

    new Float:fFixedAngle = (fAbsAngle - (360.0 * floatround(fAbsAngle / 360.0, floatround_floor)));
    if (fFixedAngle > 180.0) {
      fFixedAngle -= 360.0;
    }

    fFixedAngle *= direction;

    return fFixedAngle;
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

stock UTIL_FindUsersNearby(startId = 0, Float:vOrigin[3], Float:fDistance, team = 0, bool:alive = true, maxPlayers = 32)
{
    for (new id = startId + 1; id <= maxPlayers; ++id)
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

        return id;
    }

    return 0;
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

stock Float:UTIL_GetNextPrimaryAttack(ent)
{
    #if defined _reapi_included
        return get_member(ent, m_Weapon_flNextPrimaryAttack);
    #else
        return get_pdata_float(ent, m_flNextPrimaryAttack, 4);
    #endif
}

stock UTIL_SetNextPrimaryAttack(ent, Float:fValue)
{
    #if defined _reapi_included
        set_member(ent, m_Weapon_flNextPrimaryAttack, fValue);
    #else
        set_pdata_float(ent, m_flNextPrimaryAttack, fValue, 4);
    #endif
}

stock Float:UTIL_GetNextSecondaryAttack(ent)
{
    #if defined _reapi_included
        return get_member(ent, m_Weapon_flNextSecondaryAttack);
    #else
        return get_pdata_float(ent, m_flNextSecondaryAttack, 4);
    #endif
}

stock UTIL_SetNextSecondaryAttack(ent, Float:fValue)
{
    #if defined _reapi_included
        set_member(ent, m_Weapon_flNextSecondaryAttack, fValue);
    #else
        set_pdata_float(ent, m_flNextSecondaryAttack, fValue, 4);
    #endif
}

stock UTIL_GetPlayerActiveItem(id)
{
    #if defined _reapi_included
        return get_member(id, m_pActiveItem);
    #else
        return get_pdata_cbase(id, m_pActiveItem);
    #endif
}

stock UTIL_GetItemPlayer(ent)
{
    #if defined _reapi_included
        return get_member(ent, m_pPlayer);
    #else
        return get_pdata_cbase(ent, m_pPlayer, 4);
    #endif
}

stock UTIL_FindEntityNearby(startEnt = 0, const Float:vOrigin[3], const Float:fRadius)
{

    new target = engfunc(EngFunc_FindEntityInSphere, startEnt, vOrigin, fRadius);
    if (target <= startEnt) {
        return 0; // infinite loop fix
    }

    if (!pev_valid(target)) {
        return 0;
    }

    return target;
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

stock bool:UTIL_FindPlaceToTeleport(ent, const Float:vTarget[3], Float:vOut[3], hull = HULL_POINT, ignoreFlags = DONT_IGNORE_MONSTERS)
{
    static Float:vMins[3];
    pev(ent, pev_mins, vMins);

    static Float:vMaxs[3];
    pev(ent, pev_maxs, vMaxs);

    if (UTIL_IsOpenHull(vTarget, hull, ent, ignoreFlags)) {
        xs_vec_copy(vTarget, vOut);
        return true;
    }

    static const Float:vDirections[][3] = {
        { 1.0, 0.0, 0.0 },
        { 0.0, 1.0, 0.0 },
        { 0.0, 0.0, 1.0 },
        { 1.0, 1.0, 0.0 },
        { 0.0, 1.0, 1.0 },
        { 1.0, 0.0, 1.0 },
        { 1.0, 1.0, 1.0 }
    };
    
    new directionsNum = sizeof(vDirections);

    for (new i = 0; i < directionsNum; ++i) {
        static Float:vNewTarget[3];
        xs_vec_copy(vTarget, vNewTarget);

        for (new j = 0; j < 3; ++j) {
            vNewTarget[j] = vTarget[j] + (vMins[j] * vDirections[i][j]);
        }

        if (UTIL_IsOpenHull(vNewTarget, hull, ent, ignoreFlags)) {
            xs_vec_copy(vNewTarget, vOut);
            return true;
        }

        for (new j = 0; j < 3; ++j) {
            vNewTarget[j] = vTarget[j] + (vMaxs[j] * vDirections[i][j]);
        }

        if (UTIL_IsOpenHull(vNewTarget, hull, ent, ignoreFlags)) {
            xs_vec_copy(vNewTarget, vOut);
            return true;
        }
    }

    return false;
}

stock bool:UTIL_IsOpenHull(const Float:vOrigin[3], hull, ignoreEnt = 0, ignoreFlags = DONT_IGNORE_MONSTERS)
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceHull, vOrigin, vOrigin, ignoreFlags, hull, ignoreEnt, trace);
    new bool:isVacant = !!get_tr2(trace, TR_InOpen);
    free_tr2(trace);

    return isVacant;
}

stock UTIL_GetViewOrigin(id, Float:vOut[3])
{
    static Float:vStart[3];
    pev(id, pev_origin, vStart);

    static Float:vViewOfs[3];
    pev(id, pev_view_ofs, vViewOfs);

    xs_vec_copy(vStart, vOut);
    vOut[2] += vViewOfs[2];
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

stock UTIL_Message_HideWeapon(id, flags)
{
    static msgid = 0;
    if(!msgid) {
        msgid = get_user_msgid("HideWeapon");
    }

    message_begin(id ? MSG_ONE : MSG_ALL, msgid, _, id);
    write_byte(flags);
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

stock UTIL_Message_BeamCylinder(
    const Float:vOrigin[3],
    Float:fRadius,
    modelIndex = 0,
    startFrame = 0,
    lifeTime = 1,
    width = 0,
    noise = 0,
    const color[3] = {255, 255, 255},
    brightness = 255,
    speed = 255
)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BEAMCYLINDER);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, vOrigin[2] + fRadius);
    write_short(modelIndex);
    write_byte(startFrame);
    write_byte(0);
    write_byte(lifeTime);
    write_byte(width);
    write_byte(noise);
    write_byte(color[0]);
    write_byte(color[1]);
    write_byte(color[2]);
    write_byte(brightness);
    write_byte(speed);
    message_end();
}

stock UTIL_Message_BeamTorus(
    const Float:vOrigin[3],
    Float:fRadius,
    modelIndex = 0,
    startFrame = 0,
    lifeTime = 1,
    width = 0,
    noise = 0,
    const color[3] = {255, 255, 255},
    brightness = 255,
    speed = 255
)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BEAMTORUS);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, vOrigin[2] + fRadius);
    write_short(modelIndex);
    write_byte(startFrame);
    write_byte(0);
    write_byte(lifeTime);
    write_byte(width);
    write_byte(noise);
    write_byte(color[0]);
    write_byte(color[1]);
    write_byte(color[2]);
    write_byte(brightness);
    write_byte(speed);
    message_end();
}

stock UTIL_Message_BeamDisk(
    const Float:vOrigin[3],
    Float:fRadius,
    modelIndex = 0,
    startFrame = 0,
    lifeTime = 1,
    width = 0,
    noise = 0,
    const color[3] = {255, 255, 255},
    brightness = 255,
    speed = 255
)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BEAMDISK);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, 0.0);
    engfunc(EngFunc_WriteCoord, vOrigin[2] + fRadius);
    write_short(modelIndex);
    write_byte(startFrame);
    write_byte(0);
    write_byte(lifeTime);
    write_byte(width);
    write_byte(noise);
    write_byte(color[0]);
    write_byte(color[1]);
    write_byte(color[2]);
    write_byte(brightness);
    write_byte(speed);
    message_end();
}

stock UTIL_Message_BeamEnts(
    ent1,
    ent2,
    modelIndex,
    startFrame = 0,
    frameRate = 0,
    lifeTime = 1,
    width = 0,
    noise = 0,
    const color[3] = {255, 255, 255},
    brightness = 255,
    speed = 0
)
{
    static Float:vOrigin[3];
    pev(ent1, pev_origin, vOrigin);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BEAMENTS);
    write_short(ent1);
    write_short(ent2);
    write_short(modelIndex);
    write_byte(startFrame);
    write_byte(frameRate);
    write_byte(lifeTime);
    write_byte(width);
    write_byte(noise);
    write_byte(color[0]);
    write_byte(color[1]);
    write_byte(color[2]);
    write_byte(brightness);
    write_byte(speed);
    message_end();
}

stock UTIL_Message_ParticleBurst(const Float:vOrigin[3], radius, color, lifeTime = 1)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_PARTICLEBURST);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_short(radius);
    write_byte(color);
    write_byte(lifeTime);
    message_end();
}

stock UTIL_Message_RoundTime(id, time)
{
    static msgid = 0;
    if(!msgid) {
        msgid = get_user_msgid("RoundTime");
    }

    message_begin(id ? MSG_ONE : MSG_ALL, msgid);
    write_short(time);
    message_end();
}

stock UTIL_Message_Blood(const Float:vOrigin[3], const Float:vDirection[3], color = 0, speed = 255)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_BLOOD);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, vDirection[0]);
    engfunc(EngFunc_WriteCoord, vDirection[1]);
    engfunc(EngFunc_WriteCoord, vDirection[2]);
    write_byte(color);
    write_byte(speed);
    message_end();
}

stock UTIL_Message_Sprite(const Float:vOrigin[3], modelIndex, scale, alpha)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_SPRITE);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    write_short(modelIndex);
    write_byte(scale);
    write_byte(alpha);
    message_end();
}

stock UTIL_Message_Sparks(const Float:vOrigin[3])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_SPARKS);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    message_end();
}

stock UTIL_Message_SpriteTrail(const Float:vStart[3], const Float:vEnd[3], modelIndex, count, lifeTime, scale, speed, noise)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vStart, 0);
    write_byte(TE_SPRITETRAIL);
    engfunc(EngFunc_WriteCoord, vStart[0]);
    engfunc(EngFunc_WriteCoord, vStart[1]);
    engfunc(EngFunc_WriteCoord, vStart[2]);
    engfunc(EngFunc_WriteCoord, vEnd[0]);
    engfunc(EngFunc_WriteCoord, vEnd[1]);
    engfunc(EngFunc_WriteCoord, vEnd[2]);
    write_short(modelIndex);
    write_byte(count);
    write_byte(lifeTime);
    write_byte(scale);
    write_byte(speed);
    write_byte(noise);
    message_end();
}

stock UTILS_Message_Projectile(const Float:vOrigin[3], const Float:vVelocity[3], modelIndex, lifeTime, owner)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
    write_byte(TE_PROJECTILE);
    engfunc(EngFunc_WriteCoord, vOrigin[0]);
    engfunc(EngFunc_WriteCoord, vOrigin[1]);
    engfunc(EngFunc_WriteCoord, vOrigin[2]);
    engfunc(EngFunc_WriteCoord, vVelocity[0]);
    engfunc(EngFunc_WriteCoord, vVelocity[1]);
    engfunc(EngFunc_WriteCoord, vVelocity[2]);
    write_short(modelIndex);
    write_byte(lifeTime);
    write_byte(owner);
    message_end();
}

stock UTIL_CreateDictKey(const szName[], const szPrefix[] = "", szOut[], len)
{
    copy(szOut, len, szName);
    strtoupper(szOut);
    replace_all(szOut, len, " ", "_");
    format(szOut, len, "%s%s", szPrefix, szOut);
}

stock bool:UTIL_IsLocalizationExists(const szKey[])
{
    new szBuffer[16];
    format(szBuffer, charsmax(szBuffer), "%L", LANG_SERVER, szKey);

    new szNotFound[] = "ML_NOTFOUND:";

    return !equali(szBuffer, szNotFound, sizeof(szNotFound) - 1);
}

stock UTIL_PushFromOrigin(const Float:vOrigin[3], ent, Float:fImpulse)
{
    static Float:vTargetOrigin[3];
    pev(ent, pev_origin, vTargetOrigin);

    static Float:vVelocity[3];
    xs_vec_sub(vTargetOrigin, vOrigin, vVelocity);
    xs_vec_normalize(vVelocity, vVelocity);
    xs_vec_mul_scalar(vVelocity, fImpulse, vVelocity);

    static Float:vTargetVelocity[3];
    pev(ent, pev_velocity, vTargetVelocity);
    xs_vec_add(vTargetVelocity, vVelocity, vTargetVelocity);
    set_pev(ent, pev_velocity, vTargetVelocity);
}
