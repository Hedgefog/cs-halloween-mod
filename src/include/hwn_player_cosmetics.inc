#if defined _hwn_player_cosmetics_included
  #endinput
#endif
#define _hwn_player_cosmetics_included

#pragma reqlib hwn_player_cosmetics

enum Hwn_PlayerCosmetic_Group (<<=1) {
    Hwn_PlayerCosmetic_Group_Hat = 1,
    Hwn_PlayerCosmetic_Group_Mask,
    Hwn_PlayerCosmetic_Group_Body,
    Hwn_PlayerCosmetic_Group_Back,
    Hwn_PlayerCosmetic_Group_Fanny,
    Hwn_PlayerCosmetic_Group_Legs,
    Hwn_PlayerCosmetic_Group_Cape
};

enum Hwn_PlayerCosmetic_Type {
    Hwn_PlayerCosmetic_Type_Normal = 0,
    Hwn_PlayerCosmetic_Type_Unusual
};

stock const Hwn_PlayerCosmetic_GroupNames[][] = { "hat", "mask", "body", "back", "fanny", "legs", "cape" };

native PCosmetic:Hwn_PlayerCosmetic_Register(const szCosmetic[], Hwn_PlayerCosmetic_Group:iGroups, iModelIndex, Float:flUnusualColor[3]);
native Hwn_PlayerCosmetic_GetCount();
native Hwn_PlayerCosmetic_GetIdByIndex(iIndex, szId[], iLen);

native Hwn_Player_UpdateCosmetics(pPlayer);
native Hwn_Player_OpenCosmeticsMenu(pPlayer);
native Hwn_Player_GiveCosmetic(pPlayer, const szCosmetic[], Hwn_PlayerCosmetic_Type:iType, Float:flTime);

forward Hwn_Player_Fw_CosmeticsChanged(pPlayer);
