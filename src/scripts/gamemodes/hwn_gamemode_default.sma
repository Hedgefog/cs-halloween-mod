#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Hwn] Gamemode Default"
#define AUTHOR "Hedgehog Fog"

enum CustomSky
{
    CustomSky_Name[32],
    CustomSky_Color[3]
}

new const g_szSkySufixes[][4] = {"bk", "dn", "ft", "lf", "rt", "up"};

new const g_customSkies[][CustomSky] = {
    {"hwn1", {56, 56, 72}},
    {"hwn2", {25, 21, 29}},
    {"hwn3", {56, 56, 72}},
    {"hwn4", {72, 64, 72}}
};

new g_hGamemode;

new g_cvarSpellsOnSpawn;
new g_cvarRandomEvents;
new g_cvarChangeLighting;

new g_customSkyIdx = -1;

new g_defaultLigthStyle[] = "0";
new g_customLigthStyle[] = "e";
new g_defaultSkyName[32];
new g_defaultSkyColor[3];
new g_prevChangeLightingCvarVal;

public plugin_precache()
{
    g_customSkyIdx = random(sizeof(g_customSkies));

    new szPath[32];
    for (new i = 0; i < sizeof(g_szSkySufixes); ++i) {
        format(szPath, charsmax(szPath), "gfx/env/%s%s.tga", g_customSkies[g_customSkyIdx][CustomSky_Name], g_szSkySufixes[i]);
        precache_generic(szPath);
    }

    g_cvarChangeLighting = register_cvar("hwn_gamemode_change_lighting", "1");

    g_hGamemode = Hwn_Gamemode_Register(
        .szName = "Default",
        .flags = Hwn_GamemodeFlag_Default
    );

    register_forward(FM_LightStyle, "OnLightStyle", 0);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_cvarSpellsOnSpawn = register_cvar("hwn_gamemode_spells_on_spawn", "1");
    g_cvarRandomEvents = register_cvar("hwn_gamemode_random_events", "1");

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Fw_ConfigLoaded()
{
    CreateEventTask();
    UpdateSky();

    set_task(3.0, "TaskUpdateLighting", _, _, _, "b");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnLightStyle(style, szPattern[])
{
    if (style) {
        return;
    }

    g_defaultLigthStyle[0] = szPattern[0];
    g_defaultSkyColor[0] = get_cvar_num("sv_skycolor_r");
    g_defaultSkyColor[1] = get_cvar_num("sv_skycolor_g");
    g_defaultSkyColor[2] = get_cvar_num("sv_skycolor_b");
    get_cvar_string("sv_skyname", g_defaultSkyName, charsmax(g_defaultSkyName));
}

public OnPlayerSpawn(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    if (Hwn_Gamemode_GetCurrent() != g_hGamemode) {
        return;
    }

    new spellsOnSpawn = get_pcvar_num(g_cvarSpellsOnSpawn);

    if (spellsOnSpawn > 0) {
        new spellCount = Hwn_Spell_GetCount();
        if (spellCount) {
            Hwn_Spell_SetPlayerSpell(id, random(spellCount), spellsOnSpawn);
        }
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

UpdateSky()
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemode) {
        return;
    }

    if (get_pcvar_num(g_cvarChangeLighting) > 0) {
        set_cvar_string("sv_skyname", g_customSkies[g_customSkyIdx][CustomSky_Name]);
        set_cvar_num("sv_skycolor_r", g_customSkies[g_customSkyIdx][CustomSky_Color][0]);
        set_cvar_num("sv_skycolor_g", g_customSkies[g_customSkyIdx][CustomSky_Color][1]);
        set_cvar_num("sv_skycolor_b", g_customSkies[g_customSkyIdx][CustomSky_Color][2]);
    } else {
        set_cvar_string("sv_skyname", g_defaultSkyName);
        set_cvar_num("sv_skycolor_r", g_defaultSkyColor[0]);
        set_cvar_num("sv_skycolor_g", g_defaultSkyColor[1]);
        set_cvar_num("sv_skycolor_b", g_defaultSkyColor[2]);
    }
}

CreateEventTask()
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemode) {
        return;
    }

    set_task(random_float(5.0, 20.0), "TaskEvent");
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskEvent()
{
    CreateEventTask();

    if (!get_pcvar_num(g_cvarRandomEvents)) {
        return;
    }

    static Float:vOrigin[3];
    if (!Hwn_EventPoints_GetRandom(vOrigin)) {
        return;
    }

    new ent = 0;

    switch (random(3)) {
        case 0: {
            ent = CE_Create("hwn_npc_ghost", vOrigin);
        }
        case 1: {
            ent = CE_Create("hwn_npc_skeleton", vOrigin);
        }
        case 2: {
            ent = CE_Create("hwn_item_spellbook", vOrigin);
        }
    }

    if (ent) {
        dllfunc(DLLFunc_Spawn, ent);
    }
}

public TaskUpdateLighting()
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemode) {
        return;
    }

    new changeLighting = get_pcvar_num(g_cvarChangeLighting);

    new bool:useCustom = changeLighting > 0
        && g_defaultLigthStyle[0] > g_customLigthStyle[0];

    engfunc(EngFunc_LightStyle, 0, useCustom ? g_customLigthStyle : g_defaultLigthStyle);

    if (g_prevChangeLightingCvarVal != changeLighting) {
        UpdateSky();
    }

    g_prevChangeLightingCvarVal = changeLighting;
}
