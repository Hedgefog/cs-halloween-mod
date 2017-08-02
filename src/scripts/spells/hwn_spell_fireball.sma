#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_player_burn>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Hwn] Fireball Spell"
#define AUTHOR "Hedgehog Fog"

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"

const Float:FireballDamage = 30.0;

const Float:EffectRadius = 128.0;
new const EffectColor[3] = {255, 127, 47};

new const g_szSndDetonate[] = "hwn/spells/spell_fireball_impact.wav";

new g_sprSpellball;
new g_sprSpellballTrace;

new g_hSpell;

new g_hCeSpellball;

public plugin_precache()
{
    g_sprSpellball = precache_model("sprites/rjet1.spr");
    g_sprSpellballTrace = precache_model("sprites/xbeam4.spr");

    precache_sound(g_szSndDetonate);
}

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    
    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "OnTouch", .Post = 1);
    
    g_hSpell = Hwn_Spell_Register("Fireball", "OnCast");

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);
    
    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "OnSpellballKilled");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public OnCast(id)
{
    static Float:vOrigin[3];
    pev(id, pev_origin, vOrigin);
    
    new ent = CE_Create(SPELLBALL_ENTITY_CLASSNAME, vOrigin);

    if (!ent) {
        return;
    }

    static Float:vVelocity[3];
    velocity_by_aim(id, 512, vVelocity);
    
    set_pev(ent, pev_iuser1, g_hSpell);
    set_pev(ent, pev_owner, id);
    set_pev(ent, pev_velocity, vVelocity);
    set_pev(ent, pev_modelindex, g_sprSpellball);
    set_pev(ent, pev_scale, 0.25);
    set_pev(ent, pev_rendercolor, EffectColor);
    
    dllfunc(DLLFunc_Spawn, ent);
    
    set_pev(ent, pev_movetype, MOVETYPE_FLYMISSILE);
}

public OnTouch(ent, target)
{
	if (!pev_valid(ent)) {
		return;
	}

	if (g_hCeSpellball != CE_GetHandlerByEntity(ent)) {
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
    new team = get_pdata_int(owner, m_iTeam);
    
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    
    new target;
    new prevTarget;
    while ((target = engfunc(EngFunc_FindEntityInSphere, target, vOrigin, EffectRadius)) != 0)
    {
    	if (prevTarget >= target) {
			break; // infinite loop fix
		}

        prevTarget = target;

        if (pev(target, pev_takedamage) == DAMAGE_NO) {
            continue;
        }
        
        if (target == owner) {
            continue;
        }
        
        static Float:vTargetOrigin[3];
        pev(target, pev_origin, vTargetOrigin);
        
        new Float:fDamage = UTIL_CalculateRadiusDamage(vOrigin, vTargetOrigin, EffectRadius, FireballDamage);
        
        if (UTIL_IsPlayer(target)) {
            if (team == get_pdata_int(target, m_iTeam)) {
                continue;
            }
        
            static Float:vDirection[3];
            xs_vec_sub(vOrigin, vTargetOrigin, vDirection);
            xs_vec_normalize(vDirection, vDirection);
            xs_vec_mul_scalar(vDirection, -512.0, vDirection);
            
            static Float:vTargetVelocity[3];
            pev(target, pev_velocity, vTargetVelocity);
            xs_vec_add(vTargetVelocity, vDirection, vTargetVelocity);
            set_pev(target, pev_velocity, vTargetVelocity);

            UTIL_CS_DamagePlayer(target, fDamage, DMG_BURN, owner, 0);
            burn_player(target, owner, 15);
        } else {
            ExecuteHamB(Ham_TakeDamage, target, 0, owner, fDamage, DMG_BURN);
        }
    }
    
    DetonateEffect(ent, vOrigin);
}

DetonateEffect(ent, const Float:vOrigin[3])
{
    UTIL_SpellballDetonateEffect(
      .modelindex = g_sprSpellballTrace,
      .vOrigin = vOrigin,
      .fRadius = EffectRadius,
      .color = EffectColor
    );

    emit_sound(ent, CHAN_BODY, g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}