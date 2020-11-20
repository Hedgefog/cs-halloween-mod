#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#if AMXX_VERSION_NUM < 183
    #include <dhudmessage>
#endif

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] HUD"
#define AUTHOR "Hedgehog Fog"

#define HUD_COLOR_STATIC HWN_COLOR_PRIMARY
#define HUD_COLOR_NOTIFICATION HWN_COLOR_PRIMARY

#define HUD_POS_STATIC_PLAYER_POINTS 0.01, 0.175
#define HUD_POS_STATIC_TEAM_POINTS -1.0, 0.075
#define HUD_POS_STATIC_PLAYER_SPELL -1.0, 0.85
#define HUD_POS_NOTIFICATION_INFO -1.0, 0.65
#define HUD_POS_NOTIFICATION_OVERTIME -1.0, 0.030
#define HUD_POS_NOTIFICATION_WOF -1.0, 0.15
#define HUD_POS_NOTIFICATION_BOSS_SPAWN -1.0, 0.225
#define HUD_POS_NOTIFICATION_BOSS_ESCAPE -1.0, 0.225
#define HUD_POS_NOTIFICATION_BOSS_REWARD -1.0, 0.35
#define HUD_POS_NOTIFICATION_GIFT_SPAWN -1.0, 0.35
#define HUD_POS_NOTIFICATION_GIFT_DISAPPEARED -1.0, 0.35
#define HUD_POS_NOTIFICATION_GIFT_PICKED 0.05, 0.35
#define HUD_POS_NOTIFICATION_SPELL_PICKED HUD_POS_NOTIFICATION_INFO
#define HUD_POS_NOTIFICATION_MOD_MENU HUD_POS_NOTIFICATION_INFO
#define HUD_POS_NOTIFICATION_FIRST_PUMPKIN_PICKED HUD_POS_NOTIFICATION_INFO

new g_hGamemodeCollector;

new g_hudMsgTeamPoints;
new g_hudMsgPlayerPoints;
new g_hudMsgPlayerSpell;

new g_cvarCollectorHideMoney;
new g_cvarCollectorHideTimer;
new g_cvarTeamPointsLimit;

new g_maxPlayers;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_dictionary("hwn.txt");
    register_dictionary("miscstats.txt");

    g_hudMsgTeamPoints = CreateHudSyncObj();
    g_hudMsgPlayerPoints = CreateHudSyncObj();
    g_hudMsgPlayerSpell = CreateHudSyncObj();

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", .Post = 1);

    register_event("ResetHUD", "OnResetHUD", "b");
    register_message(get_user_msgid("HideWeapon"), "OnMessageHideWeapon");

    CE_RegisterHook(CEFunction_Spawn, "hwn_item_gift", "OnGiftSpawn");
    CE_RegisterHook(CEFunction_Killed, "hwn_item_gift", "OnGiftKilled");
    CE_RegisterHook(CEFunction_Picked, "hwn_item_gift", "OnGiftPicked");

    CE_RegisterHook(CEFunction_Picked, "hwn_item_spellbook", "OnSpellbookPicked");

    g_maxPlayers = get_maxplayers();
    g_hGamemodeCollector = Hwn_Gamemode_GetHandler("Collector");

    g_cvarCollectorHideMoney = register_cvar("hwn_hud_collector_hide_money", "1");
    g_cvarCollectorHideTimer = register_cvar("hwn_hud_collector_hide_timer", "0");
    g_cvarTeamPointsLimit = get_cvar_pointer("hwn_collector_teampoints_limit");

    set_task(1.0, "TaskUpdate", _, _, _, "b");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Collector_Fw_TeamPoints(team)
{
    UpdateTeamPoints();
}

public Hwn_Collector_Fw_PlayerPoints(id)
{
    if (Hwn_Collector_GetPlayerPoints(id) == 1) {
        SetupNotificationMessage(HUD_POS_NOTIFICATION_FIRST_PUMPKIN_PICKED);
        show_dhudmessage(id, "%L", LANG_PLAYER, "HWN_FIRST_PUMPKIN_PICKED");
    }

    UpdatePlayerPoints(id);
}

