#if defined _api_player_preview_included
  #endinput
#endif
#define _api_player_preview_included

#pragma reqlib api_player_preview

native bool:PlayerPreview_Activate(id, light);
native PlayerPreview_Deactivate(id);
native bool:PlayerPreview_IsActive(id);
