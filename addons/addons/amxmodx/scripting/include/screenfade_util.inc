#if defined _screenfade_util_included
	#endinput
#endif
#define _screenfade_util_included

#define FFADE_IN			0x0000		// Just here so we don't pass 0 into the function
#define FFADE_OUT			0x0001		// Fade out (not in)
#define FFADE_MODULATE		0x0002		// Modulate (don't blend)
#define FFADE_STAYOUT		0x0004		// ignores the duration, stays faded out until new ScreenFade message received

enum {
	Red,
	Green,
	Blue
};

stock FixedUnsigned16(Float:flValue, iScale)
{
	new iOutput;

	iOutput = floatround(flValue * iScale);

	if ( iOutput < 0 )
		iOutput = 0;

	if ( iOutput > 0xFFFF )
		iOutput = 0xFFFF;

	return iOutput;
}

stock UTIL_ScreenFade(id=0,iColor[3]={0,0,0},Float:flFxTime=-1.0,Float:flHoldTime=0.0,iAlpha=0,iFlags=FFADE_IN,bool:bReliable=false,bool:bExternal=false)
{
	if( id && !is_user_connected(id))
		return;

	new iFadeTime;
	if( flFxTime == -1.0 )
	{
		iFadeTime = 4;
	}
	else
	{
		iFadeTime = FixedUnsigned16( flFxTime , 1<<12 );
	}

	static gmsgScreenFade;
	if( !gmsgScreenFade )
	{
		gmsgScreenFade = get_user_msgid("ScreenFade");
	}

	new MSG_DEST;
	if( bReliable )
	{
		MSG_DEST = id ? MSG_ONE : MSG_ALL;
	}
	else
	{
		MSG_DEST = id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST;
	}

	if( bExternal )
	{
		emessage_begin( MSG_DEST, gmsgScreenFade, _, id );
		ewrite_short( iFadeTime );
		ewrite_short( FixedUnsigned16( flHoldTime , 1<<12 ) );
		ewrite_short( iFlags );
		ewrite_byte( iColor[Red] );
		ewrite_byte( iColor[Green] );
		ewrite_byte( iColor[Blue] );
		ewrite_byte( iAlpha );
		emessage_end();
	}
	else
	{
		message_begin( MSG_DEST, gmsgScreenFade, _, id );
		write_short( iFadeTime );
		write_short( FixedUnsigned16( flHoldTime , 1<<12 ) );
		write_short( iFlags );
		write_byte( iColor[Red] );
		write_byte( iColor[Green] );
		write_byte( iColor[Blue] );
		write_byte( iAlpha );
		message_end();
	}
}

stock UTIL_FadeToBlack(id,Float:fxtime=3.0,bool:bReliable=false,bool:bExternal=false)
{
	UTIL_ScreenFade(id, _, fxtime, fxtime, 255, FFADE_OUT|FFADE_STAYOUT,bReliable,bExternal);
}