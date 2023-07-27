#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Cosmetics"
#define AUTHOR "Hedgehog Fog"

new Array:g_irgCosmetics;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_Cosmetic_GetCount", "Native_GetCount");
    register_native("Hwn_Cosmetic_GetCosmetic", "Native_GetCosmetic");
    register_native("Hwn_Cosmetic_Register", "Native_RegisterCosmetic");
}

public plugin_end() {
    if (g_irgCosmetics != Invalid_Array) {
        ArrayDestroy(g_irgCosmetics);
    }
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_GetCount(iPluginId, iArgc) {
    if (g_irgCosmetics == Invalid_Array) {
        return 0;
    }

    return ArraySize(g_irgCosmetics);
}

public Native_GetCosmetic(iPluginId, iArgc) {
    if (g_irgCosmetics == Invalid_Array) {
        return -1;
    }

    new iCosmetic = get_param(1);
    return ArrayGetCell(g_irgCosmetics, iCosmetic);
}

public Native_RegisterCosmetic() {
    if (g_irgCosmetics == Invalid_Array) {
        g_irgCosmetics = ArrayCreate();
    }

    new hPCosmetic = get_param(1);
    ArrayPushCell(g_irgCosmetics, hPCosmetic);
}

public PCosmetic_Fw_EquipmentChanged(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    if (!Hwn_Gamemode_IsPlayerOnSpawn(pPlayer)) {
        return;
    }

    PCosmetic_UpdateEquipment(pPlayer);
}