public Hwn_Bosses_Fw_Winner(id)
{
    new szName[128];
    get_user_name(id, szName, charsmax(szName));
    client_print(0, print_chat, "%L", LANG_PLAYER, "HWN_DEFEAT_BOSS", szName);

    SetupNotificationMessage(HUD_POS_NOTIFICATION_BOSS_REWARD);
    show_dhudmessage(id, "%L", LANG_PLAYER, "HWN_BOSS_REWARD");
}

public Hwn_Bosses_Fw_BossSpawn()
{
    new bossIdx = Hwn_Bosses_GetCurrent();

    static szName[128];
    Hwn_Bosses_GetName(bossIdx, szName, charsmax(szName));

    SetupNotificationMessage(HUD_POS_NOTIFICATION_BOSS_SPAWN);
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_BOSS_SPAWN", szName);
}

public Hwn_Bosses_Fw_BossEscape()
{
    new bossIdx = Hwn_Bosses_GetCurrent();

    static szName[128];
    Hwn_Bosses_GetName(bossIdx, szName, charsmax(szName));

    SetupNotificationMessage(HUD_POS_NOTIFICATION_BOSS_ESCAPE);
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_BOSS_ESCAPE", szName);
}

public Hwn_Wof_Fw_Roll_Start()
{
    SetupNotificationMessage(HUD_POS_NOTIFICATION_WOF);
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_WOF_ROLL_STARTED");
}

public Hwn_Wof_Fw_Effect_Start(spellIdx)
{
    SetupNotificationMessage(HUD_POS_NOTIFICATION_WOF);

    static szSpellName[128];
    Hwn_Wof_Spell_GetDictionaryKey(spellIdx, szSpellName, charsmax(szSpellName));

    if (szSpellName[0] == '^0') {
        Hwn_Wof_Spell_GetName(spellIdx, szSpellName, charsmax(szSpellName));
        show_dhudmessage(0, "%L %s!", LANG_PLAYER, "HWN_WOF_EFFECT_STARTED", szSpellName);
    } else {
        show_dhudmessage(0, "%L %L!", LANG_PLAYER, "HWN_WOF_EFFECT_STARTED", LANG_PLAYER, szSpellName);
    }
}

public Hwn_Collector_Fw_Overtime(overtime)
{
    SetupNotificationMessage(HUD_POS_NOTIFICATION_OVERTIME, .holdTime = float(overtime));
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_OVERTIME");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnPlayerSpawn(id)
{
    if (!is_user_alive(id)) {
        return;
    }

    SetupNotificationMessage(HUD_POS_NOTIFICATION_MOD_MENU);
    show_dhudmessage(id, "%L", LANG_PLAYER, "HWN_MENU_HELP");
}

public OnGiftSpawn(ent)
{
    new owner = pev(ent, pev_owner);

    SetupNotificationMessage(HUD_POS_NOTIFICATION_GIFT_SPAWN);
    show_dhudmessage(owner, "%L", LANG_PLAYER, "HWN_GIFT_SPAWN");
}

public OnGiftKilled(ent, bool:picked)
{
    if (!picked) {
        new owner = pev(ent, pev_owner);

        SetupNotificationMessage(HUD_POS_NOTIFICATION_GIFT_DISAPPEARED);
        show_dhudmessage(owner, "%L", LANG_PLAYER, "HWN_GIFT_DISAPPEARED");
    }
}

public OnGiftPicked(ent, id)
{
    static szName[128];
    get_user_name(id, szName, charsmax(szName));

    SetupNotificationMessage(HUD_POS_NOTIFICATION_GIFT_PICKED);
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_GIFT_FOUND", szName);
}

public OnSpellbookPicked(ent, id)
{
    UpdatePlayerSpell(id);

    SetupNotificationMessage(HUD_POS_NOTIFICATION_SPELL_PICKED);
    show_dhudmessage(id, "%L", LANG_PLAYER, "HWN_SPELLBOOK_PICKUP");
}

public OnResetHUD(id)
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    UTIL_Message_HideWeapon(id, GetHideWeaponFlags());
}

