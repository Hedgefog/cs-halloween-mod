#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Hwn] Gamemode Default"
#define AUTHOR "Hedgehog Fog"

#define TASKID_UPDATE_SKY 0

#define GAMEMODE_NAME "Default"
#define GAMEMODE_FLAGS (Hwn_GamemodeFlag_Default | Hwn_GamemodeFlag_SpellShop)

enum CustomSky { CustomSky_Name[32], CustomSky_Color[3] };

new const g_rgszSkySufixes[][4] = { "bk", "dn", "ft", "lf", "rt", "up" };

new const g_rgCustomSkies[][CustomSky] = {
    { "hwn1", { 56, 56, 72 } },
    { "hwn2", { 25, 21, 29 } },
    { "hwn3", { 56, 56, 72 } },
    { "hwn4", { 72, 64, 72 } }
};

new const g_rgszRandomEntities[][] = {
    "hwn_item_spellbook",
    "hwn_npc_ghost",
    "hwn_npc_skeleton",
    "hwn_npc_spookypumpkin"
};

new g_pCvarSpellsOnSpawn;
new g_pCvarRandomEvents;
new g_pCvarChangeLighting;

new g_iGamemode;

new g_iCustomSky = -1;

new g_szDefaultLigthStyle[] = "0";
new g_szCustomLigthStyle[] = "g";
new g_szDefaultSkyName[32];
new g_rgiDefaultSkyColor[3];

public plugin_precache() {
    g_iCustomSky = random(sizeof(g_rgCustomSkies));

    PrecacheSky(g_rgCustomSkies[g_iCustomSky][CustomSky_Name]);

    g_iGamemode = Hwn_Gamemode_Register(GAMEMODE_NAME, GAMEMODE_FLAGS);
    
    g_pCvarChangeLighting = register_cvar("hwn_gamemode_change_lighting", "1");

    hook_cvar_change(g_pCvarChangeLighting, "CvarHook_ChangeLighting");

    register_forward(FM_LightStyle, "FMHook_LightStyle", 0);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarSpellsOnSpawn = register_cvar("hwn_gamemode_spells_on_spawn", "1");
    g_pCvarRandomEvents = register_cvar("hwn_gamemode_random_events", "1");

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Gamemode_Fw_Activated(iGamemode) {
    remove_task(TASKID_UPDATE_SKY);

    if (iGamemode != g_iGamemode) return;

    set_task(15.0, "Task_Event", TASKID_UPDATE_SKY, _, _, "b");

    UpdateLighting();
}

/*--------------------------------[ Hooks ]--------------------------------*/

public FMHook_LightStyle(iStyle, const szPattern[]) {
    if (iStyle) return;

    g_szDefaultLigthStyle[0] = szPattern[0];

    g_rgiDefaultSkyColor[0] = get_cvar_num("sv_skycolor_r");
    g_rgiDefaultSkyColor[1] = get_cvar_num("sv_skycolor_g");
    g_rgiDefaultSkyColor[2] = get_cvar_num("sv_skycolor_b");

    get_cvar_string("sv_skyname", g_szDefaultSkyName, charsmax(g_szDefaultSkyName));
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) return;
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    new bSpellsOnSpawn = get_pcvar_bool(g_pCvarSpellsOnSpawn);

    if (bSpellsOnSpawn > 0) {
        new iSpellsNum = Hwn_Spell_GetCount();
        if (iSpellsNum) Hwn_Spell_SetPlayerSpell(pPlayer, random(iSpellsNum), bSpellsOnSpawn);
    }
}

public CvarHook_ChangeLighting(pCvar) {
    UpdateLighting();
}

/*--------------------------------[ Functions ]--------------------------------*/

PrecacheSky(const szName[]) {
    new szPath[32];
    for (new i = 0; i < sizeof(g_rgszSkySufixes); ++i) {
        format(szPath, charsmax(szPath), "gfx/env/%s%s.tga", szName, g_rgszSkySufixes[i]);
        precache_generic(szPath);
    }
}

UpdateLighting() {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    new bool:bChangeLighting = get_pcvar_bool(g_pCvarChangeLighting);

    new bool:bUseCustom = (
        bChangeLighting &&
        g_szDefaultLigthStyle[0] > g_szCustomLigthStyle[0]
    );

    engfunc(EngFunc_LightStyle, 0, bUseCustom ? g_szCustomLigthStyle : g_szDefaultLigthStyle);
    UpdateSky();
}

UpdateSky() {
    if (Hwn_Gamemode_GetCurrent() != g_iGamemode) return;

    if (get_pcvar_num(g_pCvarChangeLighting) > 0) {
        set_cvar_string("sv_skyname", g_rgCustomSkies[g_iCustomSky][CustomSky_Name]);
        set_cvar_num("sv_skycolor_r", g_rgCustomSkies[g_iCustomSky][CustomSky_Color][0]);
        set_cvar_num("sv_skycolor_g", g_rgCustomSkies[g_iCustomSky][CustomSky_Color][1]);
        set_cvar_num("sv_skycolor_b", g_rgCustomSkies[g_iCustomSky][CustomSky_Color][2]);
    } else {
        set_cvar_string("sv_skyname", g_szDefaultSkyName);
        set_cvar_num("sv_skycolor_r", g_rgiDefaultSkyColor[0]);
        set_cvar_num("sv_skycolor_g", g_rgiDefaultSkyColor[1]);
        set_cvar_num("sv_skycolor_b", g_rgiDefaultSkyColor[2]);
    }
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Event() {
    if (!get_pcvar_num(g_pCvarRandomEvents)) return;

    static Float:vecOrigin[3];
    if (!Hwn_EventPoints_GetRandom(vecOrigin)) return;

    new iRandomEntity = random(sizeof(g_rgszRandomEntities));
    new pEntity = CE_Create(g_rgszRandomEntities[iRandomEntity], vecOrigin);
    if (pEntity) dllfunc(DLLFunc_Spawn, pEntity);
}
