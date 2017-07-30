#if defined _roundcontrol_included
	#endinput
#endif

#define _roundcontrol_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib roundcontrol
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib roundcontrol
	#endif
#else
	#pragma library roundcontrol
#endif

#define DONT_REG			-1
#define BLOCK_BOTH			0
#define BLOCK_ONLY_EXPIRED		1

#define FLAG_RETRACT_EXPIRED		(1<<0)							/* Этот флаг убирает перехват функции HasRoundTimeExpired за ненадобностью. */

#define RC_NONE				0
#define RC_SOUND			(1<<0)							/* Воспроизводить звук победы. */
#define RC_MESSAGE			(1<<1)							/* Сообщение окончания раунда. ( Автоматически составляет сообщение по событии eventid ) */
#define RC_SCORE			(1<<2)							/* Прибавлять команде победные очки. */

#define RC_ALL_AUTO			(RC_SOUND|RC_SCORE)
#define RC_ALL_CUSTOM			(RC_SOUND|RC_MESSAGE|RC_SCORE)

#define ROUND_CONTINUE			0							/* Продолжает выполнение функции */
#define ROUND_SUPERCEDE			4							/* Блокирует дальнейшее выполнение функции */

enum (+= 4)
{
	m_bFreezePeriod = 4,
	m_bBombDropped,

	m_flRestartRoundTime = 48,		// +4 float	| W.48 | L.40
	m_flCheckWinConditions,			// +4 float	| W.52 | L.44
	m_fRoundCount,				// +4 float	| W.56 | L.48
	m_iRoundTime,				// +4 int	| W.60 | L.52
	m_iRoundTimeSecs,			// +4 int	| W.64 | L.56
	m_iIntroRoundTime,			// +4 int	| W.68 | L.60
	m_fIntroRoundCount,			// +4 int	| W.72 | L.64
	m_iAccountTerrorist,			// +4 int	| W.76 | L.68
	m_iAccountCT,				// +4 int	| W.80 | L.68
	m_iNumTerrorist,			// +4 int	| W.84 | L.76
	m_iNumCT,				// +4 int	| W.88 | L.80
	m_iNumSpawnableTerrorist,		// +4 int	| W.92 | L.84
	m_iNumSpawnableCT,			// +4 int	| W.96 | L.88
	m_iSpawnPointCount_Terrorist,		// +4 int	| W.100 | L.92
	m_iSpawnPointCount_CT,			// +4 int	| W.104 | L.96
	m_iHostagesRescued,			// +4 int	| W.108 | L.100
	m_iHostagesTouched,			// +4 int	| W.112 | L.104
	m_iRoundWinStatus,			// +4 int	| W.116 | L.108
	m_iNumCTWins,				// +2 short	| W.120 | L.112
	m_iNumTerroristWins = 122,		// +2 short	| W.122 | L.114
	m_bTargetBombed = 124,			// +1 bool	| W.124 | L.116
	m_bBombDefused = 125,			// +1 bool	| W.125 | L.117
	m_bMapHasBombTarget = 126,		// +1 bool	| W.126 | L.118
	m_bMapHasBombZone = 127,		// +1 bool	| W.127 | L.119
	m_bMapHasBuyZone = 128,			// +1 bool	| W.128 | L.120
	m_bMapHasRescueZone = 129,		// +1 bool	| W.129 | L.121
	m_bMapHasEscapeZone = 130,		// +1 bool	| W.130 | L.122
	m_iMapHasVIPSafetyZone = 132,		// +4 int	| W.132 | L.124
	m_bMapHasCameras,			// +4 bool	| W.136 | L.128
	m_iC4Timer,				// +4 int	| W.140 | L.132
	m_iC4Guy,				// +4 int	| W.144 | L.136
	m_iLoserBonus,				// +4 int	| W.148 | L.140
	m_iNumConsecutiveCTLoses,		// +4 int	| W.152 | L.144
	m_iNumConsecutiveTerroristLoses,	// +4 int	| W.156 | L.148
	m_fMaxIdlePeriod,			// +4 int	| W.160 | L.152
	m_iLimitTeams,				// +4 int	| W.164 | L.156
	m_bLevelInitialized,			// +1 bool	| W.168 | L.160
	m_bRoundTerminating = 169,		// +1 bool	| W.169 | L.161
	m_bCompleteReset = 170,			// +1 bool	| W.170 | L.162
	m_flRequiredEscapeRatio = 172,		// +4 float	| W.172 | L.164
	m_iNumEscapers,				// +4 float	| W.176 | L.168
	m_iHaveEscaped,				// +4 float	| W.180 | L.172
	m_bCTCantBuy,				// +1 bool	| W.184 | L.176
	m_bTCantBuy = 185,			// +1 bool	| W.185 | L.177
	m_flBombRadius = 188,			// +4 float	| W.188 | L.180
	m_iConsecutiveVIP,			// +4 float	| W.192 | L.184
	m_iTotalGunCount,			// +4 int	| W.196 | L.188
	m_iTotalGrenadeCount,			// +4 int	| W.200 | L.192
	m_iTotalArmourCount,			// +4 int	| W.204 | L.196
	m_iUnBalancedRounds,			// +4 int	| W.208 | L.200
	m_iNumEscapeRounds,			// +4 int	| W.212 | L.204
	m_iMapVotes,				// +400 int	| W.216 | L.208
	m_iLastPick = 616,			// +4 int	| W.616 | L.608
	m_iMaxMapTime,				// +4 int	| W.620 | L.612
	m_iMaxRounds,				// +4 int	| W.624 | L.616
	m_iTotalRoundsPlayed,			// +4 int	| W.628 | L.620
	m_iMaxRoundsWon,			// +4 int	| W.632 | L.624
	m_iStoredSpectValue,			// +4 int	| W.636 | L.628
	m_flForceCameraValue,			// +4 float	| W.640 | L.632
	m_flForceChaseCamValue,			// +4 float	| W.644 | L.636
	m_flFadeToBlackValue,			// +4 float	| W.648 | L.640
	m_pVIP,					// +4 pvdata	| W.652 | L.644
	VIPQueue,				// +20 pvdata	| W.656 | L.648
	m_flIntermissionEndTime = 676,		// +4 pvdata	| W.676 | L.668
	m_flIntermissionStartTime,		// +4 float	| W.680 | L.672
	m_iEndIntermissionButtonHit,		// +4 int	| W.684 | L.676
	m_tmNextPeriodicThink,			// +4 float	| W.688 | L.680
	m_bFirstConnected,			// +1 bool	| W.692 | L.684
	m_bInCareerGame = 693,			// +1 bool	| W.693 | L.685
	m_fCareerRoundMenuTime = 696,		// +4 float	| W.696 | L.688
	m_iCareerMatchWins,			// +4 int	| W.700 | L.692
	m_iRoundWinDifference,			// +4 int	| W.704 | L.696
	m_fCareerMatchMenuTime,			// +4 float	| W.708 | L.700
	m_bSkipSpawn				// +1 bool	| W.712 | L.704
};

