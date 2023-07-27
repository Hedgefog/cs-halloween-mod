#if defined _api_particles_included
  #endinput
#endif
#define _api_particles_included

#define API_PARTICLES_MAX_SPRITES 8

native Particles_Register
(
    const szName[],
    const szTransformCallback[],
    const sprites[API_PARTICLES_MAX_SPRITES],
    Float:flLifeTime,
    Float:flScale,
    renderMode,
    Float:flRenderAmt,
    spawnCount
);

native Particles_Spawn(const szName[], const Float:vecOrigin[3], Float:flPlayTime);
native Particles_Remove(ent);