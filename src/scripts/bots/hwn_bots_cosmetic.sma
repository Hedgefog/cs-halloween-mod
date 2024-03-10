#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>

#include <api_player_inventory>

#include <hwn>
#include <hwn_player_cosmetics>

#define PLUGIN "[Hwn] Bots Cosmetics"
#define AUTHOR "Hedgehog Fog"

#define COSMETIC_TIME 3600.0

new g_pCvarCosmeticsNum;
new g_iCosmeticsPluginId;

public plugin_precache() {
    g_pCvarCosmeticsNum = register_cvar("hwn_bots_cosmetics", "2");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_iCosmeticsPluginId = find_plugin_byfile("hwn_player_cosmetics.amxx");
}

public client_connect(pPlayer) {
    if (get_pcvar_num(g_pCvarCosmeticsNum) <= 0) return;
    if (!is_user_bot(pPlayer)) return;

    @Player_GiveAllCosmetic(pPlayer);
    @Player_EquipRandomCosmetics(pPlayer);
}

public PlayerInventory_Fw_SlotSave(pPlayer, iSlot) {
    if (PlayerInventory_CheckItemType(pPlayer, iSlot, "hwn_cosmetic")) {
        if (is_user_bot(pPlayer)) return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

@Player_GiveAllCosmetic(pPlayer) {
    new iNum = Hwn_PlayerCosmetic_GetCount();
    for (new i = 0; i < iNum; ++i) {
        static szCosmetic[32];
        Hwn_PlayerCosmetic_GetIdByIndex(i, szCosmetic, charsmax(szCosmetic));
        Hwn_Player_GiveCosmetic(pPlayer, szCosmetic, random(2) == 1 ? Hwn_PlayerCosmetic_Type_Unusual : Hwn_PlayerCosmetic_Type_Normal, COSMETIC_TIME);
    }
}

@Player_EquipRandomCosmetics(pPlayer) {
    new iMaxCosmetic = get_pcvar_num(g_pCvarCosmeticsNum);
    new iInventorySize = PlayerInventory_Size(pPlayer);

    new iTotal = 0;
    for (new iSlot = 0; iSlot < iInventorySize; ++iSlot) {
        if (!PlayerInventory_CheckItemType(pPlayer, iSlot, "hwn_cosmetic")) continue;
        if (!@Player_CanEquipInventorySlot(pPlayer, iSlot)) continue;
        if (random(100) > 30) continue;

        @Player_EquipInventorySlot(pPlayer, iSlot);
        iTotal++;

        if (iTotal >= iMaxCosmetic) break;
    }
}

bool:@Player_CanEquipInventorySlot(this, iSlot) {
    new iCanEquipFunctionId = get_func_id("@Player_CanEquipInventorySlot", g_iCosmeticsPluginId);
    callfunc_begin_i(iCanEquipFunctionId, g_iCosmeticsPluginId);
    callfunc_push_int(this);
    callfunc_push_int(iSlot);

    return bool:callfunc_end();
}

bool:@Player_EquipInventorySlot(this, iSlot) {
    new iCanEquipFunctionId = get_func_id("@Player_EquipInventorySlot", g_iCosmeticsPluginId);
    callfunc_begin_i(iCanEquipFunctionId, g_iCosmeticsPluginId);
    callfunc_push_int(this);
    callfunc_push_int(iSlot);

    return bool:callfunc_end();
}