enum RoundEvent
{
	EventDefault = 0,
	TargetBombed,
	VIPEscaped,
	VIPAssassinated,
	TerroristEscaped,
	CTsPreventEscape,
	EscapingTerroristNeutralized,
	BombDefused,
	CTsWin,
	TerroristWin,
	RoundDraw,
	AllHostagesRescued,
	TargetSaved,
	HostagesNotRescued,
	TerroristNotEscaped,
	VIPNotEscaped,
	GameCommencing
};

enum RoundControlWin
{
	WINSTATUS_CT = 1,
	WINSTATUS_TERRORIST,
	WINSTATUS_DRAW
};

enum RoundControlFunc
{
	/*
	* void
	*/
	RC_CheckWinConditions = 0,			// (void);

	/*
	 * teamWins - какая команда побеждает.
	 * numWins - победные очки.
	 * eventRound - событие окончание раунда.
	 * bHasExpired - раунд закончился по истечению времени.
	*/
	RC_RoundEnd					// (RoundControlWin:teamWins,numWins,RoundEvent:eventRound,bool:bHasExpired)
};

/*
 * Регистрация форварда
 *
*/
native RoundControlHook:RegisterControl(RoundControlFunc:function,const callback[],Post = 0);

/*
 * Удаление форварда
 *
*/
native UnregisterControl(RoundControlFunc:function,RoundControlHook:hookid,Post = 0);

/*
 * Позволяет составить условие для постоянной блокировки
 * 
*/
native RoundControlHook:SetBlockControl(RoundControlFunc:function,any:...);

/*
 * Удаляет блокировку
 * 
*/
native RemoveBlockControl(RoundControlFunc:function,RoundControlHook:hookid);

/**
 * Возобновляет вызов форварда
 *
*/
native EnableControl(RoundControlHook:hookid,Post = 0);

/**
 * Приостанавливает вызов форварда
 *
*/
native DisableControl(RoundControlHook:hookid,Post = 0);

/*
 * Вызов функции из gamedll, в частности функцию CheckWinConditions
 * Вызов RoundEnd имитирует конце раунда
 *
*/
native ExecuteControl(RoundControlFunc:function,any:...);

/*
 * Действует только для RoundEnd и только в PRE
 * Дает возможность изменить параметры, которые передается в функции. 
*/
native SetReturnParamControl(RoundControlFunc:function,any:...);

/*
 * Устанавливает особые флаги
 *
*/
native SetFlagsControl(const flags = FLAG_RETRACT_EXPIRED);

/*
 * Обновить табло счёта и установить/добавить очки команде.
 *
*/
native RoundUpdateScoreWins(ctsWins = 0,tsWins = 0,bool:bAdd = true);

/*
 * Принудительное окончание раунда.
 *
 * @param winStatus		Команда которая побеждает.
 * @param fDelay		Время (задержка), через которое наступит следующий раунд.
 * @param flags			Флаги RC_SOUND, RC_MESSAGE,RC_SCORE.
 * @param sentence		Своё сообщение о победе. (По умолчанию сообщение определяется по eventid)
 * @param eventid		Событие победы, "RoundEvent".
 * @param numScore		Сколько очков получает побежденная команда (По умолчанию +1)
 * @param bReset		Отбирать всю экипировку, фраги, смерти, победы в начале нового раунда. (Идентично sv_restart 1)
 *
 * @return			nothing
 */
native RoundEndForceControl(RoundControlWin:winStatus = WINSTATUS_CT,Float:fDelay = 5.0,flags = RC_ALL_CUSTOM,const sentence[] = "#Round_Draw",RoundEvent:eventid = EventDefault,numScore = 1,bool:bReset = false);

native set_pgame_int(_offset,_value,_linuxdiff = 8);

native get_pgame_int(_offset,_linuxdiff = 8);

native set_pgame_float(_offset,Float:_value,_linuxdiff = 8);

native Float:get_pgame_float(_offset,_linuxdiff = 8);

native set_pgame_short(_offset,Float:_value,_linuxdiff = 8);

native get_pgame_short(_offset,_linuxdiff = 8);

native set_pgame_bool(_offset,bool:_value,_linuxdiff = 8);

native bool:get_pgame_bool(_offset,_linuxdiff = 8);

native set_pgame_cbase(_Index_,_offset,_linuxdiff = 8);

native get_pgame_cbase(_offset,_linuxdiff = 8);

/*
* @return адрес указателя g_pGameRules
*/
native get_pgame_rules();
