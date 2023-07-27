#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_rounds>
#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Event Handler"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_event_handler"

new Array:g_irgEventHandlers = Invalid_Array;

public plugin_precache() {
    CE_Register(ENTITY_NAME);
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "@Entity_Spawn");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_end() {
    if (g_irgEventHandlers != Invalid_Array) {
        ArrayDestroy(g_irgEventHandlers);
    }
}

/*------------[ Hooks ]------------*/

@Entity_Spawn(this) {
    if (g_irgEventHandlers == Invalid_Array) {
        g_irgEventHandlers = ArrayCreate();
    }

    ArrayPushCell(g_irgEventHandlers, this);
}

/*------------[ Methods ]------------*/

Dispatch(const eventName[], caller = 0) {
    if (g_irgEventHandlers == Invalid_Array) {
        return;
    }

    new iSize = ArraySize(g_irgEventHandlers);

    for (new i = 0; i < iSize; ++i) {
        new pEntity = ArrayGetCell(g_irgEventHandlers, i);

        static szTargetname[32];
        pev(pEntity, pev_targetname, szTargetname, charsmax(szTargetname));

        if (!equal(szTargetname, eventName)) {
            continue;
        }

        static szTarget[32];
        pev(pEntity, pev_target, szTarget, charsmax(szTarget));

        new pTarget = 0;
        while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "targetname", szTarget)) != 0) {
            ExecuteHamB(Ham_Use, pTarget, caller, pEntity, 2, 1.0);
        }
    }
}

/*------------[ Events ]------------*/

public Round_Fw_NewRound() {
    Dispatch("new_round");
}

public Round_Fw_RoundStart() {
    Dispatch("round_start");
}

public Round_Fw_RoundEnd() {
    Dispatch("round_end");
}

public Hwn_Bosses_Fw_BossSpawn(pEntity) {
    Dispatch("boss_spawn", pEntity);
}

public Hwn_Bosses_Fw_BossKill(pEntity) {
    Dispatch("boss_kill", pEntity);
}

public Hwn_Bosses_Fw_BossRemove(pEntity) {
    Dispatch("boss_remove", pEntity);
}

public Hwn_Bosses_Fw_BossEscape(pEntity) {
    Dispatch("boss_escape", pEntity);
}

public Hwn_Bosses_Fw_BossTeleport(pEntity) {
    Dispatch("boss_teleport", pEntity);
}

public Hwn_Bosses_Fw_Winner(pPlayer, damage) {
    Dispatch("boss_winner", pPlayer);
}

public Hwn_Collector_Fw_TeamPoints(iTeam) {
    if (iTeam == 1) {
        Dispatch("teampoints_team1");
    } else if (iTeam == 2) {
        Dispatch("teampoints_team2");
    }
}

public Hwn_Collector_Fw_PlayerPoints(pPlayer) {
    Dispatch("playerpoints", pPlayer);
}

public Hwn_Spell_Fw_Cast(pPlayer) {
    Dispatch("spell_cast", pPlayer);
}

public Hwn_Wof_Fw_Roll_Start() {
    Dispatch("wof_roll_start");
}

public Hwn_Wof_Fw_Roll_End() {
    Dispatch("wof_roll_end");
}

public Hwn_Wof_Fw_Effect_Start() {
    Dispatch("wof_effect_start");
}

public Hwn_Wof_Fw_Effect_End() {
    Dispatch("wof_effect_end");
}

public Hwn_Wof_Fw_Effect_Invoke(pPlayer) {
    Dispatch("wof_effect_invoke", pPlayer);
}

public Hwn_Wof_Fw_Effect_Revoke(pPlayer) {
    Dispatch("wof_effect_revoke", pPlayer);
}

public Hwn_Wof_Fw_Abort() {
    Dispatch("wof_abort");
}
