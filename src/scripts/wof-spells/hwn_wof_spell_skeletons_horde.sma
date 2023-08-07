#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_wof>
#include <hwn_utils>

#define PLUGIN "[Hwn] Skeletons Horde WoF Spell"
#define AUTHOR "Hedgehog Fog"

#define SKELETON_EGG_ENTITY_NAME "hwn_skeleton_egg_big"
#define SKELETON_EGG_COUNT 5

new const g_szSndDetonate[] = "hwn/spells/spell_skeletons_horde_rise.wav";

new g_iGibsModelIndex;

new g_hWofSpell;

public plugin_precache() {
    g_iGibsModelIndex = precache_model("models/bonegibs.mdl");

    precache_sound(g_szSndDetonate);
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_hWofSpell = Hwn_Wof_Spell_Register("Skeletons Horde", "Invoke");
}

public Hwn_Wof_Fw_Effect_Start(iSpell) {
    if (g_hWofSpell != iSpell) {
        return;
    }

    Hwn_Wof_Abort();

    new pTarget = -1;
    while ((pTarget = engfunc(EngFunc_FindEntityByString, pTarget, "classname", "hwn_pumpkin_dispenser")) != 0) {
        static Float:vecOrigin[3];
        pev(pTarget, pev_origin, vecOrigin);

        static Float:vecDir[3];
        pev(pTarget, pev_angles, vecDir);
        angle_vector(vecDir, ANGLEVECTOR_UP, vecDir);
        xs_vec_mul_scalar(vecDir, -64.0, vecDir);

        xs_vec_add(vecOrigin, vecDir, vecOrigin);

        SpawnEggs(vecOrigin);
        DetonateEffect(pTarget);
    }
}

public Invoke(pPlayer) {}

SpawnEggs(const Float:vecOrigin[3], iTeam = 0, pOwner = 0) {
    for (new i = 0; i < SKELETON_EGG_COUNT; ++i) {
        new pEgg = CE_Create(SKELETON_EGG_ENTITY_NAME, vecOrigin);

        if (!pEgg) {
            continue;
        }

        set_pev(pEgg, pev_team, iTeam);
        set_pev(pEgg, pev_owner, pOwner);
        dllfunc(DLLFunc_Spawn, pEgg);

        static Float:vecNewOrigin[3];
        UTIL_FindPlaceToTeleport(pEgg, vecOrigin, vecNewOrigin, HULL_HUMAN);
        set_pev(pEgg, pev_origin, vecNewOrigin);

        new Float:vecVelocity[3];
        xs_vec_set(vecVelocity, random_float(-96.0, 96.0), random_float(-96.0, 96.0), 128.0);
        set_pev(pEgg, pev_velocity, vecVelocity);
    }
}

DetonateEffect(pEntity) {
    static Float:vecVelocity[3];
    UTIL_RandomVector(-128.0, 128.0, vecVelocity);

    static Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    UTIL_Message_Dlight(vecOrigin, 36, {HWN_COLOR_SECONDARY}, 30, 12);

    UTIL_Message_BreakModel(vecOrigin, Float:{16.0, 16.0, 16.0}, vecVelocity, 30, g_iGibsModelIndex, 20, 25, 0);

    emit_sound(pEntity, CHAN_BODY , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
