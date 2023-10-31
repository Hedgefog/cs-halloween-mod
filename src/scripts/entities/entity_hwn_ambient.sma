#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Ambient"
#define AUTHOR "Hedgehog Fog"

#define ENTITY_NAME "hwn_ambient"

new const g_szSndAimbent[][48] = {
    "hwn/ambient/female_scream_01.wav",
    "hwn/ambient/female_scream_02.wav",
    "hwn/ambient/male_scream_02.wav",
    "hwn/ambient/male_scream_02.wav",
    "hwn/ambient/hallow01.wav",
    "hwn/ambient/hallow02.wav",
    "hwn/ambient/hallow03.wav",
    "hwn/ambient/hallow04.wav",
    "hwn/ambient/mysterious_perc_01.wav",
    "hwn/ambient/mysterious_perc_02.wav",
    "hwn/ambient/mysterious_perc_03.wav",
    "hwn/ambient/mysterious_perc_04.wav"
};

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    for (new i = 0; i < sizeof(g_szSndAimbent); ++i) {
        precache_sound(g_szSndAimbent[i]);
    }

    CE_Register(ENTITY_NAME);
    CE_RegisterHook(CEFunction_Spawned, ENTITY_NAME, "@Entity_Spawned");
    CE_RegisterHook(CEFunction_Think, ENTITY_NAME, "@Entity_Think");
}

@Entity_Spawned(this) {
    set_pev(this, pev_nextthink, get_gametime());
}

@Entity_Think(this) {
    emit_sound(this, CHAN_VOICE, g_szSndAimbent[random(sizeof(g_szSndAimbent))], VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
    set_pev(this, pev_nextthink, get_gametime() + random_float(10.0, 100.0));
}
