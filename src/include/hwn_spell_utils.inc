#include <api_custom_entities>

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"

stock UTIL_HwnSpawnPlayerSpellball(
    owner,
    const color[3],
    speed = 512,
    const szEffectSprite[] = "",
    Float:fEffectAmt = 255.0,
    Float:fEffectScale = 1.0,
    Float:fEffectFrameRate = 0.0
)
{
    static Float:vOrigin[3];
    pev(owner, pev_origin, vOrigin);

    static Float:vViewOfs[3];
    pev(owner, pev_view_ofs, vViewOfs);
    xs_vec_add(vOrigin, vViewOfs, vOrigin);

    static Float:vOffset[3];
    velocity_by_aim(owner, 16, vOffset);
    xs_vec_add(vOrigin, vOffset, vOrigin);

    new ent = CE_Create(SPELLBALL_ENTITY_CLASSNAME, vOrigin);

    if (!ent) {
        return 0;
    }

    static Float:vVelocity[3];
    velocity_by_aim(owner, speed, vVelocity);

    set_pev(ent, pev_owner, owner);
    set_pev(ent, pev_velocity, vVelocity);

    static Float:fColor[3];
    for (new i = 0; i < 3; ++i) {
        fColor[i] = float(color[i]);
    }

    set_pev(ent, pev_rendercolor, fColor);

    dllfunc(DLLFunc_Spawn, ent);

    if (szEffectSprite[0] != '^0') {
        UTIL_HwnSpawnSpellballEffect(ent, szEffectSprite, fColor, fEffectAmt, fEffectScale, fEffectFrameRate);
    }

    return ent;
}

stock UTIL_HwnSpawnSpellballEffect(spellballEnt, const szSprite[], const Float:fColor[3], Float:fAmt, Float:fScale, Float:fFramerate)
{
    static allocClassname;
    if (!allocClassname) {
        allocClassname = engfunc(EngFunc_AllocString, "env_sprite");
    }

    new ent = engfunc(EngFunc_CreateNamedEntity, allocClassname);
    set_pev(ent, pev_solid, SOLID_NOT);
    set_pev(ent, pev_movetype, MOVETYPE_NONE);
    set_pev(ent, pev_rendermode, kRenderTransAdd);
    engfunc(EngFunc_SetModel, ent, szSprite);
    set_pev(ent, pev_renderamt, fAmt);
    set_pev(ent, pev_rendercolor, fColor);
    set_pev(ent, pev_scale, fScale);
    set_pev(ent, pev_animtime, get_gametime());
    set_pev(ent, pev_framerate, fFramerate);
    set_pev(ent, pev_spawnflags, SF_SPRITE_STARTON);

    dllfunc(DLLFunc_Spawn, ent);

    set_pev(ent, pev_aiment, spellballEnt);
    set_pev(ent, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(spellballEnt, pev_euser1, ent);

    return ent;
}