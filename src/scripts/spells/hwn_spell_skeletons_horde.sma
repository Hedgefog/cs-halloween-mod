#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>
#include <hwn_spell_utils>

#define PLUGIN "[Hwn] Skeletons Horde Spell"
#define AUTHOR "Hedgehog Fog"

#define SKELETON_EGG_ENTITY_NAME "hwn_skeleton_egg_big"
#define SKELETON_EGG_COUNT 5

const SpellballSpeed = 720;

new const EffectColor[3] = {HWN_COLOR_SECONDARY};

new const g_szSndCast[] = "hwn/spells/spell_skeletons_horde_cast.wav";
new const g_szSndDetonate[] = "hwn/spells/spell_skeletons_horde_rise.wav";
new const g_szSprSpellBall[] = "sprites/xsmoke1.spr";

new g_mdlGibs;

new g_hSpell;
new g_hWofSpell;
new g_hCeSpellball;

public plugin_precache() {
    g_mdlGibs = precache_model("models/bonegibs.mdl");
    precache_model(g_szSprSpellBall);

    precache_sound(g_szSndCast);
    precache_sound(g_szSndDetonate);

    g_hSpell = Hwn_Spell_Register(
        "Skeletons Horde",
        Hwn_SpellFlag_Throwable | Hwn_SpellFlag_Damage | Hwn_SpellFlag_Radius | Hwn_SpellFlag_Rare,
        "Cast"
    );

    g_hWofSpell = Hwn_Wof_Spell_Register("Skeletons Horde", "Invoke");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    RegisterHam(Ham_Touch, CE_BASE_CLASSNAME, "HamHook_Base_Touch_Post", .Post = 1);

    g_hCeSpellball = CE_GetHandler(SPELLBALL_ENTITY_CLASSNAME);

    CE_RegisterHook(CEFunction_Killed, SPELLBALL_ENTITY_CLASSNAME, "@SpellBall_Killed");
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Base_Touch_Post(pEntity, pTarget) {
    if (!pev_valid(pEntity)) {
        return;
    }

    if (g_hCeSpellball != CE_GetHandlerByEntity(pEntity)) {
        return;
    }

    if (pev(pEntity, pev_iuser1) != g_hSpell) {
        return;
    }

    if (pTarget == pev(pEntity, pev_owner)) {
        return;
    }

    CE_Kill(pEntity);
}

public @SpellBall_Killed(pEntity) {
    new iSpell = pev(pEntity, pev_iuser1);

    if (iSpell != g_hSpell) {
        return;
    }

    Detonate(pEntity);
}

/*--------------------------------[ Forwards ]--------------------------------*/

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

/*--------------------------------[ Methods ]--------------------------------*/

public Cast(pPlayer) {
    new pEntity = UTIL_HwnSpawnPlayerSpellball(pPlayer, EffectColor, SpellballSpeed, g_szSprSpellBall, _, 0.5, 10.0);
    if (!pEntity) {
        return PLUGIN_HANDLED;
    }

    set_pev(pEntity, pev_iuser1, g_hSpell);

    emit_sound(pPlayer, CHAN_STATIC , g_szSndCast, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);

    return PLUGIN_CONTINUE;
}

public Invoke(pPlayer) {}

Detonate(pEntity) {
    new pOwner = pev(pEntity, pev_owner);
    new iTeam = get_member(pOwner, m_iTeam);

    new Float:vecOrigin[3];
    pev(pEntity, pev_origin, vecOrigin);
    vecOrigin[2] += 32.0;

    UTIL_FindPlaceToTeleport(pEntity, vecOrigin, vecOrigin, HULL_HUMAN);

    SpawnEggs(vecOrigin, iTeam, pOwner);

    DetonateEffect(pEntity);
}

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

    UTIL_Message_BreakModel(vecOrigin, Float:{16.0, 16.0, 16.0}, vecVelocity, 30, g_mdlGibs, 20, 25, 0);

    emit_sound(pEntity, CHAN_BODY , g_szSndDetonate, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}
