#include <api_custom_entities>

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"

stock UTIL_HwnSpawnPlayerSpellball(owner, const color[3], speed = 512)
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

    return ent;
}