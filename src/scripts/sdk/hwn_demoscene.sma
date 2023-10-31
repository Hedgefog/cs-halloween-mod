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
#include <hwn_utils>
#include <api_custom_entities>

#define CAMERA_CLASSNAME "trigger_camera"
#define CAMERA_MODEL "models/rpgrocket.mdl"
#define PLAYER_MODEL "gign"
#define PLAYER_WEAPON "weapon_mp5navy"
#define DEPTH_OFFSET 64.0 // Distance between player and logo
#define CAMERA_DISTANCE 240.0 // Resolution: 1920x1080 FOV: 90
#define CAMERA_YAW 90.0 // Side view

new g_hSpellFireball;

public plugin_init() {
    register_plugin("[Hwn] Demo Scene", "1.0.0", "Hedgehog Fog");

    RegisterHam(Ham_Think, CAMERA_CLASSNAME, "HamHook_Camera_Think", .Post = 0);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink", .Post = 0);

    g_hSpellFireball = Hwn_Spell_GetHandler("Fireball");

    register_clcmd("hwn_demoscene_reset", "ResetAll");
}

public plugin_precache() {
    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));
    if (!equal(szMapName, "hwn_demoscene")) {
        pause("ad");
        return;
    }

    CE_RegisterHook(CEFunction_Spawned, "hwn_skeleton_egg", "OnSkeletonEggSpawn");
    CE_RegisterHook(CEFunction_Spawned, "hwn_item_pumpkin", "OnPumpkinSpawn");

    precache_model(CAMERA_MODEL);
}

public client_disconnected(pPlayer) {
    ResetAll(pPlayer);
}

public Hwn_Fw_ConfigLoaded() {
    set_cvar_num("hwn_collector_npc_drop_chance_spell", 0);
    set_cvar_num("hwn_crits_random_chance_max", 0);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    ResetAll(pPlayer);

    CreateCamera(pPlayer);
    SetHudDraw(pPlayer, 0);
    SetDecalsLimit(pPlayer, 0);
    set_task(0.1, "Equip", pPlayer);
    set_task(2.0, "MoveStart", pPlayer);
    set_task(4.8, "CastSpell", pPlayer);
    set_task(5.75, "AttackStart", pPlayer);
    set_task(6.5, "AttackEnd", pPlayer);
}

public HamHook_Player_PreThink(pPlayer) {
    set_pev(pPlayer, pev_punchangle, {0.0, 0.0, 0.0});
}

public OnSkeletonEggSpawn(pEntity) {
    CE_Remove(pEntity);
}

public OnPumpkinSpawn(pEntity) {
    CE_SetMember(pEntity, "iType", 2);
    set_pev(pEntity, pev_rendercolor, {HWN_COLOR_RED_F});
}

public HamHook_Camera_Think(pEntity) {
    new pOwner = pev(pEntity, pev_owner);
    if (!pOwner) {
        return;
    }

    static Float:vecPlayerOrigin[3];
    UTIL_GetViewOrigin(pOwner, vecPlayerOrigin);

    static Float:vecViewAngle[3];
    pev(pOwner, pev_v_angle, vecViewAngle);
    vecViewAngle[1] += CAMERA_YAW;

    static Float:vecOffset[3];
    angle_vector(vecViewAngle, ANGLEVECTOR_FORWARD, vecOffset);
    xs_vec_mul_scalar(vecOffset, -1.0, vecOffset);
    xs_vec_mul_scalar(vecOffset, CAMERA_DISTANCE + DEPTH_OFFSET, vecOffset);

    static Float:vecOrigin[3];
    xs_vec_add(vecPlayerOrigin, vecOffset, vecOrigin);

    engfunc(EngFunc_SetOrigin, pEntity, vecOrigin);
    set_pev(pEntity, pev_angles, vecViewAngle);

    set_pev(pEntity, pev_nextthink, get_gametime());
}

public CreateCamera(pPlayer) {
    static iszClassName;
    if (!iszClassName) {
        iszClassName = engfunc(EngFunc_AllocString, CAMERA_CLASSNAME);
    }

    new pEntity = engfunc(EngFunc_CreateNamedEntity, iszClassName);
    set_pev(pEntity, pev_classname, CAMERA_CLASSNAME);
    set_pev(pEntity, pev_owner, pPlayer);
    set_pev(pEntity, pev_solid, SOLID_NOT);
    set_pev(pEntity, pev_movetype, MOVETYPE_FLY);
    set_pev(pEntity, pev_rendermode, kRenderTransTexture);

    engfunc(EngFunc_SetModel, pEntity, CAMERA_MODEL);
    engfunc(EngFunc_SetView, pPlayer, pEntity);

    set_pev(pEntity, pev_nextthink, get_gametime());
}

public Equip(pPlayer) {
    cs_set_user_model(pPlayer, PLAYER_MODEL);
    strip_user_weapons(pPlayer);
    give_item(pPlayer, PLAYER_WEAPON);
}

public MoveStart(pPlayer) {
    client_cmd(pPlayer, "+forward");
}

public MoveEnd(pPlayer) {
    client_cmd(pPlayer, "-forward");
}

public AttackStart(pPlayer) {
    client_cmd(pPlayer, "+attack");
}

public AttackEnd(pPlayer) {
    client_cmd(pPlayer, "-attack");
}

public SetHudDraw(pPlayer, iValue) {
    client_cmd(pPlayer, "hud_draw %d", iValue);
}

public SetDecalsLimit(pPlayer, iValue) {
    client_cmd(pPlayer, "r_decals %d", iValue);
}

public CastSpell(pPlayer) {
    Hwn_Spell_SetPlayerSpell(pPlayer, g_hSpellFireball, 1);
    client_cmd(pPlayer, "impulse 100");
}

public ResetAll(pPlayer) {
    MoveEnd(pPlayer);
    AttackEnd(pPlayer);
    SetHudDraw(pPlayer, 1);
    SetDecalsLimit(pPlayer, 300);
    remove_task(pPlayer);
}
