#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <hamsandwich>

#include <api_custom_entities>
#include <api_waypoint_markers>

#include <hwn>

#define PLUGIN "[Hwn] Objective Marks"
#define AUTHOR "Hedgehog Fog"

#define SPRITE_WIDTH 128.0

new const g_szMarkerModel[] = "sprites/hwn/mark_cauldron.spr";

new g_pCvarEnabled;

new Array:g_irgpMarkers;

public plugin_precache() {
    g_irgpMarkers = ArrayCreate(_, 2);

    precache_model(g_szMarkerModel);

    CE_RegisterHook(CEFunction_Init, "hwn_bucket", "@Bucket_Init");
    CE_RegisterHook(CEFunction_Remove, "hwn_bucket", "@Bucket_Remove");

    g_pCvarEnabled = register_cvar("hwn_objective_marks", "1");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
}

public plugin_end() {
    ArrayDestroy(g_irgpMarkers);
}

@Bucket_Init(this) {
    if (get_pcvar_bool(g_pCvarEnabled)) {
        static Float:vecOrigin[3];
        pev(this, pev_origin, vecOrigin);
        vecOrigin[2] += 28.0;

        new pMarker = WaypointMarker_Create(g_szMarkerModel, vecOrigin, 56.0 / SPRITE_WIDTH / 2, Float:{28.0, 28.0});
        set_pev(pMarker, pev_team, pev(this, pev_team));
        set_pev(pMarker, pev_renderamt, 160.0);

        CE_SetMember(this, "pMarker", pMarker);
    }
}

@Bucket_Remove(this) {
    new pMarker = CE_GetMember(this, "pMarker");
    if (pMarker) {
        set_pev(pMarker, pev_flags, pev(pMarker, pev_flags) | FL_KILLME);
        dllfunc(DLLFunc_Think, pMarker);
    }
}

public WaypointMarker_Fw_Created(pMarker) {
    ArrayPushCell(g_irgpMarkers, pMarker);
}

public WaypointMarker_Fw_Destroy(pMarker) {
    new iGlobalId = ArrayFindValue(g_irgpMarkers, pMarker);
    if (iGlobalId != -1) {
        ArrayDeleteItem(g_irgpMarkers, iGlobalId);
    }
}

public Hwn_Collector_Fw_PlayerPoints(pPlayer) {
    @Player_UpdateMarkersVisibility(pPlayer);
}

public HamHook_Player_Spawn_Post(pPlayer) {
    @Player_UpdateMarkersVisibility(pPlayer);
}

@Player_UpdateMarkersVisibility(this) {
    static iMarkCount; iMarkCount = ArraySize(g_irgpMarkers);
    for (new iMarker = 0; iMarker < iMarkCount; ++iMarker) {
        static pMarker; pMarker = ArrayGetCell(g_irgpMarkers, iMarker);
        WaypointMarker_SetVisible(pMarker, this, @Player_ShouldSeeMarker(this, pMarker));
    }
}

bool:@Player_ShouldSeeMarker(this, pMarker) {
    if (!get_pcvar_bool(g_pCvarEnabled)) return false;
    if (!is_user_alive(this)) return false;

    static iMarkerTeam; iMarkerTeam = pev(pMarker, pev_team);
    static iTeam; iTeam = get_member(this, m_iTeam);
    if (iMarkerTeam && iMarkerTeam != iTeam) return false;

    new iPoints = Hwn_Collector_GetPlayerPoints(this);
    if (!iPoints) return false;

    return true;
}
