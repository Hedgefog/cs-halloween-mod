#include <api_custom_entities>

#define SPELLBALL_ENTITY_CLASSNAME "hwn_item_spellball"

stock UTIL_HwnSpawnPlayerSpellball
(
    owner,
    modelindex,
    const color[3],
    speed = 512,
    Float:scale = 0.25
)
{
    static Float:vOrigin[3];
    pev(owner, pev_origin, vOrigin);
    
    new ent = CE_Create(SPELLBALL_ENTITY_CLASSNAME, vOrigin);

    if (!ent) {
        return 0;
    }

    static Float:vVelocity[3];
    velocity_by_aim(owner, speed, vVelocity);
    
    set_pev(ent, pev_owner, owner);
    set_pev(ent, pev_velocity, vVelocity);
    set_pev(ent, pev_modelindex, modelindex);
    set_pev(ent, pev_scale, scale);
    set_pev(ent, pev_rendercolor, color);
    
    dllfunc(DLLFunc_Spawn, ent);

    return ent;
}

stock UTIL_HwnSpellDetonateEffect(modelindex, const Float:vOrigin[3], const color[3], Float:fRadius)
{
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vOrigin, 0);
	write_byte(TE_BEAMCYLINDER);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]);
	engfunc(EngFunc_WriteCoord, vOrigin[0]);
	engfunc(EngFunc_WriteCoord, vOrigin[1]);
	engfunc(EngFunc_WriteCoord, vOrigin[2]+fRadius);
	write_short(modelindex);
	write_byte(0);
	write_byte(0);
	write_byte(5);
	write_byte(floatround(fRadius/2));
	write_byte(0);
	write_byte(color[0]);
	write_byte(color[1]);
	write_byte(color[2]);
	write_byte(255);
	write_byte(0);
	message_end();
}