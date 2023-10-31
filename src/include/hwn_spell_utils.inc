#include <api_custom_entities>

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"

stock UTIL_HwnSpawnPlayerSpellball(
    pOwner,
    const iColor[3],
    iSpeed = 512,
    const szEffectSprite[] = "",
    Float:flEffectAmt = 255.0,
    Float:flEffectScale = 1.0,
    Float:flEffectFrameRate = 0.0
)
{
    static Float:vecOrigin[3];
    UTIL_GetViewOrigin(pOwner, vecOrigin);

    static Float:vecOffset[3];
    velocity_by_aim(pOwner, 16, vecOffset);
    xs_vec_add(vecOrigin, vecOffset, vecOrigin);

    new pEntity = CE_Create(SPELLBALL_ENTITY_CLASSNAME, vecOrigin);

    if (!pEntity) {
        return 0;
    }

    static Float:vecVelocity[3];
    velocity_by_aim(pOwner, iSpeed, vecVelocity);

    set_pev(pEntity, pev_owner, pOwner);
    set_pev(pEntity, pev_velocity, vecVelocity);

    static Float:flColor[3];
    for (new i = 0; i < 3; ++i) {
        flColor[i] = float(iColor[i]);
    }

    set_pev(pEntity, pev_rendercolor, flColor);

    dllfunc(DLLFunc_Spawn, pEntity);

    if (szEffectSprite[0] != '^0') {
        UTIL_HwnSpawnSpellballEffect(pEntity, szEffectSprite, flColor, flEffectAmt, flEffectScale, flEffectFrameRate);
    }

    return pEntity;
}

stock UTIL_HwnSpawnSpellballEffect(spellballEnt, const szSprite[], const Float:flColor[3], Float:flAmt, Float:flScale, Float:flFramerate)
{
    static iszClassName;
    if (!iszClassName) {
        iszClassName = engfunc(EngFunc_AllocString, "env_sprite");
    }

    new pEntity = engfunc(EngFunc_CreateNamedEntity, iszClassName);
    set_pev(pEntity, pev_solid, SOLID_NOT);
    set_pev(pEntity, pev_movetype, MOVETYPE_NONE);
    set_pev(pEntity, pev_rendermode, kRenderTransAdd);
    engfunc(EngFunc_SetModel, pEntity, szSprite);
    set_pev(pEntity, pev_renderamt, flAmt);
    set_pev(pEntity, pev_rendercolor, flColor);
    set_pev(pEntity, pev_scale, flScale);
    set_pev(pEntity, pev_animtime, get_gametime());
    set_pev(pEntity, pev_framerate, flFramerate);
    set_pev(pEntity, pev_spawnflags, SF_SPRITE_STARTON);

    dllfunc(DLLFunc_Spawn, pEntity);

    set_pev(pEntity, pev_aiment, spellballEnt);
    set_pev(pEntity, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(spellballEnt, pev_euser1, pEntity);

    return pEntity;
}