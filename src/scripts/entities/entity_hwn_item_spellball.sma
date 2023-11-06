#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#include <api_custom_entities>

#include <hwn>
#include <hwn_utils>

#define PLUGIN "[Custom Entity] Hwn Item Spellball"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_item_spellball"

new g_iSmokeModelIndex;
new g_iNullModelIndex;

public plugin_precache() {
    g_iSmokeModelIndex = precache_model("sprites/black_smoke1.spr");
    g_iNullModelIndex = precache_model("sprites/white.spr");

    CE_Register(ENTITY_NAME, CEPreset_None);
    CE_RegisterHook(CEFunction_Init, ENTITY_NAME, "@Entity_Init");
    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
    CE_RegisterHook(CEFunction_Killed, ENTITY_NAME, "@Entity_Killed");
    CE_RegisterHook(CEFunction_Remove, ENTITY_NAME, "@Entity_Remove");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");
}

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

@Entity_Init(this) {
    CE_SetMemberVec(this, CE_MEMBER_MINS, Float:{-8.0, -8.0, -8.0});
    CE_SetMemberVec(this, CE_MEMBER_MAXS, Float:{8.0, 8.0, 8.0});
    CE_SetMember(this, CE_MEMBER_LIFETIME, HWN_NPC_LIFE_TIME);
}

@Entity_Spawned(this) {
    set_pev(this, pev_gravity, 0.20);
    set_pev(this, pev_health, 1.0);
    set_pev(this, pev_solid, SOLID_TRIGGER);
    set_pev(this, pev_movetype, MOVETYPE_TOSS);
    set_pev(this, pev_rendermode, kRenderTransTexture);
    set_pev(this, pev_renderamt, 0.0);
    set_pev(this, pev_modelindex, g_iNullModelIndex);
    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Killed(this) {
    set_pev(this, pev_deadflag, DEAD_DEAD);
}

@Entity_Remove(this) {
    for (new euser = pev_euser1; euser <= pev_euser4; ++euser) {
        if (pev(this, euser)) {
            engfunc(EngFunc_RemoveEntity, pev(this, euser));
        }
    }
}

@Entity_Think(this) {
    static Float:flRate; flRate = Hwn_GetUpdateRate();
    static iLifeTime; iLifeTime = max(floatround(flRate * 10), 1);

    static Float:vecOrigin[3];
    pev(this, pev_origin, vecOrigin);

    static rgiColor[3];
    pev(this, pev_rendercolor, rgiColor);
    for (new i = 0; i < 3; ++i) rgiColor[i] = floatround(Float:rgiColor[i]);

    UTIL_Message_Dlight(vecOrigin, 16, rgiColor, iLifeTime, 0);

    // Fix for smoke origin
    static Float:vecVelocity[3];
    pev(this, pev_velocity, vecVelocity);

    static Float:flSpeed; flSpeed = xs_vec_len(vecVelocity);

    static Float:vecSub[3];
    xs_vec_normalize(vecVelocity, vecSub);
    xs_vec_mul_scalar(vecSub, flSpeed / 16.0, vecSub); // origin prediction
    vecSub[2] += 20.0;

    xs_vec_sub(vecOrigin, vecSub, vecOrigin);

    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vecOrigin, 0);
    write_byte(TE_SMOKE);
    engfunc(EngFunc_WriteCoord, vecOrigin[0]);
    engfunc(EngFunc_WriteCoord, vecOrigin[1]);
    engfunc(EngFunc_WriteCoord, vecOrigin[2]);
    write_short(g_iSmokeModelIndex);
    write_byte(10);
    write_byte(90);
    message_end();

    UTIL_Message_Dlight(vecOrigin, 16, rgiColor, iLifeTime, 0);

    set_pev(this, pev_nextthink, get_gametime() + flRate);
}
