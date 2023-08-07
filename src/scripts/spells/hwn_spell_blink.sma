#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Blink Spell"
#define AUTHOR "Hedgehog Fog"

const Float:SpellballDamage = 500.0;
const SpellballSpeed = 600;

const Float:EffectRadius = 48.0;
new const EffectColor[3] = {0, 0, 255};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_teleport.wav";

new g_szSprSpellBall[] = "sprites/enter1.spr";

new g_hSpell;

public plugin_precache() {
    precache_model(g_szSprSpellBall);
    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register("Blink", Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage, "Cast");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn_Post", .Post = 1);

    CE_RegisterHook(CEFunction_Kill, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Kill");
    CE_RegisterHook(CEFunction_Touch, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Touch");
    CE_RegisterHook(CEFunction_Think, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Think");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public Cast(pPlayer) {
    new pEntity = UTIL_HwnSpawnPlayerSpellball(pPlayer, EffectColor, SpellballSpeed, g_szSprSpellBall, _, 0.75, 10.0);

    if (!pEntity) {
        return PLUGIN_HANDLED;
    }

    set_pev(pEntity, pev_iuser1, g_hSpell);

    emit_sound(pPlayer, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

public HamHook_Player_Spawn_Post(pPlayer) {
    if (!is_user_alive(pPlayer)) {
        return;
    }

    new pTarget = -1;
    while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "classname", SPELLBALL_ENTITY_CLASSNAME)) != 0) {
        if (pev(pTarget, pev_iuser1) != g_hSpell) {
            continue;
        }

        set_pev(pTarget, pev_owner, 0);
    }
}

/*--------------------------------[ Methods ]--------------------------------*/

@SpellBall_Kill(this) {
    if (pev(this, pev_iuser1) != g_hSpell) {
        return;
    }

    new pOwner = pev(this, pev_owner);
    if (!pOwner) {
        return;
    }

    if (!is_user_alive(pOwner)) {
        return;
    }

    static Float:vecOwnerOrigin[3];
    pev(pOwner, pev_origin, vecOwnerOrigin);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    if (get_distance_f(vecOwnerOrigin, vecOrigin) > EffectRadius) {
        new iHull = (pev(this, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
        UTIL_FindPlaceToTeleport(pOwner, vecOrigin, vecOrigin, iHull, IGNORE_MONSTERS);
        engfunc(EngFunc_SetOrigin, pOwner, vecOrigin);
    }

    UTIL_ScreenFade(pOwner, {0, 0, 255}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
    @SpellBall_BlinkEffect(pOwner);

    new pTarget = 0;
    while ((pTarget = UTIL_FindEntityNearby(pTarget, vecOrigin, EffectRadius)) > 0) {
        if (pOwner == pTarget) {
            continue;
        }

        if (pev(pTarget, pev_deadflag) != DEAD_NO) {
            continue;
        }

        if (pev(pTarget, pev_takedamage) == DAMAGE_NO) {
            continue;
        }

        ExecuteHamB(Ham_TakeDamage, pTarget, this, pOwner, SpellballDamage, DMG_ALWAYSGIB);
    }

    if (UTIL_IsStuck(pOwner)) {
        ExecuteHamB(Ham_TakeDamage, pOwner, 0, 0, SpellballDamage, DMG_ALWAYSGIB);
    }
}

@SpellBall_Touch(this, pToucher) {
    if (pev(this, pev_iuser1) != g_hSpell) {
        return;
    }

    if (pToucher == pev(this, pev_owner)) {
        return;
    }

    CE_Kill(this);
}

@SpellBall_Think(this) {
    if (pev(this, pev_iuser1) != g_hSpell) {
        return;
    }

    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    if (!xs_vec_len(vecVelocity)) {
        CE_Kill(this);
    }
}

@SpellBall_BlinkEffect(this) {
    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    emit_sound(this, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    UTIL_Message_Dlight(vecOrigin, 32, EffectColor, 5, 64);
    UTIL_Message_ParticleBurst(vecOrigin, 32, 210, 1);
}
