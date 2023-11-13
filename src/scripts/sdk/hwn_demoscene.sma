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

#include <api_custom_entities>
#include <api_player_camera>

#include <hwn>
#include <hwn_utils>

#define CAMERA_MODEL "models/rpgrocket.mdl"
#define PLAYER_MODEL "gign"
#define PLAYER_WEAPON "weapon_mp5navy"
#define HEIGHT_OFFSET 16.0 // Distance between player and logo
#define DEPTH_OFFSET 64.0 // Distance between player and logo
#define CAMERA_DISTANCE 240.0 // Resolution: 1920x1080 FOV: 90
#define CAMERA_YAW 90.0 // Side view

new g_iFireballSpell;

public plugin_init() {
    register_plugin("[Hwn] Demo Scene", "1.0.0", "Hedgehog Fog");

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
    RegisterHamPlayer(Ham_Player_PreThink, "HamHook_Player_PreThink", .Post = 0);

    g_iFireballSpell = Hwn_Spell_GetHandler("Fireball");

    register_clcmd("hwn_demoscene_reset", "@Player_ResetAll");
}

public plugin_precache() {
    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));
    if (!equal(szMapName, "hwn_demoscene")) {
        pause("ad");
        return;
    }

    CE_RegisterHook(CEFunction_Spawned, "hwn_skeleton_egg", "@SkeletonEgg_Spawned");
    CE_RegisterHook(CEFunction_Spawned, "hwn_item_pumpkin", "@Pumpkin_Spawned");

    precache_model(CAMERA_MODEL);
}

public client_disconnected(pPlayer) {
    @Player_ResetAll(pPlayer);
}

public Hwn_Fw_ConfigLoaded() {
    set_cvar_num("hwn_collector_npc_drop_chance_spell", 0);
    set_cvar_num("hwn_crits_random_chance_max", 0);
    set_cvar_num("hwn_objective_marks", 0);
    set_cvar_num("hwn_objective_marks", 0);
    set_cvar_num("hwn_pumpkin_mutate_chance", 100);
    set_cvar_num("mp_freezetime", 0);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) return;

    @Player_ResetAll(pPlayer);

    PlayerCamera_Activate(pPlayer);
    PlayerCamera_SetAngles(pPlayer, Float:{0.0, CAMERA_YAW, 0.0});
    PlayerCamera_SetDistance(pPlayer, CAMERA_DISTANCE + DEPTH_OFFSET);
    PlayerCamera_SetOffset(pPlayer, Float:{0.0, 0.0, HEIGHT_OFFSET});

    @Player_SetHudDraw(pPlayer, 0);
    @Player_SetDecalsLimit(pPlayer, 0);

    set_task(0.1, "@Player_Equip", pPlayer);
    set_task(2.0, "@Player_MoveStart", pPlayer);
    set_task(4.8, "@Player_CastSpell", pPlayer);
    set_task(5.75, "@Player_AttackStart", pPlayer);
    set_task(6.5, "@Player_AttackEnd", pPlayer);
}

public HamHook_Player_PreThink(pPlayer) {
    set_pev(pPlayer, pev_punchangle, {0.0, 0.0, 0.0});
}

@SkeletonEgg_Spawned(pEntity) {
    CE_Remove(pEntity);
}

@Pumpkin_Spawned(pEntity) {
    CE_SetMember(pEntity, "iType", 2);
    set_pev(pEntity, pev_rendercolor, {HWN_COLOR_RED_F});
}

@Player_Equip(pPlayer) {
    cs_set_user_model(pPlayer, PLAYER_MODEL);
    strip_user_weapons(pPlayer);
    give_item(pPlayer, PLAYER_WEAPON);
}

@Player_MoveStart(pPlayer) {
    client_cmd(pPlayer, "+forward");
}

@Player_MoveEnd(pPlayer) {
    client_cmd(pPlayer, "-forward");
}

@Player_AttackStart(pPlayer) {
    client_cmd(pPlayer, "+attack");
}

@Player_AttackEnd(pPlayer) {
    client_cmd(pPlayer, "-attack");
}

@Player_SetHudDraw(pPlayer, iValue) {
    client_cmd(pPlayer, "hud_draw %d", iValue);
}

@Player_SetDecalsLimit(pPlayer, iValue) {
    client_cmd(pPlayer, "r_decals %d", iValue);
}

@Player_CastSpell(pPlayer) {
    Hwn_Spell_SetPlayerSpell(pPlayer, g_iFireballSpell, 1);
    client_cmd(pPlayer, "impulse 100");
}

@Player_ResetAll(pPlayer) {
    @Player_MoveEnd(pPlayer);
    @Player_AttackEnd(pPlayer);
    @Player_SetHudDraw(pPlayer, 1);
    @Player_SetDecalsLimit(pPlayer, 300);
    remove_task(pPlayer);
}
