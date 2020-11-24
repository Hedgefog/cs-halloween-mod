#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <hwn>
#include <api_player_inventory>
#include <api_player_cosmetic>

#define PLUGIN "[Hwn] Menu Player Cosmetic"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define PREVIEW_CAMERA_MODEL "models/rpgrocket.mdl"
#define PREVIEW_CAMERA_PITCH 15.0
#define PREVIEW_CAMERA_YAW 180.0
#define PREVIEW_CAMERA_DISTANCE 96.0
#define PREVIEW_CAMERA_LIGHT_RADIUS 4
#define PREVIEW_CAMERA_LIGHT_BRIGHTNESS 1.0
#define PREVIEW_CAMERA_LIGHT_LIFETIME 5
#define PREVIEW_CAMERA_LIGHT_DECAYRATE 1

new g_cvarPreview;
new g_cvarPreviewLight;

new PInv_ItemType:g_hCosmeticItemType;

new Array:g_playerMenu;
new Array:g_playerMenuSlotRefs;
new Array:g_playerCamera;

new g_maxPlayers;

public plugin_precache()
{
    precache_model(PREVIEW_CAMERA_MODEL);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);

    g_cvarPreview = register_cvar("hwn_pcosmetic_menu_preview", "1");
    g_cvarPreviewLight = register_cvar("hwn_pcosmetic_menu_preview_light", "1");

    g_hCosmeticItemType = PInv_GetItemTypeHandler("cosmetic");

    g_maxPlayers = get_maxplayers();

    g_playerMenu = ArrayCreate(1, g_maxPlayers+1);
    g_playerMenuSlotRefs = ArrayCreate(1, g_maxPlayers+1);
    g_playerCamera = ArrayCreate(1, g_maxPlayers+1);

    for (new i = 0; i <= g_maxPlayers; ++i) {
        ArrayPushCell(g_playerMenu, 0);
        ArrayPushCell(g_playerMenuSlotRefs, Invalid_Array);
        ArrayPushCell(g_playerCamera, 0);
    }
}

public plugin_natives()
{
    register_library("menu_player_cosmetic");
    register_native("PCosmetic_Menu_Open", "Native_Open");
}

public plugin_end()
{
    ArrayDestroy(g_playerMenu);

    for (new i = 1; i <= g_maxPlayers; ++i) {
        new Array:slotRefs = ArrayGetCell(g_playerMenuSlotRefs, i);
        if (slotRefs != Invalid_Array) {
            ArrayDestroy(slotRefs);
        }
    } ArrayDestroy(g_playerMenuSlotRefs);

    ArrayDestroy(g_playerCamera);
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Open(pluginID, argc)
{
    new id = get_param(1);
    Open(id);
}

/*--------------------------------[ Forwards ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    SetPlayerPreview(id, false);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerKilled(id)
{
    SetPlayerPreview(id, false);
}

/*--------------------------------[ Methods ]--------------------------------*/

Open(id, page = 0)
{
    new menu = ArrayGetCell(g_playerMenu, id);
    if (menu) {
        menu_destroy(menu);
    }

    menu = Create(id);
    ArraySetCell(g_playerMenu, id, menu);

    menu_display(id, menu, page);


    if (get_pcvar_num(g_cvarPreview) > 0 && Hwn_Gamemode_IsPlayerOnSpawn(id)) {
        SetPlayerPreview(id, true);
    }
}

Create(id)
{
    new callbackDisabled = menu_makecallback("MenuDisabledCallback");

    static szMenuTitle[32];
    format(szMenuTitle, charsmax(szMenuTitle), "%L", id, "HWN_COSMETIC_MENU_TITLE");
    
    new menu = menu_create(szMenuTitle, "MenuHandler");

    new Array:slotRefs = ArrayGetCell(g_playerMenuSlotRefs, id);
    if (slotRefs != Invalid_Array) {
        ArrayClear(slotRefs);
    } else {
        slotRefs = ArrayCreate();
        ArraySetCell(g_playerMenuSlotRefs, id, slotRefs);
    }

    new size = PInv_Size(id);

    for (new i = 0; i < size; ++i)
    {
        if (g_hCosmeticItemType != PInv_GetItemType(id, i)) {
            continue;
        }

        new itemTime = PCosmetic_GetItemTime(id, i);
        if (!itemTime) {
            continue;
        }

        ArrayPushCell(slotRefs, i);

        new cosmetic = PCosmetic_GetItemCosmetic(id, i);
        new PCosmetic_Type:cosmeticType = PCosmetic_GetItemCosmeticType(id, i);

        static szCosmeticName[32];
        PCosmetic_GetCosmeticName(cosmetic, szCosmeticName, charsmax(szCosmeticName));

        static text[64];
        format
        (
            text,
            charsmax(text),
            "%s%s%s (%i seconds left)",
            (PCosmetic_IsItemEquiped(id, i) ? "\y" : ""),
            (cosmeticType == PCosmetic_Type_Unusual ? "Unusual " : "^0"),
            szCosmeticName,
            itemTime
        );

        menu_additem(menu, text, .callback = PCosmetic_CanBeEquiped(id, cosmetic, i)
            || PCosmetic_IsItemEquiped(id, i)  ? -1 : callbackDisabled);
    }

    if (!size) {
        static szEmptyCosmeticText[64];
        format(szEmptyCosmeticText, charsmax(szEmptyCosmeticText), "%L", id, "HWN_COSMETIC_MENU_EMPTY");

        menu_additem(menu, szEmptyCosmeticText, .callback = callbackDisabled);
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);

    return menu;
}


SetPlayerPreview(id, value)
{
    DestroyPlayerCamera(id); // destroy old camera

    if (!is_user_connected(id)) {
        return;
    }

    if (value) {
        if (!is_user_alive(id)) {
            return;
        }

        if (CreatePlayerCamera(id)) {
            set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);
            set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0});
        }
    } else {
        set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
    }
}

