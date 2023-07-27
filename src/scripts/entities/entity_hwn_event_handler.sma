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
    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_end() {
    if (g_irgEventHandlers != Invalid_Array) {
        ArrayDestroy(g_irgEventHandlers);
    }
}

@Entity_Init(this) {
    if (g_irgEventHandlers == Invalid_Array) {
        g_irgEventHandlers = ArrayCreate();
    }

    ArrayPushCell(g_irgEventHandlers, this);
}

@Entity_Remove(this) {
    new iGlobalId = ArrayFindValue(g_irgEventHandlers, this);
    if (iGlobalId != -1) {
        ArrayDeleteItem(g_irgEventHandlers, iGlobalId);
    }
}

DispatchEvent(const eventName[], caller = 0) {
    if (g_irgEventHandlers == Invalid_Array) {
        return;
    }

    new iSize = ArraySize(g_irgEventHandlers);
    for (new iGlobalId = 0; iGlobalId < iSize; ++iGlobalId) {
        new pEntity = ArrayGetCell(g_irgEventHandlers, iGlobalId);

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

public Round_Fw_NewRound() {
    DispatchEvent("new_round");
}

public Round_Fw_RoundStart() {
    DispatchEvent("round_start");
}

public Round_Fw_RoundEnd() {
    DispatchEvent("round_end");
}

public Hwn_Bosses_Fw_BossSpawn(pEntity) {
    DispatchEvent("boss_spawn", pEntity);
}

public Hwn_Bosses_Fw_BossKill(pEntity) {
    DispatchEvent("boss_kill", pEntity);
}

public Hwn_Bosses_Fw_BossRemove(pEntity) {
    DispatchEvent("boss_remove", pEntity);
}

public Hwn_Bosses_Fw_BossEscape(pEntity) {
    DispatchEvent("boss_escape", pEntity);
}

public Hwn_Bosses_Fw_BossTeleport(pEntity) {
    DispatchEvent("boss_teleport", pEntity);
}

public Hwn_Bosses_Fw_Winner(pPlayer, damage) {
    DispatchEvent("boss_winner", pPlayer);
}

public Hwn_Collector_Fw_TeamPoints(iTeam) {
    if (iTeam == 1) {
        DispatchEvent("teampoints_team1");
    } else if (iTeam == 2) {
        DispatchEvent("teampoints_team2");
    }
}

public Hwn_Collector_Fw_PlayerPoints(pPlayer) {
    DispatchEvent("playerpoints", pPlayer);
}

public Hwn_Spell_Fw_Cast(pPlayer) {
    DispatchEvent("spell_cast", pPlayer);
}

public Hwn_Wof_Fw_Roll_Start() {
    DispatchEvent("wof_roll_start");
}

public Hwn_Wof_Fw_Roll_End() {
    DispatchEvent("wof_roll_end");
}

public Hwn_Wof_Fw_Effect_Start() {
    DispatchEvent("wof_effect_start");
}

public Hwn_Wof_Fw_Effect_End() {
    DispatchEvent("wof_effect_end");
}

public Hwn_Wof_Fw_Effect_Invoke(pPlayer) {
    DispatchEvent("wof_effect_invoke", pPlayer);
}

public Hwn_Wof_Fw_Effect_Revoke(pPlayer) {
    DispatchEvent("wof_effect_revoke", pPlayer);
}

public Hwn_Wof_Fw_Abort() {
    DispatchEvent("wof_abort");
}
