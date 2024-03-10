#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <hwn>
#include <hwn_utils>

#include <api_custom_entities>
#include <api_particles>

#define PLUGIN "[Custom Entity] Hwn Item Spellbook"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_spellbook"

#define m_iSpell "iSpell"
#define m_iAmount "iAmount"
#define m_pParticlesEmitter "pParticlesEmitter"

new const g_szModel[] = "models/hwn/items/spellbook_v2.mdl";
new const g_szSndSpawn[] = "hwn/items/spellbook/spellbook_spawn.wav";
new const g_szSndPickup[] = "hwn/spells/spell_pickup.wav";
new const g_szSndPickupRare[] = "hwn/spells/spell_pickup_rare.wav";

new g_pCvarMaxSpellsNum;
new g_pCvarMaxRareSpellsNum;
new g_pCvarRareChance;

new g_iSmokeModelIndex;

new g_rgszParticleSprites[][] = {
    "sprites/muz2.spr",
    "sprites/muz3.spr",
    "sprites/muz4.spr",
    "sprites/muz5.spr",
    "sprites/muz6.spr",
    "sprites/muz7.spr",
    "sprites/muz8.spr"
};

new g_rgszRareParticleSprites[][] = {
    "sprites/muz7.spr",
    "sprites/muz4.spr"
};

public plugin_precache() {
    precache_model(g_szModel);
    g_iSmokeModelIndex = precache_model("sprites/hwn/magic_smoke.spr");

    for (new i = 0; i < sizeof(g_rgszParticleSprites); ++i) {
        precache_model(g_rgszParticleSprites[i]);
    }

    for (new i = 0; i < sizeof(g_rgszRareParticleSprites); ++i) {
        precache_model(g_rgszRareParticleSprites[i]);
    }

    precache_sound(g_szSndSpawn);
    precache_sound(g_szSndPickup);
    precache_sound(g_szSndPickupRare);

    CE_Register(ENTITY_NAME, CEPreset_Item);
    CE_RegisterHook(ENTITY_NAME, CEFunction_Init, "@Entity_Init");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Spawned, "@Entity_Spawned");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Remove, "@Entity_Remove");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Killed, "@Entity_Killed");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Pickup, "@Entity_Pickup");
    CE_RegisterHook(ENTITY_NAME, CEFunction_Think, "@Entity_Think");

    g_pCvarMaxSpellsNum = register_cvar("hwn_spellbook_max_spell_count", "3");
    g_pCvarMaxRareSpellsNum = register_cvar("hwn_spellbook_max_rare_spell_count", "1");
    g_pCvarRareChance = register_cvar("hwn_spellbook_rare_chance", "30");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Init(this) {
    CE_SetMember(this, CE_MEMBER_LIFETIME, HWN_NPC_LIFE_TIME);
    CE_SetMember(this, CE_MEMBER_RESPAWNTIME, HWN_ITEM_RESPAWN_TIME);
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-16.0, -12.0, 0.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{16.0, 12.0, 24.0});
    CE_SetMemberString(this, CE_MEMBER_MODEL, g_szModel, false);
    CE_SetMember(this, m_pParticlesEmitter, -1);

    new ParticleSystem:pParticlesEmitter = ParticleSystem_Create("hwn-magic-circle", Float:{0.0, 0.0, 1.0}, _, this);
    ParticleSystem_SetMember(pParticlesEmitter, "flRadius", 24.0);
    CE_SetMember(this, m_pParticlesEmitter, pParticlesEmitter);
}

@Entity_Spawned(this) {
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

    set_pev(this, pev_angles, Float:{0.0, 0.0, 0.0});
    
    new ParticleSystem:pParticlesEmitter = CE_GetMember(this, m_pParticlesEmitter);
    ParticleSystem_Activate(pParticlesEmitter);

    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Killed(this) {
    CE_DeleteMember(this, m_iSpell);
    CE_DeleteMember(this, m_iAmount);

    new ParticleSystem:pParticlesEmitter = CE_GetMember(this, m_pParticlesEmitter);
    ParticleSystem_Deactivate(pParticlesEmitter);
}

@Entity_Remove(this) {
    new ParticleSystem:pParticlesEmitter = CE_GetMember(this, m_pParticlesEmitter);
    ParticleSystem_Destroy(pParticlesEmitter);
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

    @Entity_UpdateParticles(this);

    set_pev(this, pev_nextthink, get_gametime() + 1.0);
}

@Entity_UpdateParticles(this) {
    static ParticleSystem:pParticlesEmitter; pParticlesEmitter = CE_GetMember(this, m_pParticlesEmitter);

    if (_:pParticlesEmitter == -1) return;

    static iSpell; iSpell = CE_GetMember(this, m_iSpell);
    static bool:bIsRare; bIsRare = !!(Hwn_Spell_GetFlags(iSpell) & Hwn_SpellFlag_Rare);

    ParticleSystem_SetMember(pParticlesEmitter, "bRare", bIsRare);
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
        UTIL_Message_SpriteTrail(vecOrigin, vecEnd,  engfunc(EngFunc_ModelIndex, g_rgszRareParticleSprites[0]), 8, 1, 1, 32, 16);
    } else {
        UTIL_Message_SpriteTrail(vecOrigin, vecEnd, engfunc(EngFunc_ModelIndex, g_rgszParticleSprites[0]), 6, 1, 1, 32, 16);
        UTIL_Message_SpriteTrail(vecOrigin, vecEnd, engfunc(EngFunc_ModelIndex, g_rgszParticleSprites[5]), 2, 1, 1, 32, 16);
    }

    UTIL_Message_FireField(vecOrigin, 32, g_iSmokeModelIndex, 3, TEFIRE_FLAG_ALLFLOAT | TEFIRE_FLAG_ALPHA, 10);
}

GetRandomSpell() {
    new bool:bIsRare = random(100) < get_pcvar_num(g_pCvarRareChance);

    new iSpellsNum = Hwn_Spell_GetCount();
    if (!iSpellsNum) return -1;

    new Array:spells = ArrayCreate(_, iSpellsNum);

    for (new iSpell = 0; iSpell < iSpellsNum; ++iSpell) {
        if (bIsRare != !!(Hwn_Spell_GetFlags(iSpell) & Hwn_SpellFlag_Rare)) continue;

        ArrayPushCell(spells, iSpell);
    }

    new iSpell = ArrayGetCell(spells, random(ArraySize(spells)));

    ArrayDestroy(spells);

    return iSpell;
}
