# Methods

### Hwn_Spell_Register
> Register new spell.

| Param          | Description                                                                                    |
|----------------|------------------------------------------------------------------------------------------------|
| szName         | Name of the spell                                                                              |
| szCastCallback | Callback. Will be executed when player cast spell. Player id will be passed at first argument. |

### Hwn_Spell_GetCount
> Get count of registered spells.

### Hwn_Spell_GetName
> Get name of spell by spell handler.

| Param  | Description               |
|--------|---------------------------|
| spell  | Spell handler.            |
| szName | Output array.             |
| maxlen | Max len of output string. |


---

# UTILS

### UTIL_HwnSpawnPlayerSpellball
> Create spellball entity with predefined velocity, modelindex and render color.

| Param      | Description                                                                       | Type              | Default Value |
|------------|-----------------------------------------------------------------------------------|-------------------|---------------|
| owner      | Spawn origin to will be read from the owner position.                             | Integer           |               |
| modelindex | Max len of output string.                                                         | Integer           |               |
| color      | Color of spellball                                                                | Integer Array [3] |               |
| speed      | Start speed of spell ball. Direction will be generated from the owner aim vector. | Integer           | 512           |
| scale      | Scale of spellball sprite.                                                        | Float             | 0.25          |

---
 
### UTIL_HwnSpellDetonateEffect
> Create detonation effect.

| Param      | Description    | Type              | Default Value |
|------------|----------------|-------------------|---------------|
| modelindex | Effect sprite. | Integer           |               |
| vOrigin    | Effect origin. | Float Array [3]   |               |
| color      | Effect color.  | Integer Array [3] |               |
| fRadius    | Effect radius. | Float             |               |


# Create your spell using spellball entity.

At first you should register your spell and save returned handler to the global variable

```SourcePawn
#include <amxmodx>

#include <hwn>
#include <hwn_spell_utils>

new g_hSpell;

public plugin_init()
{
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
    g_hSpell = Hwn_Spell_Register("Boo Spell", "OnCast");
}

public OnCast(id) {}

```

Precache resources for spell effects.

```SourcePawn
new g_sprSpellball;
new g_sprSpellballTrace;

public plugin_precache()
{
    g_sprSpellball = precache_model("sprites/rjet1.spr");
    g_sprSpellballTrace = precache_model("sprites/xbeam4.spr");
}
```

Implement cast handler

You can use hwn_spell_utils to spawn spellball entity.

```SourcePawn
new ent = UTIL_HwnSpawnPlayerSpellball(id, g_sprSpellball, {255, 0, 0});

if (!ent) {
    return PLUGIN_HANDLED; // discard cast
}

// create task to kill spellball after 5 seconds and pass entity index as task id.
set_task(5.0, "TaskKillSpellball", ent);

return PLUGIN_CONTINUE; // allow cast
```

Now implement task to kill spellball using hwn_spell_utils include to make detonation effect.

```SourcePawn
public TaskKillSpellball(ent)
{
    static Float:vOrigin[3];
    pev(ent, pev_origin, vOrigin);

    UTIL_HwnSpellDetonateEffect(
      .modelindex = g_sprSpellballTrace,
      .vOrigin = vOrigin,
      .fRadius = 128.0,
      .color = {255, 0, 0}
    );
}
```
