#if defined _hwn_stun_included
  #endinput
#endif
#define _hwn_stun_included

#pragma reqlib hwn_stun

#include <hwn_stun_const>

native Hwn_StunType:Hwn_Stun_Get(pPlayer);
native Hwn_Stun_Set(pPlayer, Hwn_StunType:value);
