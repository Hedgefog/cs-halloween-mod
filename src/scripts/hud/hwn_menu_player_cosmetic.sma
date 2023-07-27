#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

#include <api_player_inventory>
#include <api_player_cosmetic>
#include <api_player_camera>

#include <hwn>

#define PLUGIN "[Hwn] Menu Player Cosmetic"
#define AUTHOR "Hedgehog Fog"

#define PREVIEW_CAMERA_ANGLES Float:{15.0, 180.0, 0.0}
#define PREVIEW_CAMERA_DISTANCE 96.0
#define PREVIEW_CAMERA_LIGHT_RADIUS 4
#define PREVIEW_CAMERA_LIGHT_BRIGHTNESS 1.0
#define PREVIEW_CAMERA_LIGHT_LIFETIME 5
#define PREVIEW_CAMERA_LIGHT_DECAYRATE 1

new g_pCvarPreview;
new g_pCvarPreviewLight;

new PInv_ItemType:g_iCosmeticItemType;

new Array:g_rgirgPlayerMenuSlotRefs[MAX_PLAYERS + 1] = { Invalid_Array, ... };
new bool:g_rbPlayerInPreview[MAX_PLAYERS + 1];
new Float:g_rgflPlayerNextHighlight[MAX_PLAYERS + 1];

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarPreview = register_cvar("hwn_pcosmetic_menu_preview", "1");
    g_pCvarPreviewLight = register_cvar("hwn_pcosmetic_menu_preview_light", "1");

    g_iCosmeticItemType = PInv_GetItemTypeHandler("cosmetic");

    register_forward(FM_AddToFullPack, "FMHook_AddToFullPack", 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink_Post", .Post = 1);
}

public plugin_natives() {
    register_library("menu_player_cosmetic");
    register_native("PCosmetic_Menu_Open", "Native_Open");
}

public plugin_end() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (g_rgirgPlayerMenuSlotRefs[pPlayer] != Invalid_Array) {
            ArrayDestroy(g_rgirgPlayerMenuSlotRefs[pPlayer]);
        }
    }
}

public Native_Open(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    @Player_OpenMenu(pPlayer, 0);
}

public client_disconnected(pPlayer) {
    @Player_DeactivatePreview(pPlayer);
}

public HamHook_Player_Killed(pPlayer) {
    @Player_DeactivatePreview(pPlayer);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    @Player_DeactivatePreview(pPlayer);
}

public HamHook_Player_PreThink_Post(pPlayer) {
    if (g_rgflPlayerNextHighlight[pPlayer] && g_rgflPlayerNextHighlight[pPlayer] <= get_gametime()) {
      static Float:vecOrigin[3];
      pev(pPlayer, pev_origin, vecOrigin);

      new iBrightness = floatround(255 * PREVIEW_CAMERA_LIGHT_BRIGHTNESS);

      engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vecOrigin, pPlayer);
      write_byte(TE_DLIGHT);
      engfunc(EngFunc_WriteCoord, vecOrigin[0]);
      engfunc(EngFunc_WriteCoord, vecOrigin[1]);
      engfunc(EngFunc_WriteCoord, vecOrigin[2]);
      write_byte(PREVIEW_CAMERA_LIGHT_RADIUS);
      write_byte(iBrightness);
      write_byte(iBrightness);
      write_byte(iBrightness);
      write_byte(PREVIEW_CAMERA_LIGHT_LIFETIME);
      write_byte(PREVIEW_CAMERA_LIGHT_DECAYRATE);
      message_end();

      g_rgflPlayerNextHighlight[pPlayer] = get_gametime() + (PREVIEW_CAMERA_LIGHT_DECAYRATE * 0.1);
    }
}

public FMHook_AddToFullPack(es, e, pEntity, host, hostflags, player, pSet) {
    if (pEntity != host) {
        return;
    }

    if (!is_user_alive(pEntity)) {
        return;
    }

    if (g_rbPlayerInPreview[pEntity]) {
        set_es(es, ES_Sequence, 64);
        set_es(es, ES_GaitSequence, 1);
        set_es(es, ES_RenderMode, kRenderNormal);
        set_es(es, ES_RenderFx, kRenderFxNone);
        set_es(es, ES_RenderAmt, 255.0);
        set_es(es, ES_MoveType, MOVETYPE_NONE); // disable blending
    }
}

@Player_OpenMenu(pPlayer, iPage) {
    new iMenu = CreateMenu(pPlayer);

    menu_display(pPlayer, iMenu, iPage);

    if (get_pcvar_num(g_pCvarPreview) > 0 && Hwn_Gamemode_IsPlayerOnSpawn(pPlayer)) {
        new bool:bLight = get_pcvar_num(g_pCvarPreviewLight) > 0;
        @Player_ActivatePreview(pPlayer, bLight);
    }
}

