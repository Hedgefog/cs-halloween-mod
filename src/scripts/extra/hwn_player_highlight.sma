#include <amxmodx>
#include <fakemeta>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Player Highlight"
#define AUTHOR "Hedgehog Fog"

new g_cvarEnabled;
new g_cvarPrimaryBrightness;
new g_cvarSecondaryBrightness;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    register_forward(FM_AddToFullPack, "OnAddToFullPack", 1);

    g_cvarEnabled = register_cvar("hwn_player_highlight", "1");
    g_cvarPrimaryBrightness = register_cvar("hwn_player_highlight_primary_brightness", "100");
    g_cvarSecondaryBrightness = register_cvar("hwn_player_highlight_secondary_brightness", "20");
}


public OnAddToFullPack(es, e, ent, host, hostflags, player, pSet)
{
    if (!get_pcvar_num(g_cvarEnabled)) {
        return FMRES_IGNORED;
    }

    if (!UTIL_IsPlayer(ent)) {
        return FMRES_IGNORED;
    }

    if (!is_user_connected(ent)) {
        return FMRES_IGNORED;
    }

    if (!is_user_alive(ent)) {
        return FMRES_IGNORED;
    }

    if (pev(ent, pev_rendermode) == kRenderNormal && pev(ent, pev_renderfx) == kRenderFxNone) {
      set_es(es, ES_RenderMode, kRenderNormal);
      set_es(es, ES_RenderFx, kRenderFxGlowShell);
      set_es(es, ES_RenderAmt, 1);

      new primaryBrightness = get_pcvar_num(g_cvarPrimaryBrightness);
      new secondaryBrightness = get_pcvar_num(g_cvarSecondaryBrightness);

      static color[3];
      for (new i = 0; i < 3; ++i) {
        color[i] = secondaryBrightness;
      }

      if (UTIL_GetPlayerTeam(ent) == 1) {
        color[0] = primaryBrightness;
      } else {
        color[2] = primaryBrightness;
      }

      set_es(es, ES_RenderColor, color);
    }


    return FMRES_IGNORED;
}
