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

new Array:g_playerCamera;

new g_maxPlayers;

public plugin_precache()
{
    precache_model(PREVIEW_CAMERA_MODEL);
}

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_forward(FM_AddToFullPack, "OnAddToFullPack", 1);
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Pre", .Post = 0);
    RegisterHam(Ham_Killed, "player", "OnPlayerSpawn", .Post = 1);

    g_maxPlayers = get_maxplayers();
    g_playerCamera = ArrayCreate(1, g_maxPlayers+1);

    for (new i = 0; i <= g_maxPlayers; ++i) {
        ArrayPushCell(g_playerCamera, 0);
    }
}

public plugin_natives()
{
    register_library("api_player_preview");
    register_native("PlayerPreview_Activate", "Native_Activate");
    register_native("PlayerPreview_Deactivate", "Native_Deactivate");
    register_native("PlayerPreview_IsActive", "Native_IsActive");
}

public plugin_end()
{
    ArrayDestroy(g_playerCamera);
}

/*--------------------------------[ Natives ]--------------------------------*/

public bool:Native_Activate(pluginID, argc)
{
    new id = get_param(1);
    new bool:light = bool:get_param(2);
    return Activate(id, light);
}

public Native_Deactivate(pluginID, argc)
{
    new id = get_param(1);
    Deactivate(id);
}

public bool:Native_IsActive(pluginID, argc)
{
   new id = get_param(1);
   return !!ArrayGetCell(g_playerCamera, id);
}

/*--------------------------------[ Forwards ]--------------------------------*/

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    Deactivate(id);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerKilled_Pre(id)
{
    Deactivate(id);
}

public OnPlayerSpawn(id)
{
    Deactivate(id);
}

public OnAddToFullPack(es, e, ent, host, hostflags, player, pSet)
{
    if (!IsPlayer(ent)) {
        return;
    }

    if (!is_user_connected(ent)) {
        return;
    }

    if (!is_user_alive(ent)) {
        return;
    }

    if (ent != host) {
        return;
    }

    if (!ArrayGetCell(g_playerCamera, ent)) {
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

bool:Activate(id, bool:light)
{
    DestroyPlayerCamera(id);

    if (!is_user_connected(id)) {
        return false;
    }

    if (!is_user_alive(id)) {
        return false;
    }

    if (!CreatePlayerCamera(id, light)) {
      return false;
    }

    set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0});
    set_pev(id, pev_avelocity, Float:{0.0, 0.0, 0.0});
    set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN);

    return true;
}

Deactivate(id)
{
    DestroyPlayerCamera(id);

    if (!is_user_connected(id)) {
        return;
    }

    set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
}

CreatePlayerCamera(id, bool:light)
{
    if (!is_user_alive(id)) {
        return false;
    }

    if (~pev(id, pev_flags) & FL_ONGROUND) {
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
    set_pev(ent, pev_iuser1, light);

    engfunc(EngFunc_SetModel, ent, PREVIEW_CAMERA_MODEL);

    UpdatePlayerCamera(ent);
    if (!CheckPlayerCamera(ent)) {
        DestroyPlayerCamera(id);
        return false;
    }

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

UpdatePlayerCamera(ent)
{
    new owner = pev(ent, pev_owner);

    static Float:vViewAngle[3];
    pev(owner, pev_v_angle, vViewAngle);
    vViewAngle[0] = PREVIEW_CAMERA_PITCH;
    vViewAngle[1] += PREVIEW_CAMERA_YAW;
    vViewAngle[2] = 0.0;
    set_pev(ent, pev_angles, vViewAngle);

    static Float:vPlayerOrigin[3];
    pev(owner, pev_origin, vPlayerOrigin);

    static Float:vOffset[3];
    angle_vector(vViewAngle, ANGLEVECTOR_FORWARD, vOffset);
    xs_vec_mul_scalar(vOffset, -1.0, vOffset);
    xs_vec_mul_scalar(vOffset, PREVIEW_CAMERA_DISTANCE, vOffset);
    
    static Float:vOrigin[3];
    xs_vec_add(vPlayerOrigin, vOffset, vOrigin);
    engfunc(EngFunc_SetOrigin, ent, vOrigin);
}

CheckPlayerCamera(ent)
{
    new owner = pev(ent, pev_owner);

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    
    static Float:vPlayerOrigin[3];
    pev(owner, pev_origin, vPlayerOrigin);

    engfunc(EngFunc_TraceLine, vPlayerOrigin, vOrigin, IGNORE_MONSTERS, owner, 0); 

    new Float:flFraction;
    get_tr2(0, TR_flFraction, flFraction);

    return flFraction == 1.0;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskCameraThink(taskID)
{
    new ent = taskID;
    new owner = pev(ent, pev_owner);
    new light = pev(ent, pev_iuser1);

    if (light) {
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
