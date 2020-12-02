#pragma semicolon 1

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#include <hwn>

#define PLUGIN "[Hwn] Event Points"
#define AUTHOR "Hedgehog Fog"

#define MIN_EVENT_POINTS 8
#define MAX_EVENT_POINTS 32

new Float:g_eventPoints[MAX_EVENT_POINTS][3];

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_Killed, "player", "OnPlayerKilled", .Post = 1);
}

public plugin_natives()
{
    register_library("hwn");
    register_native("Hwn_EventPoints_Add", "Native_Add");
    register_native("Hwn_EventPoints_GetCount", "Native_GetCount");
    register_native("Hwn_EventPoints_Get", "Native_Get");
    register_native("Hwn_EventPoints_GetRandom", "Native_GetRandom");
}

/*--------------------------------[ Native ]--------------------------------*/

public Native_Add(pluginID, argc)
{
    new Float:vOrigin[3];
    get_array_f(1, vOrigin, sizeof(vOrigin));

    Add(vOrigin);
}

public Native_GetCount(pluginID, argc)
{
    return GetCount();
}

public bool:Native_Get(pluginID, argc)
{
    new pointIdx = get_param(1);

    new Float:vOrigin[3];
    new bool:result = Get(pointIdx, vOrigin);
    set_array_f(2, vOrigin, sizeof(vOrigin));

    return result;
}

public bool:Native_GetRandom(pluginID, argc)
{
    new Float:vOrigin[3];
    new bool:result = GetRandom(vOrigin);
    set_array_f(1, vOrigin, sizeof(vOrigin));

    return result;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerKilled(id)
{
    if (Hwn_Gamemode_IsPlayerOnSpawn(id)) {
        return;
    }

    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    if (!pev(id, pev_bInDuck)) {
        vOrigin[2] += 18.0;
    }

    Add(vOrigin);
}

/*--------------------------------[ Methods ]--------------------------------*/

Add(const Float:vOrigin[3])
{
    new bool:isFull = xs_vec_len(g_eventPoints[MAX_EVENT_POINTS - 1]) > 0.0;

    for (new i = 0; i < MAX_EVENT_POINTS; ++i) {
        if (isFull) {
            if (!i) {
                continue;
            }

            xs_vec_copy(g_eventPoints[i], g_eventPoints[i - 1]);

            if (i < MAX_EVENT_POINTS - 1) {
                continue;
            }
        } else {
            if (xs_vec_len(g_eventPoints[i]) > 0.0) {
                continue;
            }
        }

        xs_vec_copy(vOrigin, g_eventPoints[i]);
        break;
    }
}

bool:Get(pointIdx, Float:vOrigin[3])
{
  new count = GetCount();
  if (pointIdx >= count) {
    return false;
  }

  xs_vec_copy(g_eventPoints[pointIdx], vOrigin);

  return true;
}

bool:GetRandom(Float:vOrigin[3])
{
    new count = GetCount();
    return Get(random(count), vOrigin);
}

GetCount()
{
    new count = 0;
    for (new i = 0; i < MAX_EVENT_POINTS; ++i) {
        if (xs_vec_len(g_eventPoints[i]) == 0.0) {
            break;
        }

        count++;
    }

    return count;
}
