#include <amxmodx>
#include <fakemeta>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Player Highlight"
#define AUTHOR "Hedgehog Fog"

new g_pCvarEnabled;
new g_pCvarPrimaryBrightness;
new g_pCvarSecondaryBrightness;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    register_forward(FM_AddToFullPack, "OnAddToFullPack", 1);

    g_pCvarEnabled = register_cvar("hwn_player_highlight", "1");
    g_pCvarPrimaryBrightness = register_cvar("hwn_player_highlight_primary_brightness", "80");
    g_pCvarSecondaryBrightness = register_cvar("hwn_player_highlight_secondary_brightness", "15");
}

public OnAddToFullPack(es, e, pEntity, pHost, hostflags, player, pSet) {
    if (!get_pcvar_num(g_pCvarEnabled)) {
        return FMRES_IGNORED;
    }

    if (!pev_valid(pEntity)) {
        return FMRES_IGNORED;
    }

    new pTargetPlayer = 0;
    if (IS_PLAYER(pEntity)) {
        pTargetPlayer = pEntity;
    } else {
        new pAimEnt = pev(pEntity, pev_aiment);
        if (IS_PLAYER(pAimEnt)) {
            pTargetPlayer = pAimEnt;
        }
    }

    if (pTargetPlayer == pHost) {
        return FMRES_IGNORED;
    }

    if (!is_user_alive(pTargetPlayer)) {
        return FMRES_IGNORED;
    }

    if (pev(pTargetPlayer, pev_rendermode) == kRenderNormal && pev(pTargetPlayer, pev_renderfx) == kRenderFxNone) {
      set_es(es, ES_RenderMode, kRenderNormal);
      set_es(es, ES_RenderFx, kRenderFxGlowShell);
      set_es(es, ES_RenderAmt, 1);

      new iPrimaryBrightness = get_pcvar_num(g_pCvarPrimaryBrightness);
      new iSecondaryBrightness = get_pcvar_num(g_pCvarSecondaryBrightness);

      static rgiColor[3];
      for (new i = 0; i < 3; ++i) {
        rgiColor[i] = iSecondaryBrightness;
      }

      new iTeam = get_member(pTargetPlayer, m_iTeam);
      switch (iTeam) {
        case 1: rgiColor[0] = iPrimaryBrightness;
        case 2: rgiColor[2] = iPrimaryBrightness;
      }


      set_es(es, ES_RenderColor, rgiColor);
    }

    return FMRES_IGNORED;
}
