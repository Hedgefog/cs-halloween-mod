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

new Float:g_rgvecEventPoints[MAX_EVENT_POINTS][3];

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHamPlayer(Ham_Killed, "HamHook_Player_Killed_Post", .Post = 1);
}

public plugin_natives() {
    register_library("hwn");
    register_native("Hwn_EventPoints_Add", "Native_Add");
    register_native("Hwn_EventPoints_GetCount", "Native_GetCount");
    register_native("Hwn_EventPoints_Get", "Native_Get");
    register_native("Hwn_EventPoints_GetRandom", "Native_GetRandom");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Native_Add(iPluginId, iArgc) {
    new Float:vecOrigin[3];
    get_array_f(1, vecOrigin, sizeof(vecOrigin));

    Add(vecOrigin);
}

public Native_GetCount(iPluginId, iArgc) {
    return GetCount();
}

public bool:Native_Get(iPluginId, iArgc) {
    new iPointIdx = get_param(1);

    new Float:vecOrigin[3];
    new bool:bResult = Get(iPointIdx, vecOrigin);
    set_array_f(2, vecOrigin, sizeof(vecOrigin));

    return bResult;
}

public bool:Native_GetRandom(iPluginId, iArgc) {
    new Float:vecOrigin[3];
    new bool:bResult = GetRandom(vecOrigin);
    set_array_f(1, vecOrigin, sizeof(vecOrigin));

    return bResult;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Killed_Post(pPlayer) {
    if (Hwn_Gamemode_IsPlayerOnSpawn(pPlayer, true)) {
        return;
    }

    new Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    if (!pev(pPlayer, pev_bInDuck)) {
        vecOrigin[2] += 18.0;
    }

    Add(vecOrigin);
}

/*--------------------------------[ Methods ]--------------------------------*/

Add(const Float:vecOrigin[3]) {
    new bool:bIsFull = xs_vec_len(g_rgvecEventPoints[MAX_EVENT_POINTS - 1]) > 0.0;

    for (new iPoint = 0; iPoint < MAX_EVENT_POINTS; ++iPoint) {
        if (bIsFull) {
            if (!iPoint) {
                continue;
            }

            xs_vec_copy(g_rgvecEventPoints[iPoint], g_rgvecEventPoints[iPoint - 1]);

            if (iPoint < MAX_EVENT_POINTS - 1) {
                continue;
            }
        } else {
            if (xs_vec_len(g_rgvecEventPoints[iPoint]) > 0.0) {
                continue;
            }
        }

        xs_vec_copy(vecOrigin, g_rgvecEventPoints[iPoint]);
        break;
    }
}

bool:Get(iPoint, Float:vecOrigin[3]) {
  if (iPoint >= GetCount()) {
    return false;
  }

  xs_vec_copy(g_rgvecEventPoints[iPoint], vecOrigin);

  return true;
}

bool:GetRandom(Float:vecOrigin[3]) {
    new iNum = GetCount();
    return Get(random(iNum), vecOrigin);
}

GetCount() {
    new iNum = 0;
    for (new i = 0; i < MAX_EVENT_POINTS; ++i) {
        if (xs_vec_len(g_rgvecEventPoints[i]) == 0.0) {
            break;
        }

        iNum++;
    }

    return iNum;
}
