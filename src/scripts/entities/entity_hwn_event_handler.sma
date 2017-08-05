#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Event Handler"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_event_handler"

new Array:g_eventHandlers;

public plugin_precache()
{
    CE_Register(ENTITY_NAME);
    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_end()
{
    if (g_eventHandlers != Invalid_Array) {
        ArrayDestroy(g_eventHandlers);
    }
}

/*------------[ Hooks ]------------*/

public OnSpawn(ent)
{
    if (g_eventHandlers == Invalid_Array) {
        g_eventHandlers = ArrayCreate();
    }

    ArrayPushCell(g_eventHandlers, ent);
}

/*------------[ Methods ]------------*/

Dispatch(const eventName[], caller = 0)
{
    if (g_eventHandlers == Invalid_Array) {
        return;
    }

    new size = ArraySize(g_eventHandlers);

    for (new i = 0; i < size; ++i) {
        new ent = ArrayGetCell(g_eventHandlers, i);

        static szTargetname[32];
        pev(ent, pev_targetname, szTargetname, charsmax(szTargetname));

        if (!equal(szTargetname, eventName)) {
            continue;
        }

        static szTarget[32];
        pev(ent, pev_target, szTarget, charsmax(szTarget));

        new target;
        while ((target = engfunc(EngFunc_FindEntityByString, target, "targetname", szTarget)) != 0) {
            ExecuteHamB(Ham_Use, target, caller, ent, 2, 1.0);
        }
    }
}

/*------------[ Events ]------------*/

public Hwn_Gamemode_Fw_NewRound()
{
    Dispatch("new_round");
}

public Hwn_Gamemode_Fw_RoundStart()
{
    Dispatch("round_start");
}

public Hwn_Gamemode_Fw_RoundEnd()
{
    Dispatch("round_end");
}

public Hwn_Bosses_Fw_BossSpawn(ent)
{
    Dispatch("boss_spawn", ent);
}

public Hwn_Bosses_Fw_BossKill(ent)
{
    Dispatch("boss_kill", ent);
}

public Hwn_Bosses_Fw_BossEscape(ent)
{
    Dispatch("boss_escape", ent);
}

public Hwn_Bosses_Fw_BossTeleport(ent)
{
    Dispatch("boss_teleport", ent);
}

public Hwn_Bosses_Fw_Winner(id)
{
    Dispatch("boss_winner", id);
}

public Hwn_Collector_Fw_TeamPoints(team)
{
    if (team == 1) {
        Dispatch("teampoints_team1");
    } else if (team == 2) {
        Dispatch("teampoints_team2");
    }
}

public Hwn_Collector_Fw_PlayerPoints(id)
{
    Dispatch("playerpoints", id);
}

public Hwn_Spell_Fw_Cast(id)
{
    Dispatch("spell_cast", id);
}