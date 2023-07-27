#if defined _api_player_burn_included
  #endinput
#endif
#define _api_player_burn_included

#pragma reqlib api_player_burn

native extinguish_player(pPlayer);
native burn_player(pPlayer, inflictor = 0, burnTime = 0);
native is_player_burn(pPlayer);