CreatePlayerCamera(id)
{
    if (!is_user_alive(id)) {
        return false;
    }

    static allocClassname;
    if (!allocClassname) {
        allocClassname = engfunc(EngFunc_AllocString, "trigger_camera");
    }

    new ent = engfunc(EngFunc_CreateNamedEntity, allocClassname);
    if (!pev_valid(ent)) {
        return false;
    }

    set_pev(ent, pev_owner, id);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_movetype, MOVETYPE_NONE);
    set_pev(ent, pev_rendermode, kRenderTransTexture);

    engfunc(EngFunc_SetModel, ent, PREVIEW_CAMERA_MODEL);

    static Float:vViewAngle[3];
    pev(id, pev_v_angle, vViewAngle);
    vViewAngle[0] = PREVIEW_CAMERA_PITCH;
    vViewAngle[1] += PREVIEW_CAMERA_YAW;
    vViewAngle[2] = 0.0;
    set_pev(ent, pev_angles, vViewAngle);

    static Float:vPlayerOrigin[3];
    pev(id, pev_origin, vPlayerOrigin);

    static Float:vOffset[3];
    angle_vector(vViewAngle, ANGLEVECTOR_FORWARD, vOffset);
    xs_vec_mul_scalar(vOffset, -1.0, vOffset);
    xs_vec_mul_scalar(vOffset, PREVIEW_CAMERA_DISTANCE, vOffset);
    
    static Float:vOrigin[3];
    xs_vec_add(vPlayerOrigin, vOffset, vOrigin);

    engfunc(EngFunc_TraceLine, vPlayerOrigin, vOrigin, IGNORE_MONSTERS, id, 0); 

    new Float:flFraction;
    get_tr2(0, TR_flFraction, flFraction);

    if(flFraction != 1.0) {
        engfunc(EngFunc_RemoveEntity, ent);
        return false;
    }

    dllfunc(DLLFunc_Think, ent);
    engfunc(EngFunc_SetOrigin, ent, vOrigin);

    engfunc(EngFunc_SetView, id, ent);
    set_task(0.1, "TaskCameraThink", ent, _, _, "b");
    ArraySetCell(g_playerCamera, id, ent);

    return true;
}

DestroyPlayerCamera(id)
{
    new ent = ArrayGetCell(g_playerCamera, id);
    if (!ent) {
        return;
    }

    if (is_user_connected(id)) {
        engfunc(EngFunc_SetView, id, id);
    }

    remove_task(ent);
    engfunc(EngFunc_RemoveEntity, ent);
    ArraySetCell(g_playerCamera, id, 0);
}

/*--------------------------------[ Menu ]--------------------------------*/

public MenuHandler(id, menu, item)
{
    if (item != MENU_EXIT)
    {
        new Array:slotRefs = ArrayGetCell(g_playerMenuSlotRefs, id);
        new slotIdx = ArrayGetCell(slotRefs, item);

        new PInv_ItemType:itemType = PInv_GetItemType(id, slotIdx);
        if (itemType == g_hCosmeticItemType) {
            if (PCosmetic_IsItemEquiped(id, slotIdx)) {
                PCosmetic_Unequip(id, slotIdx);
            } else {
                PCosmetic_Equip(id, slotIdx);
            }
        }
    }

    if (is_user_connected(id)) {
        menu_cancel(id);
        SetPlayerPreview(id, false);

        new page = 0;
        {
            new _unusedRef;
            player_menu_info(id, _unusedRef, _unusedRef, page);
        }

        if (item != MENU_EXIT) {
        Open(id, page);
        }
    }



    return PLUGIN_HANDLED;
}

public MenuDisabledCallback()
{
    return ITEM_DISABLED;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskCameraThink(taskID)
{
    new ent = taskID;
    new owner = pev(ent, pev_owner);

    if (get_pcvar_num(g_cvarPreviewLight) > 0) {
        static Float:vOrigin[3];
        pev(owner, pev_origin, vOrigin);

        new brightness = floatround(255 * PREVIEW_CAMERA_LIGHT_BRIGHTNESS);

        engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vOrigin, owner);
        write_byte(TE_DLIGHT);
        engfunc(EngFunc_WriteCoord, vOrigin[0]);
        engfunc(EngFunc_WriteCoord, vOrigin[1]);
        engfunc(EngFunc_WriteCoord, vOrigin[2]);
        write_byte(PREVIEW_CAMERA_LIGHT_RADIUS);
        write_byte(brightness);
        write_byte(brightness);
        write_byte(brightness);
        write_byte(PREVIEW_CAMERA_LIGHT_LIFETIME);
        write_byte(PREVIEW_CAMERA_LIGHT_DECAYRATE);
        message_end();
    }
}
