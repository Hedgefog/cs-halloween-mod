#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <screenfade_util>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Blink Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectRadius = 64.0;
new const EffectColor[3] = {0, 0, 255};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_teleport.wav";

new g_szSprSpellBall[] = "sprites/enter1.spr";

new g_hSpell;

new g_hCeSpellball;

public plugin_precache()
{
    precache_model(g_szSprSpellBall);
    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register("Blink", Hwn_SpellFlag_Throwable, "OnCast");
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, EffectColor, _, g_szSprSpellBall, _, 0.75, 10.0);

    if (!ent) {
        return PLUGIN_HANDLED;
    }

    set_pev(ent, pev_iuser1, g_hSpell);

    emit_sound(id, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

public OnTouch(ent, target)
{
    if (!pev_valid(ent)) {
        return;
    }

    if (g_hCeSpellball != CE_GetHandlerByEntity(ent)) {
        return;
    }

    if (pev(ent, pev_iuser1) != g_hSpell) {
        return;
    }

    if (target == pev(ent, pev_owner)) {
        return;
    }

    CE_Kill(ent);
}

public OnSpellballKilled(ent)
{
    new spellIdx = pev(ent, pev_iuser1);

    if (spellIdx != g_hSpell) {
        return;
    }

    Detonate(ent);
}

/*--------------------------------[ Methods ]--------------------------------*/

Detonate(ent)
{
    new owner = pev(ent, pev_owner);

    if (!is_user_alive(owner)) {
        return;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    new hull = (pev(ent, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
    if (UTIL_FindPlaceToTeleport(owner, vOrigin, vOrigin, hull)) {
        engfunc(EngFunc_SetOrigin, owner, vOrigin);
        UTIL_ScreenFade(owner, {0, 0, 255}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
        BlinkEffect(owner);
    }
}

BlinkEffect(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    emit_sound(ent, CHAN_STATIC , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    UTIL_Message_Dlight(vOrigin, 32, EffectColor, 5, 64);
    UTIL_Message_ParticleBurst(vOrigin, 32, 210, 1);
}