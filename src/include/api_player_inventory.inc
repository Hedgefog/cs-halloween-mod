#if defined _api_player_inventory_included
  #endinput
#endif
#define _api_player_inventory_included

enum PInv_ItemType
{
    PInv_Invalid_ItemType = -1
};

native PInv_ItemType:PInv_RegisterItemType(const szTypeName[]);
native PInv_ItemType:PInv_GetItemTypeHandler(const szTypeName[]);

native any:PInv_GetItem(pPlayer, slotIdx);
native PInv_ItemType:PInv_GetItemType(pPlayer, slotIdx);

native PInv_GiveItem(pPlayer, any:item, PInv_ItemType:itemType);
native PInv_TakeItem(pPlayer, slotIdx);

native PInv_SetItem(pPlayer, slotIdx, any:item, PInv_ItemType:itemType);

native PInv_Size(pPlayer);

forward PInv_Event_SlotLoaded(pPlayer, slotIdx);
forward PInv_Event_SlotSaved(pPlayer, slotIdx);
forward Pinv_Event_NewSlot(pPlayer, slotIdx);
forward Pinv_Event_TakeSlot(pPlayer, slotIdx);
forward PInv_Event_Destroy();