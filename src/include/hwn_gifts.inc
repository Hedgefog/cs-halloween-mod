#if defined _hwn_gifts_included
  #endinput
#endif
#define _hwn_gifts_included

#pragma reqlib hwn_gifts

native Hwn_Gifts_AddTarget(const Float:vecOrigin[3]);
native Hwn_Gifts_GetTargetCount();
native Hwn_Gifts_GetTarget(iTarget, Float:vecOrigin[3]);

forward Hwn_Gifts_Fw_GiftSpawn(pPlayer, pEntity);
forward Hwn_Gifts_Fw_GiftPicked(pPlayer, pEntity);
forward Hwn_Gifts_Fw_GiftDisappear(pPlayer, pEntity);
