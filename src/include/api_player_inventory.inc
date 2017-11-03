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

native any:PInv_GetItem(id, slotIdx);
native PInv_ItemType:PInv_GetItemType(id, slotIdx);

native PInv_GiveItem(id, any:item, PInv_ItemType:itemType);
native PInv_TakeItem(id, slotIdx);

native PInv_SetItem(id, slotIdx, any:item, PInv_ItemType:itemType);

native PInv_Size(id);

forward PInv_Event_SlotLoaded(id, slotIdx);
forward PInv_Event_SlotSaved(id, slotIdx);
forward Pinv_Event_NewSlot(id, slotIdx);
forward Pinv_Event_TakeSlot(id, slotIdx);
forward PInv_Event_Destroy();