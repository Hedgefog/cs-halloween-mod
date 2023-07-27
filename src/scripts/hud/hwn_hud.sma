#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

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
#define HUD_POS_OBJECTIVE_INFO -1.0, 0.35

new Float:g_rgflPlayerNextObjectiveBlockMsg[MAX_PLAYERS + 1];

new g_hGamemodeCollector;

new g_iHudMsgTeamPoints;
new g_iHudMsgPlayerPoints;
new g_iHudMsgPlayerSpell;

new g_pCvarCollectoriTeamPointsLimit;
new g_pCvarCollectorRoundTime;

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    register_dictionary("hwn.txt");
    register_dictionary("miscstats.txt");

    g_iHudMsgTeamPoints = CreateHudSyncObj();
    g_iHudMsgPlayerPoints = CreateHudSyncObj();
    g_iHudMsgPlayerSpell = CreateHudSyncObj();

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

    register_event("ResetHUD", "OnResetHUD", "b");
    register_message(get_user_msgid("HideWeapon"), "Message_HideWeapon");

    CE_RegisterHook(CEFunction_Picked, "hwn_item_spellbook", "OnSpellbookPicked");
    CE_RegisterHook(CEFunction_Picked, "hwn_item_pumpkin", "OnPumpkinPicked");
    CE_RegisterHook(CEFunction_Picked, "hwn_item_pumpkin_big", "OnPumpkinPicked");

    g_hGamemodeCollector = Hwn_Gamemode_GetHandler("Collector");

    g_pCvarCollectoriTeamPointsLimit = get_cvar_pointer("hwn_collector_teampoints_limit");
    g_pCvarCollectorRoundTime = get_cvar_pointer("hwn_collector_roundtime");

    set_task(1.0, "Task_Update", _, _, _, "b");
}

/*--------------------------------[ Forwards ]--------------------------------*/

public Hwn_Collector_Fw_TeamPoints(iTeam) {
    UpdateTeamPoints();
}

public Hwn_Collector_Fw_PlayerPoints(pPlayer) {
    UpdatePlayerPoints(pPlayer);
}

public Hwn_Bosses_Fw_Winner(pPlayer, damage) {
    new szName[128];
    get_user_name(pPlayer, szName, charsmax(szName));
    client_print(0, print_chat, "%L", LANG_PLAYER, "HWN_DEFEAT_BOSS", szName);

    SetupNotificatiMessage(HUD_POS_NOTIFICATION_BOSS_REWARD);
    show_dhudmessage(pPlayer, "%L", LANG_PLAYER, "HWN_BOSS_REWARD");
}

public Hwn_Bosses_Fw_BossSpawn() {
    new iBoss = Hwn_Bosses_GetCurrent();

    SetupNotificatiMessage(HUD_POS_NOTIFICATION_BOSS_SPAWN);

    static szName[128];
    Hwn_Bosses_GetDictionaryKey(iBoss, szName, charsmax(szName));

    if (equal(szName, NULL_STRING)) {
        Hwn_Bosses_GetName(iBoss, szName, charsmax(szName));
        show_dhudmessage(0, "%s %L!", szName, LANG_PLAYER, "HWN_BOSS_SPAWN");
    } else {
        show_dhudmessage(0, "%L %L!", LANG_PLAYER, szName, LANG_PLAYER, "HWN_BOSS_SPAWN");
    }
}

public Hwn_Bosses_Fw_BossEscape() {
    new iBoss = Hwn_Bosses_GetCurrent();

    SetupNotificatiMessage(HUD_POS_NOTIFICATION_BOSS_ESCAPE);

    static szName[128];
    Hwn_Bosses_GetDictionaryKey(iBoss, szName, charsmax(szName));

    if (equal(szName, NULL_STRING)) {
        Hwn_Bosses_GetName(iBoss, szName, charsmax(szName));
        show_dhudmessage(0, "%s %L!", szName, LANG_PLAYER, "HWN_BOSS_ESCAPE");
    } else {
        show_dhudmessage(0, "%L %L!", LANG_PLAYER, szName, LANG_PLAYER, "HWN_BOSS_ESCAPE");
    }
}

