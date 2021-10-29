#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Bots Spells"
#define AUTHOR "Hedgehog Fog"

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#define SPELL_CHECK_DELAY 0.5
#define SPELL_CAST_CHANCE 50.0
#define SPELL_CHECK_RADIUS 1024.0
#define SPELL_CHECK_DISTANCE 2048.0
#define SPELL_CAST_DELAY 10.0

enum SpellType
{
    SpellType_ThrowableEnemy = 0,
    SpellType_RadiusEnemy,
    SpellType_Applicable,
    SpellType_Heal
};

new g_cvarEnabled;
new Trie:g_spellTypes;
new Float:g_lastSpellCast[MAX_PLAYERS + 1] = { 0.0, ... };

new g_maxPlayers;

public plugin_precache()
{
    g_cvarEnabled = register_cvar("hwn_bots_spells", "1");
}

public plugin_init()
{
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

    g_maxPlayers = get_maxplayers();
}

public plugin_end()
{
    TrieDestroy(g_spellTypes);
}

public client_connect(id)
{
    if (get_pcvar_num(g_cvarEnabled) <= 0) {
        return;
    }

    if (!is_user_bot(id)) {
        return;
    }

    set_task(SPELL_CHECK_DELAY, "TaskThink", id, _, _, "b");
}

#if AMXX_VERSION_NUM < 183
    public client_disconnect(id)
#else
    public client_disconnected(id)
#endif
{
    remove_task(id);
}

public TaskThink(id)
{
    if (get_pcvar_num(g_cvarEnabled) <= 0) {
        return;
    }

    if (!is_user_alive(id)) {
        return;
    }

    new spellIdx = Hwn_Spell_GetPlayerSpell(id);
    if (spellIdx == -1) {
        return;
    }

    new Float:fLastCast = g_lastSpellCast[id];
    if (get_gametime() - fLastCast < SPELL_CAST_DELAY) {
        return;
    }

    if (!RandomCheck(SPELL_CAST_CHANCE)) {
        return;
    }

    if (!CheckSpellCast(id)) {
        return;
    }

    Hwn_Spell_CastPlayerSpell(id);
    g_lastSpellCast[id] = get_gametime();
}

bool:CheckSpellCast(id)
{
    new spellIdx = Hwn_Spell_GetPlayerSpell(id);
    
    static szSpellName[32];
    Hwn_Spell_GetName(spellIdx, szSpellName, charsmax(szSpellName));
    
    static SpellType:spellType;
    TrieGetCell(g_spellTypes, szSpellName, spellType);

    switch (spellType)
    {
        case SpellType_ThrowableEnemy:
            return IsLookingAroundEnemy(id);
        case SpellType_RadiusEnemy:
            return CheckEnemiesNearby(id, SPELL_CHECK_RADIUS);
        case SpellType_Heal: {
            static Float:fHealth;
            pev(id, pev_health, fHealth);
            return RandomCheck(100.0 - fHealth);
        }
        case SpellType_Applicable:
            return true;
        default:
            return IsLookingAroundEnemy(id);
    }

    return false;
}

bool:IsLookingAroundEnemy(id)
{
    static Float:vOrigin[3];
    UTIL_GetViewOrigin(id, vOrigin);

    static Float:vTarget[3];
    velocity_by_aim(id, floatround(SPELL_CHECK_DISTANCE), vTarget);
    xs_vec_add(vOrigin, vTarget, vTarget);

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, vOrigin, vTarget, DONT_IGNORE_MONSTERS, id, trace);

    static Float:vEndPos[3];
    get_tr2(trace, TR_vecEndPos, vEndPos);

    free_tr2(trace);

    return CountEnemiesNearbyOrigin(id, vEndPos, 64.0) > 0;
}

bool:CheckEnemiesNearby(id, Float:fRadius)
{
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);

    new enemyCount = CountEnemiesNearbyOrigin(id, vOrigin, fRadius);
    new Float:fChance = enemyCount * (100.0 / g_maxPlayers);

    return RandomCheck(fChance);
}

CountEnemiesNearbyOrigin(id, const Float:vOrigin[3], Float:fRadius)
{
    new team = UTIL_GetPlayerTeam(id);

    new count = 0;
    for (new target = 1; target <= g_maxPlayers; ++target) {
        if (!is_user_connected(target)) {
            continue;
        }

        if (!is_user_alive(target)) {
            continue;
        }

        if (team == UTIL_GetPlayerTeam(target)) {
            continue;
        }

        static Float:vTargetOrigin[3];
        pev(target, pev_origin, vTargetOrigin);

        if (get_distance_f(vOrigin, vTargetOrigin) > fRadius) {
            continue;
        }

        if (!UTIL_IsPointVisible(vOrigin, vTargetOrigin)) {
            continue;
        }

        count++;
    }

    return count;
}

bool:RandomCheck(Float:fChance)
{
    return fChance > 0 && fChance >= random_float(0.0, 100.0);
}
