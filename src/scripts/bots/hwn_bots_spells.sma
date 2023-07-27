#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Bots Spells"
#define AUTHOR "Hedgehog Fog"

#define SPELL_CHECK_DELAY 0.5
#define SPELL_CAST_CHANCE 50.0
#define SPELL_CHECK_RADIUS 1024.0
#define SPELL_CHECK_DISTANCE 2048.0
#define SPELL_CAST_DELAY 10.0

enum SpellType {
    SpellType_ThrowableEnemy = 0,
    SpellType_RadiusEnemy,
    SpellType_Applicable,
    SpellType_Heal
};

new g_pCvarEnabled;
new Trie:g_spellTypes;
new Float:g_lastSpellCast[MAX_PLAYERS + 1];

public plugin_precache() {
    g_pCvarEnabled = register_cvar("hwn_bots_spells", "1");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    g_spellTypes = TrieCreate();

    TrieSetCell(g_spellTypes, "Fireball", SpellType_ThrowableEnemy);
    TrieSetCell(g_spellTypes, "Lightning", SpellType_ThrowableEnemy);
    TrieSetCell(g_spellTypes, "Blink", SpellType_ThrowableEnemy);
    TrieSetCell(g_spellTypes, "Invisibility", SpellType_RadiusEnemy);
    TrieSetCell(g_spellTypes, "Crits", SpellType_RadiusEnemy);
    TrieSetCell(g_spellTypes, "Moon Jump", SpellType_Applicable);
    TrieSetCell(g_spellTypes, "Power Up", SpellType_Applicable);
    TrieSetCell(g_spellTypes, "Overheal", SpellType_Heal);

}

public plugin_end() {
    TrieDestroy(g_spellTypes);
}

public client_connect(pPlayer) {
    if (get_pcvar_num(g_pCvarEnabled) <= 0) {
        return;
    }

    if (!is_user_bot(pPlayer)) {
        return;
    }

    set_task(SPELL_CHECK_DELAY, "Task_Think", pPlayer, _, _, "b");
}

public client_disconnected(pPlayer) {
    remove_task(pPlayer);
}

public Task_Think(pPlayer) {
    if (get_pcvar_num(g_pCvarEnabled) <= 0) {
        return;
    }

    if (!is_user_alive(pPlayer)) {
        return;
    }

    new iSpell = Hwn_Spell_GetPlayerSpell(pPlayer);
    if (iSpell == -1) {
        return;
    }

    new Float:flLastCast = g_lastSpellCast[pPlayer];
    if (get_gametime() - flLastCast < SPELL_CAST_DELAY) {
        return;
    }

    if (!RandomCheck(SPELL_CAST_CHANCE)) {
        return;
    }

    if (!CheckSpellCast(pPlayer)) {
        return;
    }

    Hwn_Spell_CastPlayerSpell(pPlayer);
    g_lastSpellCast[pPlayer] = get_gametime();
}

bool:CheckSpellCast(pPlayer) {
    new iSpell = Hwn_Spell_GetPlayerSpell(pPlayer);
    
    static szSpellName[32];
    Hwn_Spell_GetName(iSpell, szSpellName, charsmax(szSpellName));
    
    static SpellType:spellType;
    TrieGetCell(g_spellTypes, szSpellName, spellType);

    switch (spellType)
    {
        case SpellType_ThrowableEnemy:
            return IsLookingAroundEnemy(pPlayer);
        case SpellType_RadiusEnemy:
            return CheckEnemiesNearby(pPlayer, SPELL_CHECK_RADIUS);
        case SpellType_Heal: {
            static Float:flHealth;
            pev(pPlayer, pev_health, flHealth);
            return RandomCheck(100.0 - flHealth);
        }
        case SpellType_Applicable:
            return true;
        default:
            return IsLookingAroundEnemy(pPlayer);
    }

    return false;
}

bool:IsLookingAroundEnemy(pPlayer) {
    static Float:vecOrigin[3];
    UTIL_GetViewOrigin(pPlayer, vecOrigin);

    static Float:vecTarget[3];
    velocity_by_aim(pPlayer, floatround(SPELL_CHECK_DISTANCE), vecTarget);
    xs_vec_add(vecOrigin, vecTarget, vecTarget);

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, pPlayer, pTrace);

    static Float:vecEndPos[3];
    get_tr2(pTrace, TR_vecEndPos, vecEndPos);

    free_tr2(pTrace);

    return CountEnemiesNearbyOrigin(pPlayer, vecEndPos, 64.0) > 0;
}

bool:CheckEnemiesNearby(pPlayer, Float:flRadius) {
    static Float:vecOrigin[3];
    pev(pPlayer, pev_origin, vecOrigin);

    new iEnemiesNum = CountEnemiesNearbyOrigin(pPlayer, vecOrigin, flRadius);
    new Float:flChance = (float(iEnemiesNum) / MaxClients) * 100.0;

    return RandomCheck(flChance);
}

CountEnemiesNearbyOrigin(pPlayer, const Float:vecOrigin[3], Float:flRadius) {
    new iTeam = get_member(pPlayer, m_iTeam);

    new iNum = 0;
    for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
        if (!is_user_connected(pTarget)) {
            continue;
        }

        if (!is_user_alive(pTarget)) {
            continue;
        }

        if (iTeam == get_member(pTarget, m_iTeam)) {
            continue;
        }

        static Float:vecTargetOrigin[3];
        pev(pTarget, pev_origin, vecTargetOrigin);

        if (get_distance_f(vecOrigin, vecTargetOrigin) > flRadius) {
            continue;
        }

        if (!UTIL_IsPointVisible(vecOrigin, vecTargetOrigin)) {
            continue;
        }

        iNum++;
    }

    return iNum;
}

bool:RandomCheck(Float:flChance) {
    return flChance > 0 && flChance >= random_float(0.0, 100.0);
}
