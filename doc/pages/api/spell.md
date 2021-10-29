# Create your spell using spellball entity.

At first you should register your spell and save returned handler to the global variable, use precache forward to register spell.

```SourcePawn
#include <amxmodx>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

new g_hSpell;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache()
{
    g_hSpell = Hwn_Spell_Register("Boo Spell", Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Rare, "OnCast");
}

public OnCast(id) {}

```

Precache resources for spell effects.

```SourcePawn
new g_szSpellballSprite[] = "sprites/rjet1.spr";
new g_sprSpellballTrace;

public plugin_precache()
{
    precache_model(g_szSpellballSprite);
    g_sprSpellballTrace = precache_model("sprites/xbeam4.spr");

    g_hSpell = Hwn_Spell_Register("Boo Spell", Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Rare, "OnCast");
}
```

#### Implement cast handler

You can use hwn_spell_utils to spawn spellball entity.

```SourcePawn
public OnCast(id)
{
    new Float:spellballSpeed = 512.0;
    new Float:spellballRenderAmt = 255.0;
    new Float:spellballScale = 0.75;
    new Float:spellballFramerate = 10.0;

    new ent = UTIL_HwnSpawnPlayerSpellball(id, {255, 0, 0}, spellballSpeed, g_szSpellballSprite, spellballRenderAmt, spellballScale, spellballFramerate);

    if (!ent) {
        return PLUGIN_HANDLED; // discard cast
    }

    // create task to kill spellball after 5 seconds and pass entity index as task id.
    set_task(5.0, "TaskKillSpellball", ent);

    return PLUGIN_CONTINUE; // allow cast
}
```

Now implement task to kill spellball using hwn_utils include to make detonation effect.

Spellball entity is a custom entity created using Custom Entities API, so you should use CE_Kill to kill this entity.

```SourcePawn
public TaskKillSpellball(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_Message_BeamCylinder(
        vOrigin,
        fRadius,
        .modelIndex = g_sprSpellballTrace,
        .lifeTime = 10,
        .width = 32,
        .noise = 0,
        .color = {255, 0, 0},
        .brightness = 100
    );

    CE_Kill(ent);
}
```
