#define MENU_CHOOSEAPPEARANCE 3
#define JOIN_CHOOSEAPPEARANCE 4

stock const XO_CMapInfo = 4;

stock const m_iKevlar = 112;
stock const m_iTeam = 114;
stock const m_iJoiningState = 121;
stock const m_iMenu = 205;
stock const m_fClientMapZone = 235;

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
	new armorType = get_pdata_int(victim, m_iKevlar);
	set_pdata_int(victim, m_iKevlar, 0);
	ExecuteHamB(Ham_TakeDamage, victim, inflictor, attacker, fDamage, dmgbits);
	set_pdata_int(victim, m_iKevlar, armorType);
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
}

stock UTIL_TurnTo(ent, const Float:vTarget[3]) 
{
	//Get user origin
	new Float:vOrigin[3];
	pev(ent, pev_origin, vOrigin);
	
	//Get sub vector from origin and target
	xs_vec_sub(vTarget, vOrigin, vOrigin);
	
	//Convert direction vector to angle
	new Float:vAngles[3];
	engfunc(EngFunc_VecToAngles, vOrigin, vAngles);
	vAngles[0] = 0.0; //Disable x rotation
	vAngles[2] = 0.0; //Disable z rotation
	
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
		
		if (team && team != get_pdata_int(id, m_iTeam)) {
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

stock UTIL_SpellballDetonateEffect(modelindex, const Float:vOrigin[3], const Float:fColor[3], Float:fRadius)
{
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]+fRadius);
	write_short(modelindex);
	write_byte(0);
	write_byte(0);
	write_byte(5);
	write_byte(floatround(fRadius/2));
	write_byte(0);
	write_byte(floatround(fColor[0]));
	write_byte(floatround(fColor[1]));
	write_byte(floatround(fColor[2]));
	write_byte(255);
	write_byte(0);
	message_end();
}