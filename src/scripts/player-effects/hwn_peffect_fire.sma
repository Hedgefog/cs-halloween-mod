#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>
#include <hwn_crits>

#define PLUGIN "[Hwn] Fire Player Effect"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

#define EFFECT_ID "fire"

new g_pPlayerFire[MAX_PLAYERS + 1];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    CE_RegisterHook(CEFunction_Remove, "fire", "@Fire_Remove");

    Hwn_PlayerEffect_Register(EFFECT_ID, "@Player_EffectInvoke", "@Player_EffectRevoke", "dmg_heat", {255, 128, 0});
}

@Player_EffectInvoke(pPlayer) {
    new pFire = CE_Create("fire");
    if (!pFire) return PLUGIN_HANDLED;

    dllfunc(DLLFunc_Spawn, pFire);
    set_pev(pFire, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(pFire, pev_aiment, pPlayer);

    g_pPlayerFire[pPlayer] = pFire;

    return PLUGIN_CONTINUE;
}

@Player_EffectRevoke(pPlayer) {
    if (g_pPlayerFire[pPlayer]) {
        CE_Kill(g_pPlayerFire[pPlayer]);
    }
}

@Fire_Remove(this) {
    new pAimEnt = pev(this, pev_aiment);

    // If something removes fire entity of the current effect
    if (IS_PLAYER(pAimEnt) && g_pPlayerFire[pAimEnt] == this) {
        g_pPlayerFire[pAimEnt] = 0;
        Hwn_Player_SetEffect(pAimEnt, "fire", false);
    }
}
