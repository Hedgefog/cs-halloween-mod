#if defined _api_player_cosmetic_included
  #endinput
#endif
#define _api_player_cosmetic_included

enum PCosmetic_Groups (<<=1)
{
    PCosmetic_Group_Hat = 1,
    PCosmetic_Group_Mask,
    PCosmetic_Group_Body,
    PCosmetic_Group_Back,
    PCosmetic_Group_Fanny,
    PCosmetic_Group_Legs,
    PCosmetic_Group_Cape
};

enum PCosmetic_Type
{
    PCosmetic_Type_Normal = 0,
    PCosmetic_Type_Unusual
};

native PCosmetic:PCosmetic_Register(const szName[], PCosmetic_Groups:groups, modelIndex, Float:fUnusualColor[3]);
native PCosmetic_Give(id, cosmetic, PCosmetic_Type:type, time);

native PCosmetic_Equip(id, slotIdx);
native PCosmetic_Unequip(id, slotIdx);
native bool:PCosmetic_IsItemEquiped(id, slotIdx);
native PCosmetic_UpdateEquipment(id);

native PCosmetic_GetItemCosmetic(id, slotIdx);
native PCosmetic_Type:PCosmetic_GetItemCosmeticType(id, slotIdx);
native PCosmetic_GetItemTime(id, slotIdx);

native PCosmetic_GetCosmeticName(cosmetic, szDest[], maxlen);
native PCosmetic_GetCosmeticGroups(cosmetic);

native PCosmetic_CanBeEquiped(id, cosmetic, ignoreSlotIdx = -1);

forward PCosmetic_Fw_EquipmentChanged(id);
