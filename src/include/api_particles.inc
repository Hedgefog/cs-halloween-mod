#if defined _api_particles_included
  #endinput
#endif
#define _api_particles_included

native Particles_Register
(
	const szName[],
	const szTransformCallback[],
	Array:sprites,
	Float:fLifeTime,
	Float:fScale,
	renderMode,
	Float:fRenderAmt,
	spawnCount
);

native Particles_Spawn(const szName[], const Float:vOrigin[3], Float:fPlayTime);
native Particles_Remove(ent);