bool:@Player_ActivatePreview(pPlayer, bool:bLight) {
    if (!is_user_alive(pPlayer)) {
        return false;
    }

    if (PlayerCamera_IsActive(pPlayer)) {
        return false;
    }

    set_pev(pPlayer, pev_velocity, Float:{0.0, 0.0, 0.0});
    set_pev(pPlayer, pev_avelocity, Float:{0.0, 0.0, 0.0});
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) | FL_FROZEN);

    PlayerCamera_Activate(pPlayer);
    PlayerCamera_SetDistance(pPlayer, PREVIEW_CAMERA_DISTANCE);
    PlayerCamera_SetAngles(pPlayer, PREVIEW_CAMERA_ANGLES);
    // PlayerCamera_SetOffset(pPlayer);
    PlayerCamera_SetThinkDelay(pPlayer, 1.0);

    g_rbPlayerInPreview[pPlayer] = true;
    g_rgflPlayerNextHighlight[pPlayer] = bLight ? get_gametime() : 0.0;

    return true;
}

@Player_DeactivatePreview(pPlayer) {
    if (!g_rbPlayerInPreview[pPlayer]) {
        return;
    }

    PlayerCamera_Deactivate(pPlayer);
    g_rbPlayerInPreview[pPlayer] = false;
    g_rgflPlayerNextHighlight[pPlayer] = 0.0;
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
}

CreateMenu(pPlayer) {
    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", pPlayer, "HWN_COSMETIC_MENU_TITLE");

    if (g_rgirgPlayerMenuSlotRefs[pPlayer] == Invalid_Array) {
        g_rgirgPlayerMenuSlotRefs[pPlayer] = ArrayCreate();
    } else {
        ArrayClear(g_rgirgPlayerMenuSlotRefs[pPlayer]);
    }

    new iMenu = menu_create(szMenuTitle, "MenuHandler_Main");

    new iInvSize = PInv_Size(pPlayer);
    if (!iInvSize) {
        static szEmptyCosmeticText[64];
        format(szEmptyCosmeticText, charsmax(szEmptyCosmeticText), "\d%L", pPlayer, "HWN_COSMETIC_MENU_EMPTY");
        menu_addtext2(iMenu, szEmptyCosmeticText);
    }

    for (new iSlot = 0; iSlot < iInvSize; ++iSlot) {
        if (PInv_GetItemType(pPlayer, iSlot) != g_iCosmeticItemType) {
            continue;
        }

        if (!PCosmetic_GetItemTime(pPlayer, iSlot)) {
            continue;
        }

        new iItemCallback = menu_makecallback("MenuCallback_Main_Item");
        menu_additem(iMenu, "", .callback = iItemCallback);
        ArrayPushCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iSlot);
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);

    return iMenu;
}

public MenuHandler_Main(pPlayer, iMenu, iItem) {
    menu_destroy(iMenu);

    if (iItem != MENU_EXIT) {
        new iSlot = ArrayGetCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iItem);
        new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);

        if (iItemType == g_iCosmeticItemType) {
            new PInv_ItemType:iItemType = PInv_GetItemType(pPlayer, iSlot);
            if (iItemType == g_iCosmeticItemType) {
                if (PCosmetic_IsItemEquiped(pPlayer, iSlot)) {
                    PCosmetic_Unequip(pPlayer, iSlot);
                } else {
                    PCosmetic_Equip(pPlayer, iSlot);
                }
            }
        }
    }

    if (is_user_connected(pPlayer)) {
        if (iItem != MENU_EXIT) {
            new iPage = 0;
            new _iUnusedRef;
            player_menu_info(pPlayer, _iUnusedRef, _iUnusedRef, iPage);

            @Player_OpenMenu(pPlayer, iPage);
        } else {
            @Player_DeactivatePreview(pPlayer);
        }
    }

    return PLUGIN_HANDLED;
}

public MenuCallback_Main_Item(pPlayer, iMenu, iItem) {
    new iSlot = ArrayGetCell(g_rgirgPlayerMenuSlotRefs[pPlayer], iItem);
    new iCosmetic = PCosmetic_GetItemCosmetic(pPlayer, iSlot);
    new iItemTime = PCosmetic_GetItemTime(pPlayer, iSlot);
    new PCosmetic_Type:iCosmeticType = PCosmetic_GetItemCosmeticType(pPlayer, iSlot);

    static szCosmeticName[32];
    PCosmetic_GetCosmeticName(iCosmetic, szCosmeticName, charsmax(szCosmeticName));

    static szText[128];
    format(
        szText,
        charsmax(szText),
        "%s%s%s (%i seconds left)",
        (PCosmetic_IsItemEquiped(pPlayer, iSlot) ? "\y" : ""),
        (iCosmeticType == PCosmetic_Type_Unusual ? "Unusual " : "^0"),
        szCosmeticName,
        iItemTime
    );

    menu_item_setname(iMenu, iItem, szText);

    if (!PCosmetic_CanBeEquiped(pPlayer, iCosmetic, iSlot) && !PCosmetic_IsItemEquiped(pPlayer, iSlot)) {
        return ITEM_DISABLED;
    }

    if (!iItemTime) {
        return ITEM_DISABLED;
    }

    return ITEM_ENABLED;
}