public Hwn_Wof_Fw_Roll_Start() {
    SetupNotificatiMessage(HUD_POS_NOTIFICATION_WOF);
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_WOF_ROLL_STARTED");
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    SetupNotificatiMessage(HUD_POS_NOTIFICATION_WOF);

    static szSpellName[160];
    Hwn_Wof_Spell_GetDictionaryKey(iSpell, szSpellName, charsmax(szSpellName));

    if (equal(szSpellName, NULL_STRING)) {
        Hwn_Wof_Spell_GetName(iSpell, szSpellName, charsmax(szSpellName));
        show_dhudmessage(0, "%L %s!", LANG_PLAYER, "HWN_WOF_EFFECT_STARTED", szSpellName);
    } else {
        show_dhudmessage(0, "%L %L!", LANG_PLAYER, "HWN_WOF_EFFECT_STARTED", LANG_PLAYER, szSpellName);
    }
}

public Hwn_Collector_Fw_Overtime(iOvertime) {
    SetupNotificatiMessage(HUD_POS_NOTIFICATION_OVERTIME, .holdTime = float(iOvertime));
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_OVERTIME");
}

public Hwn_Collector_Fw_ObjectiveBlocked(pPlayer) {
    if (g_rgflPlayerNextObjectiveBlockMsg[pPlayer] < get_gametime()) {
        SetupNotificatiMessage(HUD_POS_OBJECTIVE_INFO, .holdTime = 3.0);
        show_dhudmessage(pPlayer, "%L", LANG_PLAYER, "HWN_OBJECTIVE_BLOCKED");
        g_rgflPlayerNextObjectiveBlockMsg[pPlayer] = get_gametime() + 10.0;
    }
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    SetupNotificatiMessage(HUD_POS_NOTIFICATION_MOD_MENU);
    show_dhudmessage(pPlayer, "%L", LANG_PLAYER, "HWN_MENU_HELP");

    g_rgflPlayerNextObjectiveBlockMsg[pPlayer] = 0.0;
}

public Hwn_Gifts_Fw_GiftSpawn(pPlayer) {
    SetupNotificatiMessage(HUD_POS_NOTIFICATION_GIFT_SPAWN);
    show_dhudmessage(pPlayer, "%L", LANG_PLAYER, "HWN_GIFT_SPAWN");
}

public Hwn_Gifts_Fw_GiftDisappear(pPlayer) {
    SetupNotificatiMessage(HUD_POS_NOTIFICATION_GIFT_DISAPPEARED);
    show_dhudmessage(pPlayer, "%L", LANG_PLAYER, "HWN_GIFT_DISAPPEARED");
}

public Hwn_Gifts_Fw_GiftPicked(pPlayer) {
    static szName[128];
    get_user_name(pPlayer, szName, charsmax(szName));

    SetupNotificatiMessage(HUD_POS_NOTIFICATION_GIFT_PICKED);
    show_dhudmessage(0, "%L", LANG_PLAYER, "HWN_GIFT_FOUND", szName);
}

public OnSpellbookPicked(pEntity, pPlayer) {
    UpdatePlayerSpell(pPlayer);

    SetupNotificatiMessage(HUD_POS_NOTIFICATION_SPELL_PICKED);
    show_dhudmessage(pPlayer, "%L", LANG_PLAYER, "HWN_SPELLBOOK_PICKUP");
}

public OnPumpkinPicked(pEntity, pPlayer) {
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    new iPoints = Hwn_Collector_GetPlayerPoints(pPlayer);
    new iBucketPoints = pev(pEntity, pev_iuser1) == -1 ? pev(pEntity, pev_iuser2) : 1;

    if (iPoints == iBucketPoints) {
        SetupNotificatiMessage(HUD_POS_NOTIFICATION_FIRST_PUMPKIN_PICKED);
        show_dhudmessage(pPlayer, "%L", LANG_PLAYER, "HWN_FIRST_PUMPKIN_PICKED");
    }
}

public OnResetHUD(pPlayer) {
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    UTIL_Message_HideWeapon(pPlayer, GetHideWeaponFlags());
}

public Message_HideWeapon() {
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | GetHideWeaponFlags());
}

