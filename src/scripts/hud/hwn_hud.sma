#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#if AMXX_VERSION_NUM < 183
    #include <dhudmessage>
#endif

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Hwn] HUD"
#define AUTHOR "Hedgehog Fog"

new g_hGamemodeCollector;

new g_hudMsgTeamPoints;

new g_maxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    register_dictionary("hwn.txt");
    register_dictionary("miscstats.txt");
    
    g_hudMsgTeamPoints = CreateHudSyncObj();
    
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);
    
    CE_RegisterHook(CEFunction_Spawn, "hwn_item_gift", "OnGiftSpawn");
    CE_RegisterHook(CEFunction_Killed, "hwn_item_gift", "OnGiftKilled");
    CE_RegisterHook(CEFunction_Picked, "hwn_item_gift", "OnGiftPicked");
    
    CE_RegisterHook(CEFunction_Picked, "hwn_item_spellbook", "OnSpellbookPicked");
    
    g_maxPlayers = get_maxplayers();
    g_hGamemodeCollector = Hwn_Gamemode_GetHandler("Collector");
    
    set_task(1.0, "TaskUpdate", _, _, _, "b");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Collector_Fw_TeamPoints(team)
{
    UpdateTeamPoints();
}

public Hwn_Collector_Fw_PlayerPoints(id)
{
    UpdatePlayerPoints(id);
}

public Hwn_Bosses_Fw_Winner(id)
{
    new szName[128];
    get_user_name(id, szName, charsmax(szName));
    client_print(0, print_chat, "%L", LANG_PLAYER, "HWN_DEFEAT_BOSS", szName);
    
    SetupNotificationMessage(-1.0, 0.35);
    show_dhudmessage(id, "%L", LANG_PLAYER, "HWN_BOSS_REWARD");
}

public Hwn_Wof_Fw_Roll_Start()
{
    SetupNotificationMessage(-1.0, 0.15);
    show_dhudmessage(0, "Wheel of Fate roll started...");
}

public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    new szName[32];
    Hwn_Wof_Spell_GetName(spellIdx, szName, charsmax(szName));

    SetupNotificationMessage(-1.0, 0.15, .holdTime = 0.25);
    show_dhudmessage(0, "Your fate... Is... %s!", szName);
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerSpawn(id)
{
    SetupNotificationMessage(-1.0, 0.65);
    show_dhudmessage(id, "%L", LANG_PLAYER, "HWN_MENU_HELP");
}

public OnGiftSpawn(ent)
{    
    new owner = pev(ent, pev_owner);
    
    SetupNotificationMessage(-1.0, 0.35);
    show_dhudmessage(owner, "%L", LANG_PLAYER, "HWN_GIFT_SPAWN");
}

public OnGiftKilled(ent, bool:picked)
{
    if (!picked) {
        new owner = pev(ent, pev_owner);
        
        SetupNotificationMessage(-1.0, 0.35);
        show_dhudmessage(owner, "%L", LANG_PLAYER, "HWN_GIFT_DISAPPEARED");
    }
}

public OnGiftPicked(ent, id)
{
    static szName[128];
    get_user_name(id, szName, charsmax(szName));
    
    SetupNotificationMessage(0.05, 0.35);
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_GIFT_FOUND", szName);
}

public OnSpellbookPicked(ent, id)
{
    UpdatePlayerSpell(id);
    
    SetupNotificationMessage(-1.0, 0.65);
    show_dhudmessage(id, "%L", LANG_PLAYER, "HWN_SPELLBOOK_PICKUP");
}

/*--------------------------------[ Methods ]--------------------------------*/

UpdateTeamPoints()
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    new tPoints = Hwn_Collector_GetTeamPoints(1);    
    new ctPoints = Hwn_Collector_GetTeamPoints(2);

    ClearSyncHud(0, g_hudMsgTeamPoints);
    
    set_hudmessage
    (
        .red = 127,
        .green = 0,
        .blue = 255,
        .x = -1.0,
        .y = 0.075,
        .fxtime = 0.0,
        .holdtime = 1.0,
        .channel = 1
    );    
    
    ShowSyncHudMsg(0, g_hudMsgTeamPoints, "%L: %i^t^t|^t^t%L %i", LANG_PLAYER, "TERRORISTS", tPoints, LANG_PLAYER, "CTS", ctPoints);
}

UpdatePlayerPoints(id)
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    new playerPoints = Hwn_Collector_GetPlayerPoints(id);
    
    set_hudmessage
    (
        .red = 127,
        .green = 0,
        .blue = 255,
        .x = 0.95,
        .y = 0.85,
        .fxtime = 0.0,
        .holdtime = 1.0,
        .channel = 3
    );
    
    show_hudmessage(id, "%L", LANG_PLAYER, "HWN_PLAYER_POINTS", playerPoints);
}

UpdatePlayerSpell(id)
{
    new amount;
    new userSpell = Hwn_Spell_GetPlayerSpell(id, amount);
    
    if (userSpell < 0) {
        return;
    }
    
    set_hudmessage
    (
        .red = 127,
        .green = 0,
        .blue = 255,
        .x = -1.0,
        .y = 0.85,
        .fxtime = 0.0,
        .holdtime = 1.0,
        .channel = 4
    );
    
    static szSpellName[32];
    Hwn_Spell_GetName(userSpell, szSpellName, charsmax(szSpellName));
    show_hudmessage(id, "%L x%i", LANG_PLAYER, "HWN_SPELL", szSpellName, amount);
}

SetupNotificationMessage(Float:x = -1.0, Float:y = -1.0, const color[3] = {HWN_COLOR_PURPLE}, Float:holdTime = 3.0)
{
    set_dhudmessage
    (
        .red = color[0],
        .green = color[1],
        .blue = color[2],
        .x = x,
        .y = y,
        .effects = 0,
        .fxtime = 0.0,
        .holdtime = holdTime,
        .fadeintime = 0.1,
        .fadeouttime = 1.5
    );
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskUpdate()
{
    for (new id = 0; id <= g_maxPlayers; ++id) {
        if (!is_user_connected(id))    {
            continue;
        }
        
        if (is_user_alive(id)) {
            UpdatePlayerPoints(id);
            UpdatePlayerSpell(id);
        }
    }
    
    UpdateTeamPoints();
}