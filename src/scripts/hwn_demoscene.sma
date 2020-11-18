// Output GIF: 960x256, 24 fps

/*
    1. Set resolution to 1920x1080
    2. Launch hwn_demoscene map
    3. Start recording
    4. Join team
    5. Stop the video at end of the scene
    6. Open recorded video in Photoshop
    7. Cut video
    8. Set canvas size to 1920x512
    9. Set video fps to 24
    10. Open Save for Web (Legacy)
    11. Set image size to 50%
    12. Set Looping Options to "Forever"
    13. Turn off transparency
    14. Export video as gif
    15. Use hwn_demoscene_reset command to stop script
*/

#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>
#include <fun>
#include <xs>

#include <hwn>
#include <api_custom_entities>

#define CAMERA_CLASSNAME "trigger_camera"
#define CAMERA_MODEL "models/rpgrocket.mdl"
#define PLAYER_MODEL "gign"
#define PLAYER_WEAPON "weapon_mp5navy"
#define DEPTH_OFFSET 64.0 // Distance between player and logo
#define CAMERA_DISTANCE 240.0 // Resolution: 1920x1080 FOV: 90
#define CAMERA_YAW 90.0 // Side view

public plugin_init()
{
    register_plugin("[Hwn] Demo Scene", "1.0.0", "Hedgehog Fog");

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
    RegisterHam(Ham_Think, CAMERA_CLASSNAME, "OnCameraThink", .Post = 0);
    RegisterHam(Ham_Player_PreThink, "player", "OnPlayerPreThink", .Post = 0);

    register_clcmd("hwn_demoscene_reset", "ResetAll");
}

public plugin_precache()
{
    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));
    if (!equal(szMapName, "hwn_demoscene")) {
        pause("ad");
        return;
    }

    CE_RegisterHook(CEFunction_Spawn, "hwn_skeleton_egg", "OnSkeletonEggSpawn");
    CE_RegisterHook(CEFunction_Spawn, "hwn_item_pumpkin", "OnPumpkinSpawn");

    precache_model(CAMERA_MODEL);
}

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    ResetAll(id);
}

public Hwn_Fw_ConfigLoaded()
{
    set_cvar_num("hwn_collector_npc_drop_chance_spell", 0);
    set_cvar_num("hwn_crits_random_chance_max", 0);
}

public OnPlayerSpawn(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    ResetAll(id);

    CreateCamera(id);
    SetHudDraw(id, 0);
    SetDecalsLimit(id, 0);
    set_task(0.1, "Equip", id);
    set_task(2.0, "MoveStart", id);
    set_task(4.8, "CastSpell", id);
    set_task(5.75, "AttackStart", id);
    set_task(6.5, "AttackEnd", id);
}

public OnPlayerPreThink(id)
{
    set_pev(id, pev_punchangle, {0.0, 0.0, 0.0});
}

public OnSkeletonEggSpawn(ent)
{
    CE_Remove(ent);
}

public OnPumpkinSpawn(ent)
{
    set_pev(ent, pev_iuser1, 2);
    set_pev(ent, pev_rendercolor, {HWN_COLOR_RED_F});
}

public OnCameraThink(ent)
{
    new owner = pev(ent, pev_owner);
    if (!owner) {
        return;
    }

    static Float:vPlayerOrigin[3];
    pev(owner, pev_origin, vPlayerOrigin);

    static Float:vViewOfs[3];
    pev(owner, pev_view_ofs, vViewOfs);
    vPlayerOrigin[2] += vViewOfs[2];

    static Float:vViewAngle[3];
    pev(owner, pev_v_angle, vViewAngle);
    vViewAngle[1] += CAMERA_YAW;

    static Float:vOffset[3];
    angle_vector(vViewAngle, ANGLEVECTOR_FORWARD, vOffset);
    xs_vec_mul_scalar(vOffset, -1.0, vOffset);
    xs_vec_mul_scalar(vOffset, CAMERA_DISTANCE + DEPTH_OFFSET, vOffset);

    static Float:vOrigin[3];
    xs_vec_add(vPlayerOrigin, vOffset, vOrigin);

    engfunc(EngFunc_SetOrigin, ent, vOrigin);
    set_pev(ent, pev_angles, vViewAngle);

    set_pev(ent, pev_nextthink, get_gametime());
}

public CreateCamera(id)
{
    static allocClassname;
    if (!allocClassname) {
        allocClassname = engfunc(EngFunc_AllocString, CAMERA_CLASSNAME);
    }

    new ent = engfunc(EngFunc_CreateNamedEntity, allocClassname);
    set_pev(ent, pev_classname, CAMERA_CLASSNAME);
    set_pev(ent, pev_owner, id);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_movetype, MOVETYPE_FLY);
    set_pev(ent, pev_rendermode, kRenderTransTexture);

    engfunc(EngFunc_SetModel, ent, CAMERA_MODEL);
    engfunc(EngFunc_SetView, id, ent);

    set_pev(ent, pev_nextthink, get_gametime());
}

public Equip(id)
{
    cs_set_user_model(id, PLAYER_MODEL);
    strip_user_weapons(id);
    give_item(id, PLAYER_WEAPON);
}

public MoveStart(id)
{
    client_cmd(id, "+forward");
}

public MoveEnd(id)
{
    client_cmd(id, "-forward");
}

public AttackStart(id)
{
    client_cmd(id, "+attack");
}

public AttackEnd(id)
{
    client_cmd(id, "-attack");
}

public SetHudDraw(id, value)
{
    client_cmd(id, "hud_draw %d", value);
}

public SetDecalsLimit(id, value)
{
    client_cmd(id, "r_decals %d", value);
}

public CastSpell(id)
{
    Hwn_Spell_SetPlayerSpell(id, 1, 1);
    client_cmd(id, "impulse 100");
}

public ResetAll(id)
{
    MoveEnd(id);
    AttackEnd(id);
    SetHudDraw(id, 1);
    SetDecalsLimit(id, 300);
    remove_task(id);
}
