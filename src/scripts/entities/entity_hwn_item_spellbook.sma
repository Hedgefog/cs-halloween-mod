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

#define pev_spell pev_iuser1
#define pev_eparticle pev_euser1

#define ENTITY_NAME "hwn_item_spellbook"

new g_sprSparkle;
new g_sprSparklePurple;

new g_particlesEnabled = false;

new const g_szSndSpawn[] = "hwn/items/spellbook/spellbook_spawn.wav";
new const g_szSndPickup[] = "hwn/spells/spell_pickup.wav";
new const g_szSndPickupRare[] = "hwn/spells/spell_pickup_rare.wav";

new bool:g_isPrecaching;

new g_cvarMaxSpellCount;
new g_cvarMaxRareSpellCount;
new g_cvarRareChance;

new g_ceHandler;

public plugin_init()
{
    g_isPrecaching = false;

    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{
    g_isPrecaching = true;

    g_sprSparkle = precache_model("sprites/muz2.spr");
    g_sprSparklePurple = precache_model("sprites/muz7.spr");

    precache_sound(g_szSndSpawn);
    precache_sound(g_szSndPickup);
    precache_sound(g_szSndPickupRare);

    g_ceHandler = CE_Register(
        .szName = ENTITY_NAME,
        .modelIndex = precache_model("models/hwn/items/spellbook_v2.mdl"),
        .vMins = Float:{-16.0, -12.0, 0.0},
        .vMaxs = Float:{16.0, 12.0, 24.0},
        .fLifeTime = 30.0,
        .fRespawnTime = 30.0,
        .preset = CEPreset_Item
    );

    CE_RegisterHook(CEFunction_Spawn, ENTITY_NAME, "OnSpawn");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "OnRemove");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "OnKilled");
    CE_RegisterHook(CEFunction_Pickup, ENTITY_NAME, "OnPickup");

    g_cvarMaxSpellCount = register_cvar("hwn_spellbook_max_spell_count", "3");
    g_cvarMaxRareSpellCount = register_cvar("hwn_spellbook_max_rare_spell_count", "1");
    g_cvarRareChance = register_cvar("hwn_spellbook_rare_chance", "30");
}

public Hwn_Fw_ConfigLoaded()
{
    g_particlesEnabled = get_cvar_num("hwn_enable_particles");
}

public OnSpawn(ent)
{
    new spell = RandomSpell();

    if (spell == -1) {
        CE_Remove(ent);
        return;
    }

    new bool:isRare = !!(Hwn_Spell_GetFlags(spell) & Hwn_SpellFlag_Rare);

    set_pev(ent, pev_spell, spell);
    set_pev(ent, pev_framerate, 1.0);

    new Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 32.0;

    new Float:vEnd[3];
    xs_vec_copy(vOrigin, vEnd);
    vEnd[2] += 8.0;

    if (isRare) {
        UTIL_Message_SpriteTrail(vOrigin, vEnd,  g_sprSparklePurple, 8, 1, 1, 32, 16);
    } else {
        UTIL_Message_SpriteTrail(vOrigin, vEnd, g_sprSparkle, 6, 1, 1, 32, 16);
        UTIL_Message_SpriteTrail(vOrigin, vEnd, g_sprSparklePurple, 2, 1, 1, 32, 16);
    }

    emit_sound(ent, CHAN_BODY, g_szSndSpawn, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    RemoveParticles(ent);
    CreateParticles(ent);

    TaskThink(ent);
}

public OnRemove(ent)
{
    remove_task(ent);

    RemoveParticles(ent);
}

public OnKilled(ent)
{
    RemoveParticles(ent);
}

public OnPickup(ent, id)
{
    if (Hwn_Spell_GetPlayerSpell(id) != -1) {
        return PLUGIN_CONTINUE;
    }

    new spell = pev(ent, pev_spell);
    new bool:isRare = !!(Hwn_Spell_GetFlags(spell) & Hwn_SpellFlag_Rare);
    new maxSpellCount = isRare ? get_pcvar_num(g_cvarMaxRareSpellCount) : get_pcvar_num(g_cvarMaxSpellCount);

    if (maxSpellCount > 0) {
        Hwn_Spell_SetPlayerSpell(id, spell, random(maxSpellCount) + 1);
    }

    emit_sound(ent, CHAN_BODY, isRare ? g_szSndPickupRare : g_szSndPickup, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_HANDLED;
}

public TaskThink(ent)
{
    if (!pev_valid(ent)) {
        return;
    }

    if (g_ceHandler != CE_GetHandlerByEntity(ent)) {
        return;
    }

    if (pev(ent, pev_deadflag) != DEAD_NO) {
        return;
    }

    if (g_particlesEnabled) {
        UpdateParticles(ent, true);
    } else {
        RemoveParticles(ent);
    }

    set_task(1.0, "TaskThink", ent);
}

RandomSpell() {
    new bool:isRare = random(100) < get_pcvar_num(g_cvarRareChance);

    new spellCount = Hwn_Spell_GetCount();
    if (!spellCount) {
        return - 1;
    }

    new Array:spells = ArrayCreate(_, spellCount);

    for (new spell = 0; spell < spellCount; ++spell) {
        if (isRare != !!(Hwn_Spell_GetFlags(spell) & Hwn_SpellFlag_Rare)) {
            continue;
        }

        ArrayPushCell(spells, spell);
    }

    new spell = ArrayGetCell(spells, random(ArraySize(spells)));

    ArrayDestroy(spells);

    return spell;
}

CreateParticles(ent)
{
    new spell = pev(ent, pev_spell);
    new bool:isRare = !!(Hwn_Spell_GetFlags(spell) & Hwn_SpellFlag_Rare);

    new particleEnt = Particles_Spawn(isRare ? "magic_glow_purple" : "magic_glow", Float:{0.0, 0.0, 0.0}, 0.0);
    if (particleEnt) {
        set_pev(ent, pev_eparticle, particleEnt);
    }
}

UpdateParticles(ent, bool:createIfNotExists = false)
{
    if (g_isPrecaching) {
        return;
    } 

    new particleEnt = pev(ent, pev_eparticle);
    if (!particleEnt || !pev_valid(particleEnt)) {
        if (createIfNotExists) {
            CreateParticles(ent);
        }

        return;
    }

    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);
    vOrigin[2] += 32.0;

    engfunc(EngFunc_SetOrigin, particleEnt, vOrigin);
}

RemoveParticles(ent)
{
    new particleEnt = pev(ent, pev_eparticle);
    if (!particleEnt) {
        return;
    }

    if (pev_valid(particleEnt)) {
        Particles_Remove(particleEnt);
    }

    set_pev(ent, pev_eparticle, 0);
}
