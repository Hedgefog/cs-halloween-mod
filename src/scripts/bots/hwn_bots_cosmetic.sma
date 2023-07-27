#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

#include <hwn>
#include <api_player_inventory>
#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Bots Cosmetics"
#define AUTHOR "Hedgehog Fog"

#define COSMETIC_TIME 3600

new g_pCvarCosmeticsNum;

new g_rgiPlayerFirstSpawnFlag = 0;
new PInv_ItemType:g_hItemTypeCosmetic;

public plugin_precache() {
    g_pCvarCosmeticsNum = register_cvar("hwn_bots_cosmetics", "2");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

    g_hItemTypeCosmetic = PInv_GetItemTypeHandler("cosmetic");
}

public client_connect(pPlayer) {
    if (get_pcvar_num(g_pCvarCosmeticsNum) <= 0) {
        return;
    }

    if (!is_user_bot(pPlayer)) {
        return;
    }

    g_rgiPlayerFirstSpawnFlag |= BIT(pPlayer & 31);
}

public client_disconnected(pPlayer) {
    if (!is_user_bot(pPlayer)) {
        return;
    }

    g_rgiPlayerFirstSpawnFlag &= ~BIT(pPlayer & 31);

    TakeAllCosmetic(pPlayer);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_bot(pPlayer)) {
        return HAM_IGNORED;
    }

    if (g_rgiPlayerFirstSpawnFlag & BIT(pPlayer & 31)) {
        TakeAllCosmetic(pPlayer);
        GiveAllCosmetic(pPlayer);
        EquipRandomCosmetics(pPlayer);
        g_rgiPlayerFirstSpawnFlag &= ~BIT(pPlayer & 31);

        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

EquipRandomCosmetics(pPlayer) {
    new iMaxCosmetic = get_pcvar_num(g_pCvarCosmeticsNum);

    new iInvSize = PInv_Size(pPlayer);
    new iTotal = 0;

    for (new i = 0; i < iInvSize; ++i) {
        if (PInv_GetItemType(pPlayer, i) != g_hItemTypeCosmetic) {
            continue;
        }

        new iCosmetic = PCosmetic_GetItemCosmetic(pPlayer, i);
        if (!PCosmetic_CanBeEquiped(pPlayer, iCosmetic)) {
            continue;
        }
    
        if (random(100) > 30) {
            continue;
        }

        PCosmetic_Equip(pPlayer, i);
        iTotal++;

        if (iTotal >= iMaxCosmetic) {
            break;
        }
    }
}

GiveAllCosmetic(pPlayer) {
    new iNum = Hwn_Cosmetic_GetCount();
    for (new i = 0; i < iNum; ++i) {
        new iCosmetic = Hwn_Cosmetic_GetCosmetic(i);
        PCosmetic_Give(pPlayer, iCosmetic, random(2) == 1 ? PCosmetic_Type_Unusual : PCosmetic_Type_Normal, COSMETIC_TIME);
    }
}

TakeAllCosmetic(pPlayer) {
    new iInvSize = PInv_Size(pPlayer);

    for (new iSlot = 0; iSlot < iInvSize; ++iSlot) {
        if (PInv_GetItemType(pPlayer, iSlot) != g_hItemTypeCosmetic) {
            continue;
        }

        PCosmetic_Unequip(pPlayer, iSlot);
        PInv_TakeItem(pPlayer, iSlot);
    }
}
