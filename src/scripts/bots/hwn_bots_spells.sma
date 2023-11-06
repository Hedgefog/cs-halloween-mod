#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_rounds>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Bots Spells"
#define AUTHOR "Hedgehog Fog"

#define SPELL_CHECK_DELAY 0.5
#define SPELL_CAST_CHANCE 50.0
#define SPELL_CHECK_RADIUS 1024.0
#define SPELL_CHECK_DISTANCE 2048.0
#define SPELL_CAST_DELAY 10.0

new g_pCvarEnabled;

new Float:g_flNextSpellCast[MAX_PLAYERS + 1];

public plugin_precache() {
    g_pCvarEnabled = register_cvar("hwn_bots_spells", "1");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public client_connect(pPlayer) {
    if (get_pcvar_num(g_pCvarEnabled) <= 0) return;
    if (!is_user_bot(pPlayer)) return;

    set_task(SPELL_CHECK_DELAY, "@Bot_Think", pPlayer, _, _, "b");
}

public client_disconnected(pPlayer) {
    remove_task(pPlayer);
}

@Bot_Think(this) {
    if (get_pcvar_num(g_pCvarEnabled) <= 0) return;
    if (!is_user_alive(this)) return;

    static iSpell; iSpell = Hwn_Spell_GetPlayerSpell(this);
    if (iSpell == -1) return;

    static Float:flGameTime; flGameTime = get_gametime();
    if (g_flNextSpellCast[this] <= flGameTime && @Bot_ShouldCastSpell(this)) {
        Hwn_Spell_CastPlayerSpell(this);
        g_flNextSpellCast[this] = flGameTime + SPELL_CAST_DELAY;
    }
}

bool:@Bot_ShouldCastSpell(this) {
    if (!Round_IsRoundStarted()) return false;
    if (!RandomCheck(SPELL_CAST_CHANCE)) return false;

    static iSpell; iSpell = Hwn_Spell_GetPlayerSpell(this);
    static szSpellName[32]; Hwn_Spell_GetName(iSpell, szSpellName, charsmax(szSpellName));
    static Hwn_SpellFlags:iSpellFlags; iSpellFlags = Hwn_Spell_GetFlags(iSpell);

    if (iSpellFlags & Hwn_SpellFlag_Damage) {
        if (iSpellFlags & Hwn_SpellFlag_Throwable) {
            return @Bot_IsLookingAtEnemy(this);
        } else {
            return @Bot_HasEnemiesNearby(this, SPELL_CHECK_RADIUS);
        }
    }

    if (iSpellFlags & Hwn_SpellFlag_Heal) {
        static Float:flMaxHealth; pev(this, pev_max_health, flMaxHealth);
        static Float:flHealth; pev(this, pev_health, flHealth);
        return RandomCheck(flMaxHealth - flHealth);
    }

    if (iSpellFlags & Hwn_SpellFlag_Protection) {
        return @Bot_HasEnemiesNearby(this, SPELL_CHECK_RADIUS);
    }

    if (iSpellFlags & Hwn_SpellFlag_Applicable) return false;
    if (iSpellFlags & Hwn_SpellFlag_Ability) {
        return true;
    }

    return @Bot_IsLookingAtEnemy(this);
}

bool:@Bot_IsLookingAtEnemy(this) {
    static Float:vecOrigin[3];
    UTIL_GetViewOrigin(this, vecOrigin);

    static Float:vecTarget[3];
    velocity_by_aim(this, floatround(SPELL_CHECK_DISTANCE), vecTarget);
    xs_vec_add(vecOrigin, vecTarget, vecTarget);

    new pTrace = create_tr2();
    engfunc(EngFunc_TraceLine, vecOrigin, vecTarget, DONT_IGNORE_MONSTERS, this, pTrace);

    static Float:vecEndPos[3];
    get_tr2(pTrace, TR_vecEndPos, vecEndPos);

    free_tr2(pTrace);

    return @Bot_CountEnemiesNearbyOrigin(this, vecEndPos, 64.0) > 0;
}

bool:@Bot_HasEnemiesNearby(this, Float:flRadius) {
    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static iEnemiesNum; iEnemiesNum = @Bot_CountEnemiesNearbyOrigin(this, vecOrigin, flRadius);
    static Float:flChance; flChance = (float(iEnemiesNum) / MaxClients) * 100.0;

    return RandomCheck(flChance);
}

@Bot_CountEnemiesNearbyOrigin(this, const Float:vecOrigin[3], Float:flRadius) {
    new iNum = 0;

    new iTeam = get_member(this, m_iTeam);

    for (new pTarget = 1; pTarget <= MaxClients; ++pTarget) {
        if (!is_user_connected(pTarget)) continue;
        if (!is_user_alive(pTarget)) continue;
        if (iTeam == get_member(pTarget, m_iTeam)) continue;

        static Float:vecTargetOrigin[3]; pev(pTarget, pev_origin, vecTargetOrigin);
        if (get_distance_f(vecOrigin, vecTargetOrigin) > flRadius) continue;
        if (!UTIL_IsPointVisible(vecOrigin, vecTargetOrigin)) continue;

        iNum++;
    }

    return iNum;
}

bool:RandomCheck(Float:flChance) {
    return flChance > 0 && flChance >= random_float(0.0, 100.0);
}
