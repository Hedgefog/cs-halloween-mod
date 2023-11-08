#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_rounds>
#include <api_custom_entities>
#include <api_custom_events>

#include <hwn>

#define PLUGIN "[Hwn] Events"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Round_Fw_NewRound() {
    DispatchEvent("hwn_new_round");
}

public Round_Fw_RoundStart() {
    DispatchEvent("hwn_round_start");
}

public Round_Fw_RoundEnd() {
    DispatchEvent("hwn_round_end");
}

public Hwn_Bosses_Fw_BossSpawn(pEntity) {
    DispatchEvent("hwn_boss_spawn", pEntity);
}

public Hwn_Bosses_Fw_BossKill(pEntity) {
    DispatchEvent("hwn_boss_kill", pEntity);
}

public Hwn_Bosses_Fw_BossRemove(pEntity) {
    DispatchEvent("hwn_boss_remove", pEntity);
}

public Hwn_Bosses_Fw_BossEscape(pEntity) {
    DispatchEvent("hwn_boss_escape", pEntity);
}

public Hwn_Bosses_Fw_BossTeleport(pEntity) {
    DispatchEvent("hwn_boss_teleport", pEntity);
}

public Hwn_Bosses_Fw_Winner(pPlayer) {
    DispatchEvent("hwn_boss_winner", pPlayer);
}

public Hwn_Collector_Fw_TeamPoints(iTeam) {
    if (iTeam == 1) {
        DispatchEvent("hwn_teampoints_team1");
    } else if (iTeam == 2) {
        DispatchEvent("hwn_teampoints_team2");
    }
}

public Hwn_Collector_Fw_TeamPointsScored(iTeam, iCount, pPlayer) {
    if (iTeam == 1) {
        DispatchEvent("hwn_teampoints_scored_team1", pPlayer);
    } else if (iTeam == 2) {
        DispatchEvent("hwn_teampoints_scored_team2", pPlayer);
    }
}

public Hwn_Collector_Fw_PlayerPoints(pPlayer) {
    DispatchEvent("hwn_playerpoints", pPlayer);
}

public Hwn_Spell_Fw_Cast(pPlayer) {
    DispatchEvent("hwn_spell_cast", pPlayer);
}

public Hwn_Wof_Fw_Roll_Start() {
    DispatchEvent("hwn_wof_roll_start");
}

public Hwn_Wof_Fw_Roll_End() {
    DispatchEvent("hwn_wof_roll_end");
}

public Hwn_Wof_Fw_Effect_Start() {
    DispatchEvent("hwn_wof_effect_start");
}

public Hwn_Wof_Fw_Effect_End() {
    DispatchEvent("hwn_wof_effect_end");
}

public Hwn_Wof_Fw_Effect_Invoke(pPlayer) {
    DispatchEvent("hwn_wof_effect_invoke", pPlayer);
}

public Hwn_Wof_Fw_Effect_Revoke(pPlayer) {
    DispatchEvent("hwn_wof_effect_revoke", pPlayer);
}

public Hwn_Wof_Fw_Abort() {
    DispatchEvent("hwn_wof_abort");
}

DispatchEvent(const szEvent[], pActivator = 0) {
    CustomEvent_SetActivator(pActivator);
    CustomEvent_Emit(szEvent);
}
