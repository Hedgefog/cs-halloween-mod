#include <amxmodx>
#include <hamsandwich>

#include <hwn>
#include <api_player_inventory>
#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Bots Cosmetics"
#define AUTHOR "Hedgehog Fog"

new g_cvarCosmeticCount;

new g_playerFirstSpawnFlag = 0;
new PInv_ItemType:g_hItemTypeCosmetic;

public plugin_precache()
{
    g_cvarCosmeticCount = register_cvar("hwn_bots_cosmetics", "2");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);

    g_hItemTypeCosmetic = PInv_GetItemTypeHandler("cosmetic");
}

public client_connect(id)
{
    if (get_pcvar_num(g_cvarCosmeticCount) <= 0) {
        return;
    }

    if (!is_user_bot(id)) {
        return;
    }

    g_playerFirstSpawnFlag |= (1 << (id & 31));
}

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    g_playerFirstSpawnFlag &= ~(1 << (id & 31));
}

public OnPlayerSpawn(id)
{
    if (!is_user_bot(id)) {
        return HAM_IGNORED;
    }

    if (g_playerFirstSpawnFlag & (1 << (id & 31))) {
        GiveAllCosmetic(id);
        EquipRandomCosmetics(id);
        g_playerFirstSpawnFlag &= ~(1 << (id & 31));

        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

EquipRandomCosmetics(id)
{
    new cosmeticLimit = get_pcvar_num(g_cvarCosmeticCount);
    new invSize = PInv_Size(id);
    new total = 0;

    for (new i = 0; i < invSize; ++i) {
        if (PInv_GetItemType(id, i) != g_hItemTypeCosmetic) {
            continue;
        }

        new cosmetic = PCosmetic_GetItemCosmetic(id, i);
        if (!PCosmetic_CanBeEquiped(id, cosmetic)) {
            continue;
        }
    
        if (random(100) > 30) {
            continue;
        }

        PCosmetic_Equip(id, i);
        total++;

        if (total >= cosmeticLimit) {
            break;
        }
    }
}

GiveAllCosmetic(id)
{
    new count = Hwn_Cosmetic_GetCount();
    for (new i = 0; i < count; ++i) {
        new cosmetic = Hwn_Cosmetic_GetCosmetic(i);
        PCosmetic_Give(id, cosmetic, random(2) == 1 ? PCosmetic_Type_Unusual : PCosmetic_Type_Normal, 999999);
    }
}