public OnMessageHideWeapon()
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | GetHideWeaponFlags());
}

/*--------------------------------[ Methods ]--------------------------------*/

UpdateTeamPoints()
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    new tPoints = Hwn_Collector_GetTeamPoints(1);
    new ctPoints = Hwn_Collector_GetTeamPoints(2);

    new teamPointsLimit = 0;
    if (g_cvarTeamPointsLimit) {
        teamPointsLimit = get_pcvar_num(g_cvarTeamPointsLimit);
    }

    set_hudmessage
    (
        HUD_COLOR_STATIC,
        HUD_POS_STATIC_TEAM_POINTS,
        .fxtime = 0.0,
        .holdtime = 1.0,
        .channel = -1
    );

    ShowSyncHudMsg(
        0, g_hudMsgTeamPoints,
        "%L^n%L: %i / %i^t^t|^t^t%L %i / %i",
        LANG_PLAYER, "HWN_TEAM_PUMPKIN_COLLECTED",
        LANG_PLAYER, "TERRORISTS", tPoints, teamPointsLimit,
        LANG_PLAYER, "CTS", ctPoints, teamPointsLimit
    );
}

UpdatePlayerPoints(id)
{
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    new playerPoints = Hwn_Collector_GetPlayerPoints(id);

    set_hudmessage
    (
        HUD_COLOR_STATIC,
        HUD_POS_STATIC_PLAYER_POINTS,
        .fxtime = 0.0,
        .holdtime = 1.0,
        .channel = -1
    );

    ShowSyncHudMsg(id, g_hudMsgPlayerPoints, "%L", LANG_PLAYER, "HWN_PLAYER_POINTS", playerPoints);
}

UpdatePlayerSpell(id)
{
    new amount;
    new playerSpell = Hwn_Spell_GetPlayerSpell(id, amount);

    if (playerSpell < 0) {
        return;
    }

    
    set_hudmessage
    (
        HUD_COLOR_NOTIFICATION,
        HUD_POS_STATIC_PLAYER_SPELL,
        .fxtime = 0.0,
        .holdtime = 1.0,
        .channel = -1
    );

    static szSpellName[128];
    Hwn_Spell_GetDictionaryKey(playerSpell, szSpellName, charsmax(szSpellName));

    if (szSpellName[0] == '^0') {
        Hwn_Spell_GetName(playerSpell, szSpellName, charsmax(szSpellName));
        ShowSyncHudMsg(id, g_hudMsgPlayerSpell, "%L: %s x%i", id, "HWN_SPELL", szSpellName, amount);
    } else {
        ShowSyncHudMsg(id, g_hudMsgPlayerSpell, "%L: %L x%i", id, "HWN_SPELL", id, szSpellName, amount);
    }
}

SetupNotificationMessage(Float:x = -1.0, Float:y = -1.0, const color[3] = {HUD_COLOR_NOTIFICATION}, Float:holdTime = 3.0)
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

GetHideWeaponFlags()
{
    new flags = 0;
    if (get_pcvar_num(g_cvarCollectorHideTimer) > 0) {
        flags |= HUD_HIDE_TIMER;
    }

    if (get_pcvar_num(g_cvarCollectorHideMoney) > 0) {
        flags |= HUD_HIDE_MONEY;
    }

    return flags;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public TaskUpdate()
{
    for (new id = 1; id <= g_maxPlayers; ++id) {
        if (!is_user_connected(id))    {
            continue;
        }

        if (!is_user_alive(id)) {
            continue;
        }

        UpdatePlayerPoints(id);
        UpdatePlayerSpell(id);
    }

    UpdateTeamPoints();
}