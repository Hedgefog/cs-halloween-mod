#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <screenfade_util>

#include <hwn>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Blink Spell"
#define AUTHOR "Hedgehog Fog"

const Float:EffectRadius = 64.0;
new const EffectColor[3] = {0, 0, 255};

new const g_szSndCast[] = "hwn/spells/spell_fireball_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_teleport.wav";

new g_sprSpellball;
new g_sprSpellballTrace;

new g_hSpell;

new g_hCeSpellball;

public plugin_precache()
{
    g_sprSpellball = precache_model("sprites/xspark1.spr");
    g_sprSpellballTrace = precache_model("sprites/xbeam4.spr");

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
        
    g_hSpell = Hwn_Spell_Register("Blink", "OnCast");
    
    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);
    
    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    new ent = UTIL_HwnSpawnPlayerSpellball(id, g_sprSpellball, EffectColor);

    if (!ent) {
        return PLUGIN_HANDLED;
    }

    set_pev(ent, pev_iuser1, g_hSpell);

    emit_sound(id, CHAN_BODY, g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

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

    ExecuteHamB(Ham_Killed, ent, 0, 0);
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
    
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    static Float:vVelocity[3];
    pev(ent, pev_velocity, vVelocity);

    static Float:vMins[3];
    pev(owner, pev_mins, vMins);        
    
    static Float:vAngles[3];
    vector_to_angle(vVelocity, vAngles);
    
    static Float:vAngleForward[3];            
    angle_vector(vAngles, ANGLEVECTOR_FORWARD, vAngleForward);
    xs_vec_mul_scalar(vAngleForward, vMins[1]-16.0, vAngleForward);
    xs_vec_add(vAngleForward, vOrigin, vOrigin);
    
    static Float:vAngleUp[3];
    angle_vector(vAngles, ANGLEVECTOR_UP, vAngleUp);
    xs_vec_mul_scalar(vAngleUp, -(vMins[2]-16.0), vAngleUp);
    xs_vec_add(vAngleUp, vOrigin, vOrigin);
    
    {
        new hull = (pev(owner, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;            
    
        new trace = 0;
        engfunc(EngFunc_TraceHull, vOrigin, vOrigin, 0, hull, 0, trace);
        
        if (get_tr2(trace, TR_InOpen)) {
            engfunc(EngFunc_SetOrigin, owner, vOrigin);
            UTIL_ScreenFade(owner, {0, 0, 255}, 1.0, 0.0, 128, FFADE_IN, .bExternal = true);
        }
        
        free_tr2(trace);
    }
    
    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    DetonateEffect(ent, vOrigin);
}

DetonateEffect(ent, const Float:vOrigin[3])
{
    UTIL_HwnSpellDetonateEffect(
      .modelindex = g_sprSpellballTrace,
      .vOrigin = vOrigin,
      .fRadius = EffectRadius,
      .color = EffectColor
    );

    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}