/*--------------------------------[ Methods ]--------------------------------*/

UpdateTeamPoints() {
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    new iTPoints = Hwn_Collector_GetTeamPoints(1);
    new iCtPoints = Hwn_Collector_GetTeamPoints(2);

    new iTeamPointsLimit = 0;
    if (g_pCvarCollectoriTeamPointsLimit) {
        iTeamPointsLimit = get_pcvar_num(g_pCvarCollectoriTeamPointsLimit);
    }

    set_hudmessage(HUD_COLOR_STATIC, HUD_POS_STATIC_TEAM_POINTS, .fxtime = 0.0, .holdtime = 1.0, .channel = -1);

    ShowSyncHudMsg(
        0, g_iHudMsgTeamPoints,
        "%L^n%L: %i / %i^t^t|^t^t%L %i / %i",
        LANG_PLAYER, "HWN_TEAM_PUMPKIN_COLLECTED",
        LANG_PLAYER, "TERRORISTS", iTPoints, iTeamPointsLimit,
        LANG_PLAYER, "CTS", iCtPoints, iTeamPointsLimit
    );
}

UpdatePlayerPoints(pPlayer) {
    if (Hwn_Gamemode_GetCurrent() != g_hGamemodeCollector) {
        return;
    }

    new iPoints = Hwn_Collector_GetPlayerPoints(pPlayer);

    set_hudmessage(HUD_COLOR_STATIC, HUD_POS_STATIC_PLAYER_POINTS, .fxtime = 0.0, .holdtime = 1.0, .channel = -1);

    ShowSyncHudMsg(pPlayer, g_iHudMsgPlayerPoints, "%L", LANG_PLAYER, "HWN_PLAYER_POINTS", iPoints);
}

UpdatePlayerSpell(pPlayer) {
    new iAmount = 0;
    new iSpell = Hwn_Spell_GetPlayerSpell(pPlayer, iAmount);
    if (iSpell < 0) {
        return;
    }

    set_hudmessage(HUD_COLOR_NOTIFICATION, HUD_POS_STATIC_PLAYER_SPELL, .fxtime = 0.0, .holdtime = 1.0, .channel = -1);

    static szSpellName[128];
    Hwn_Spell_GetDictionaryKey(iSpell, szSpellName, charsmax(szSpellName));

    if (equal(szSpellName, NULL_STRING)) {
        Hwn_Spell_GetName(iSpell, szSpellName, charsmax(szSpellName));
        ShowSyncHudMsg(pPlayer, g_iHudMsgPlayerSpell, "%L: %s x%i", pPlayer, "HWN_SPELL", szSpellName, iAmount);
    } else {
        ShowSyncHudMsg(pPlayer, g_iHudMsgPlayerSpell, "%L: %L x%i", pPlayer, "HWN_SPELL", pPlayer, szSpellName, iAmount);
    }
}

SetupNotificatiMessage(Float:iPosX = -1.0, Float:iPosY = -1.0, const rgiColor[3] = {HUD_COLOR_NOTIFICATION}, Float:holdTime = 3.0) {
    set_dhudmessage(rgiColor[0], rgiColor[1], rgiColor[2], iPosX, iPosY, .fxtime = 0.0, .holdtime = holdTime, .fadeintime = 0.1, .fadeouttime = 1.5);
}

GetHideWeaponFlags() {
    new iFlags = 0;

    if (Hwn_Gamemode_GetCurrent() == g_hGamemodeCollector) {
        if (get_pcvar_float(g_pCvarCollectorRoundTime) <= 0.0) {
            iFlags |= HUD_HIDE_TIMER;
        }
    }

    return iFlags;
}

/*--------------------------------[ Tasks ]--------------------------------*/

public Task_Update() {
    for (new pPlayer = 1; pPlayer <= MaxClients; ++pPlayer) {
        if (!is_user_connected(pPlayer)) {
            continue;
        }

        if (!is_user_alive(pPlayer)) {
            continue;
        }

        UpdatePlayerPoints(pPlayer);
        UpdatePlayerSpell(pPlayer);
    }

    UpdateTeamPoints();
}
