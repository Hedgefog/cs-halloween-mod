#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <hwn>
#include <hwn_utils>

#include <api_particles>
#include <api_custom_entities>

#define PLUGIN "[Custom Entity] Hwn Item Spellbook"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_spellbook"

#define m_iSpell "iSpell"
#define m_iAmount "iAmount"
#define m_pParticle "pParticle"

new const g_szSndSpawn[] = "hwn/items/spellbook/spellbook_spawn.wav";
new const g_szSndPickup[] = "hwn/spells/spell_pickup.wav";
new const g_szSndPickupRare[] = "hwn/spells/spell_pickup_rare.wav";

new bool:g_bIsPrecaching;

new g_particlesEnabled = false;

new g_pCvarMaxSpellsNum;
new g_pCvarMaxRareSpellsNum;
new g_pCvarRareChance;

new g_iSparkleModelIndex;
new g_iSparklePurpleModelIndex;
new g_iSmokeModelIndex;

public plugin_precache() {
    g_bIsPrecaching = true;

    g_iSparkleModelIndex = precache_model("sprites/muz2.spr");
    g_iSparklePurpleModelIndex = precache_model("sprites/muz7.spr");
    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke.spr");

    precache_sound(g_szSndSpawn);
    precache_sound(g_szSndPickup);
    precache_sound(g_szSndPickupRare);

    CE_Register(
        ENTITY_NAME,
        .szModel = "models/hwn/items/spellbook_v2.mdl",
        .vecMins = Float:{-16.0, -12.0, 0.0},
        .vecMaxs = Float:{16.0, 12.0, 24.0},
        .flLifeTime = HWN_NPC_LIFE_TIME,
        .flRespawnTime = HWN_ITEM_RESPAWN_TIME,
        .iPreset = CEPreset_Item
    );

    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "@Entity_Pickup");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");

    g_pCvarMaxSpellsNum = register_cvar("hwn_spellbook_max_spell_count", "3");
    g_pCvarMaxRareSpellsNum = register_cvar("hwn_spellbook_max_rare_spell_count", "1");
    g_pCvarRareChance = register_cvar("hwn_spellbook_rare_chance", "30");
}

public plugin_init() {
    g_bIsPrecaching = false;

    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public Hwn_Fw_ConfigLoaded() {
    g_particlesEnabled = get_cvar_num("hwn_enable_particles");
}

@Entity_Spawned(this) {
    @Entity_RemoveParticles(this);

    if (!CE_HasMember(this, m_iSpell)) {
        CE_SetMember(this, m_iSpell, GetRandomSpell());
    }

    new iSpell = CE_GetMember(this, m_iSpell);
    if (iSpell == -1) {
        CE_Remove(this);
        return;
    }

    new bool:bIsRare = !!(Hwn_Spell_GetFlags(iSpell) & Hwn_SpellFlag_Rare);

    new iMaxSpellsNum = bIsRare ? get_pcvar_num(g_pCvarMaxRareSpellsNum) : get_pcvar_num(g_pCvarMaxSpellsNum);
    if (iMaxSpellsNum <= 0) {
        CE_Remove(this);
        return;
    }

    if (!CE_HasMember(this, m_iAmount)) {
        CE_SetMember(this, m_iAmount, random(iMaxSpellsNum) + 1);
    }

    set_pev(this, pev_framerate, 1.0);

    @Entity_AppearEffect(this);
    emit_sound(this, CHAN_BODY, g_szSndSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    @Entity_CreateParticles(this);

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Remove(this) {
    @Entity_RemoveParticles(this);
}

@Entity_Killed(this) {
    CE_DeleteMember(this, m_iSpell);
    CE_DeleteMember(this, m_iAmount);
    @Entity_RemoveParticles(this);
}

@Entity_Pickup(this, pPlayer) {
    if (Hwn_Spell_GetPlayerSpell(pPlayer) != -1) return PLUGIN_CONTINUE;

    new iSpell = CE_GetMember(this, m_iSpell);
    new bool:bIsRare = !!(Hwn_Spell_GetFlags(iSpell) & Hwn_SpellFlag_Rare);

    Hwn_Spell_SetPlayerSpell(pPlayer, iSpell, CE_GetMember(this, m_iAmount));

    emit_sound(this, CHAN_BODY, bIsRare ? g_szSndPickupRare : g_szSndPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_HANDLED;
}

@Entity_Think(this) {
    if (pev(this, pev_deadflag) != DEAD_NO) return;

    if (g_particlesEnabled) {
        @Entity_UpdateParticles(this, true);
    } else {
        @Entity_RemoveParticles(this);
    }

    set_pev(this, pev_nextthink, get_gametime() + 1.0);
}

@Entity_AppearEffect(this) {
    new iSpell = CE_GetMember(this, m_iSpell);
    new bool:bIsRare = !!(Hwn_Spell_GetFlags(iSpell) & Hwn_SpellFlag_Rare);

    new Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 32.0;

    new Float:vecEnd[3];
    xs_vec_copy(vecOrigin, vecEnd);
    vecEnd[2] += 8.0;

    if (bIsRare) {
        UTIL_Message_SpriteTrail(vecOrigin, vecEnd,  g_iSparklePurpleModelIndex, 8, 1, 1, 32, 16);
    } else {
        UTIL_Message_SpriteTrail(vecOrigin, vecEnd, g_iSparkleModelIndex, 6, 1, 1, 32, 16);
        UTIL_Message_SpriteTrail(vecOrigin, vecEnd, g_iSparklePurpleModelIndex, 2, 1, 1, 32, 16);
    }

    UTIL_Message_FireField(vecOrigin, 32, g_iSmokeModelIndex, 3, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);
}

@Entity_CreateParticles(this) {
    new iSpell = CE_GetMember(this, m_iSpell);
    new bool:bIsRare = !!(Hwn_Spell_GetFlags(iSpell) & Hwn_SpellFlag_Rare);

    new pParticle = Particles_Spawn(bIsRare ? "magic_glow_purple" : "magic_glow", Float:{0.0, 0.0, 0.0}, 0.0);
    if (pParticle) {
        CE_SetMember(this, m_pParticle, pParticle);
    }
}

@Entity_UpdateParticles(this, bool:createIflNotExists) {
    if (g_bIsPrecaching) return;

    new pParticle = CE_GetMember(this, m_pParticle);
    if (!pParticle || !pev_valid(pParticle)) {
        if (createIflNotExists) {
            @Entity_CreateParticles(this);
        }

        return;
    }

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);
    vecOrigin[2] += 32.0;

    engfunc(EngFunc_SetOrigin, pParticle, vecOrigin);
}

@Entity_RemoveParticles(this) {
    new pParticle = CE_GetMember(this, m_pParticle);
    if (!pParticle) return;

    if (pev_valid(pParticle)) {
        Particles_Remove(pParticle);
    }

    CE_SetMember(this, m_pParticle, 0);
}

GetRandomSpell() {
    new bool:bIsRare = random(100) < get_pcvar_num(g_pCvarRareChance);

    new iSpellsNum = Hwn_Spell_GetCount();
    if (!iSpellsNum) return -1;

    new Array:spells = ArrayCreate(_, iSpellsNum);

    for (new iSpell = 0; iSpell < iSpellsNum; ++iSpell) {
        if (bIsRare != !!(Hwn_Spell_GetFlags(iSpell) & Hwn_SpellFlag_Rare)) {
            continue;
        }

        ArrayPushCell(spells, iSpell);
    }

    new iSpell = ArrayGetCell(spells, random(ArraySize(spells)));

    ArrayDestroy(spells);

    return iSpell;
}
