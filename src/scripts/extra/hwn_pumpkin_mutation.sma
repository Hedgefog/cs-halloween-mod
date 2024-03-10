#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>
#include <api_navsystem>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn NPC Spooky Pumpkin"
#define AUTHOR "Hedgehog Fog"

new const Float:g_rgflPumpkinTypeColor[Hwn_PumpkinType][3] = {
    {HWN_COLOR_ORANGE_DIRTY_F},
    {HWN_COLOR_SECONDARY_F},
    {HWN_COLOR_PRIMARY_F},
    {HWN_COLOR_YELLOW_F},
    {HWN_COLOR_RED_F},
    {50.0, 50.0, 50.0},
};

new g_pCvarPumpkinMutateChance;

public plugin_precache() {
    CE_RegisterHook("hwn_item_pumpkin", CEFunction_Killed, "@Pumpkin_Killed");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);

    g_pCvarPumpkinMutateChance = register_cvar("hwn_pumpkin_mutate_chance", "20");
}

/*--------------------------------[ Methods ]--------------------------------*/

@Pumpkin_Killed(this, pKiller, bool:bPicked) {
    if (bPicked) return;

    @Pumpkin_Mutate(this, CE_IsInstanceOf(this, "hwn_item_pumpkin_big"));
}

@Pumpkin_Mutate(this, bool:bBig) {
    new iChance = get_pcvar_num(g_pCvarPumpkinMutateChance);
    if (!iChance) return;
    if (random(100) > iChance) return;

    static Float:vecOrigin[3]; pev(this, pev_origin, vecOrigin);
    static Float:vecAngles[3]; xs_vec_set(vecAngles, 0.0, random_float(0.0, 360.0), 0.0);

    new pMonster = CE_Create(bBig ? "hwn_npc_spookypumpkin_big" : "hwn_npc_spookypumpkin", vecOrigin);
    if (!pMonster) return;

    set_pev(pMonster, pev_angles, vecAngles);

    dllfunc(DLLFunc_Spawn, pMonster);

    @SpookyPumpkin_ApplyType(pMonster, CE_GetMember(this, "iType"), CE_GetMember(this, "iSize"));
}

@SpookyPumpkin_ApplyType(this, iType, iSize) {
    if (iType == Hwn_PumpkinType_Uninitialized) return;

    static Float:flSpeed; pev(this, pev_maxspeed, flSpeed);
    static Float:flHealth; pev(this, pev_health, flHealth);
    static Float:flDamage; flDamage = CE_GetMember(this, "flDamage");

    switch (iType) {
        case Hwn_PumpkinType_Crits: {
            new Float:flDamageMultiplier = get_cvar_float("hwn_crits_damage_multiplier");
            CE_SetMember(this, "flDamage", flDamage * flDamageMultiplier);
        }
        case Hwn_PumpkinType_Equipment: {
            set_pev(this, pev_maxspeed, flSpeed * 1.5);
        }
        case Hwn_PumpkinType_Health: {
            set_pev(this, pev_health, flHealth * 1.5);
        }
        case Hwn_PumpkinType_Gravity: {
            set_pev(this, pev_gravity, MOON_GRAVIY);
        }
        case Hwn_PumpkinType_Default: {
            set_pev(this, pev_maxspeed, flSpeed + (iSize * 0.375));
            set_pev(this, pev_health, flHealth + (iSize * 10));
            CE_SetMember(this, "flDamage", flDamage + (iSize * 5));
        }
    }

    set_pev(this, pev_rendercolor, g_rgflPumpkinTypeColor[iType]);
}
