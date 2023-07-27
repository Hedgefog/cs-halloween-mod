#if defined _api_player_preview_included
  #endinput
#endif
#define _api_player_preview_included

#pragma reqlib api_player_preview

native bool:PlayerPreview_Activate(pPlayer, light);
native PlayerPreview_Deactivate(pPlayer);
native bool:PlayerPreview_IsActive(pPlayer);
