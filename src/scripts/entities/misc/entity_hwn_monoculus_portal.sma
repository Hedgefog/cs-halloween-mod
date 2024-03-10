#pragma semicolon 1

#include <amxmodx>

#include <api_custom_entities>

#include <hwn>

#define PLUGIN "[Custom Entity] Hwn Monoculus Portal"
#define AUTHOR "Hedgehog Fog"

public plugin_init() {
    register_plugin(PLUGIN, HWN_VERSION, AUTHOR);
}

public plugin_precache() {
    CE_Register("hwn_monoculus_portal");
}
