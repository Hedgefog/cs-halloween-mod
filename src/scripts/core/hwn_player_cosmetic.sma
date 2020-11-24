#pragma semicolon 1

#include <amxmodx>

#include <hwn>
#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Cosmetics"
#define AUTHOR "Hedgehog Fog"

new Array:g_cosmetics;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_Cosmetic_GetCount", "Native_GetCount");
    register_native("Hwn_Cosmetic_GetCosmetic", "Native_GetCosmetic");
    register_native("Hwn_Cosmetic_Register", "Native_RegisterCosmetic");
}

public plugin_end()
{
    if (g_cosmetics != Invalid_Array) {
        ArrayDestroy(g_cosmetics);
    }
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_GetCount(pluginID, argc)
{
    if (g_cosmetics == Invalid_Array) {
        return 0;
    }

    return ArraySize(g_cosmetics);
}

public Native_GetCosmetic(pluginID, argc)
{
    if (g_cosmetics == Invalid_Array) {
        return -1;
    }

    new index = get_param(1);
    return ArrayGetCell(g_cosmetics, index);
}

public Native_RegisterCosmetic()
{
    if (g_cosmetics == Invalid_Array) {
        g_cosmetics = ArrayCreate();
    }

    new hPCosmetic = get_param(1);
    ArrayPushCell(g_cosmetics, hPCosmetic);
}

public PCosmetic_Fw_EquipmentChanged(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    if (!Hwn_Gamemode_IsPlayerOnSpawn(id)) {
        return;
    }

    PCosmetic_UpdateEquipment(id);
}
