#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#define PLUGIN "[API] Player Preview"
#define VERSION "1.0.0"
#define AUTHOR "Hedgehog Fog"

#define IsPlayer(%1) (1 <= %1 <= 32)

#define PREVIEW_CAMERA_MODEL "models/rpgrocket.mdl"
#define PREVIEW_CAMERA_PITCH 15.0
#define PREVIEW_CAMERA_YAW 180.0
#define PREVIEW_CAMERA_DISTANCE 96.0
#define PREVIEW_CAMERA_LIGHT_RADIUS 4
#define PREVIEW_CAMERA_LIGHT_BRIGHTNESS 1.0
#define PREVIEW_CAMERA_LIGHT_LIFETIME 5
#define PREVIEW_CAMERA_LIGHT_DECAYRATE 1

new g_rgPlayerCamera[MAX_PLAYERS + 1];

public plugin_precache() {
    precache_model(PREVIEW_CAMERA_MODEL);
}

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_forward(FM_AddToFullPack, "OnAddToFullPack", 1);
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed", .Post = 0);
    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
}

public plugin_natives() {
    register_library("api_player_preview");
    register_native("PlayerPreview_Activate", "Native_Activate");
    register_native("PlayerPreview_Deactivate", "Native_Deactivate");
    register_native("PlayerPreview_IsActive", "Native_IsActive");
}

/*--------------------------------[ Natives ]--------------------------------*/

public bool:Native_Activate(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new bool:light = bool:get_param(2);
    return Activate(pPlayer, light);
}

public Native_Deactivate(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    Deactivate(pPlayer);
}

public bool:Native_IsActive(iPluginId, iArgc) {
   new pPlayer = get_param(1);
   return !!g_rgPlayerCamera[pPlayer];
}

/*--------------------------------[ Forwards ]--------------------------------*/

public client_disconnected(pPlayer) {
    Deactivate(pPlayer);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed(pPlayer) {
    Deactivate(pPlayer);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    Deactivate(pPlayer);
}

public OnAddToFullPack(es, e, pEntity, host, hostflags, player, pSet) {
    if (pEntity != host) {
        return;
    }

    if (!IsPlayer(pEntity)) {
        return;
    }

    if (!is_user_connected(pEntity)) {
        return;
    }

    if (!is_user_alive(pEntity)) {
        return;
    }

    if (!g_rgPlayerCamera[pEntity]) {
        return;
    }

    set_es(es, ES_Sequence, 64);
    set_es(es, ES_GaitSequence, 1);
    set_es(es, ES_RenderMode, kRenderNormal);
    set_es(es, ES_RenderFx, kRenderFxNone);
    set_es(es, ES_RenderAmt, 255.0);
    set_es(es, ES_MoveType, MOVETYPE_NONE); // disable blending
}

/*--------------------------------[ Methods ]--------------------------------*/

bool:Activate(pPlayer, bool:light) {
    DestroyPlayerCamera(pPlayer);

    if (!is_user_connected(pPlayer)) {
        return false;
    }

    if (!is_user_alive(pPlayer)) {
        return false;
    }

    if (!CreatePlayerCamera(pPlayer, light)) {
      return false;
    }

    set_pev(pPlayer, pev_velocity, Float:{0.0, 0.0, 0.0});
    set_pev(pPlayer, pev_avelocity, Float:{0.0, 0.0, 0.0});
    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) | FL_FROZEN);

    return true;
}

Deactivate(pPlayer) {
    DestroyPlayerCamera(pPlayer);

    if (!is_user_connected(pPlayer)) {
        return;
    }

    set_pev(pPlayer, pev_flags, pev(pPlayer, pev_flags) & ~FL_FROZEN);
}

CreatePlayerCamera(pPlayer, bool:light) {
    if (!is_user_alive(pPlayer)) {
        return false;
    }

    if (~pev(pPlayer, pev_flags) & FL_ONGROUND) {
        return false;
    }

    static allocClassname;
    if (!allocClassname) {
        allocClassname = engfunc(EngFunc_AllocString, "trigger_camera");
    }

    new pEntity = engfunc(EngFunc_CreateNamedEntity, allocClassname);
    if (!pev_valid(pEntity)) {
        return false;
    }

    set_pev(pEntity, pev_owner, pPlayer);
    set_pev(pEntity, pev_solid, SOLID_NOT);
    set_pev(pEntity, pev_movetype, MOVETYPE_NONE);
    set_pev(pEntity, pev_rendermode, kRenderTransTexture);
    set_pev(pEntity, pev_iuser1, light);

    engfunc(EngFunc_SetModel, pEntity, PREVIEW_CAMERA_MODEL);

    UpdatePlayerCamera(pEntity);
    if (!CheckPlayerCamera(pEntity)) {
        DestroyPlayerCamera(pPlayer);
        return false;
    }

    engfunc(EngFunc_SetView, pPlayer, pEntity);
    set_task(0.1, "Task_CameraThink", pEntity, _, _, "b");

    g_rgPlayerCamera[pPlayer] = pEntity;

    return true;
}

DestroyPlayerCamera(pPlayer) {
    new pEntity = g_rgPlayerCamera[pPlayer];
    if (!pEntity) {
        return;
    }

    if (is_user_connected(pPlayer)) {
        engfunc(EngFunc_SetView, pPlayer, pPlayer);
    }

    remove_task(pEntity);
    engfunc(EngFunc_RemoveEntity, pEntity);
    g_rgPlayerCamera[pPlayer] = 0;
}

UpdatePlayerCamera(pEntity) {
    new pOwner = pev(pEntity, pev_owner);

    static Float:vecViewAngle[3];
    pev(pOwner, pev_v_angle, vecViewAngle);
    vecViewAngle[0] = PREVIEW_CAMERA_PITCH;
    vecViewAngle[1] += PREVIEW_CAMERA_YAW;
    vecViewAngle[2] = 0.0;
    set_pev(pEntity, pev_angles, vecViewAngle);

    static Float:vecPlayerOrigin[3];
    pev(pOwner, pev_origin, vecPlayerOrigin);

    static Float:vecOffset[3];
    angle_vector(vecViewAngle, ANGLEVECTOR_FORWARD, vecOffset);
    xs_vec_mul_scalar(vecOffset, -1.0, vecOffset);
    xs_vec_mul_scalar(vecOffset, PREVIEW_CAMERA_DISTANCE, vecOffset);
    
    static Float:vecOrigin[3];
    xs_vec_add(vecPlayerOrigin, vecOffset, vecOrigin);
    engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);
}

CheckPlayerCamera(pEntity) {
    new pOwner = pev(pEntity, pev_owner);

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    
    static Float:vecPlayerOrigin[3];
    pev(pOwner, pev_origin, vecPlayerOrigin);

    engfunc(EngFunc_TraceLine, vecPlayerOrigin, vecOrigin, IGNORE_MONSTERS, pOwner, 0); 

    new Float:flFraction;
    get_tr2(0, TR_flFraction, flFraction);

    return flFraction == 1.0;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_CameraThink(iTaskId) {
    new pEntity = iTaskId;
    new pOwner = pev(pEntity, pev_owner);
    new light = pev(pEntity, pev_iuser1);

    if (light) {
      static Float:vecOrigin[3];
      pev(pOwner, pev_origin, vecOrigin);

      new iBrightness = floatround(255 * PREVIEW_CAMERA_LIGHT_BRIGHTNESS);

      engfunc(EngFunc_MessageBegin, MSG_ONE, SVC_TEMPENTITY, vecOrigin, pOwner);
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
    }
}
