#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#include <api_player_camera>

#include <hwn>
#include <hwn_utils>
#include <hwn_stun_const>

#define PLUGIN "[Hwn] Stun"
#define VERSION HWN_VERSION
#define AUTHOR "Hedgehog Fog"

new Hwn_StunType:g_rgiPlayerStunType[MAX_PLAYERS + 1];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    for (new iWeapon = CSW_P228; iWeapon <= CSW_LAST_WEAPON; ++iWeapon) {
        static szWeapon[32]; get_weaponname(iWeapon, szWeapon, charsmax(szWeapon));
        if (equal(szWeapon, NULL_STRING)) continue;
        RegisterHam(Ham_Item_CanDeploy, szWeapon, "HamHook_Weapon_CanDeploy");
        RegisterHam(Ham_CS_Item_GetMaxSpeed, szWeapon, "HamHook_Weapon_GetMaxSpeed");
        RegisterHam(Ham_Weapon_PrimaryAttack, szWeapon, "HamHook_Weapon_PrimaryAttack");
        RegisterHam(Ham_Weapon_SecondaryAttack, szWeapon, "HamHook_Weapon_SecondaryAttack");
        RegisterHam(Ham_Weapon_Reload, szWeapon, "HamHook_Weapon_Reload");
    }
    
    RegisterHamPlayer(Ham_Spawn, "HamHook_Player_Spawn", .Post = 0);
}

public plugin_natives() {
    register_library("hwn_stun");
    register_native("Hwn_Stun_Get", "Native_GetPlayerStun");
    register_native("Hwn_Stun_Set", "Native_SetPlayerStun");
}

/*--------------------------------[ Natives ]--------------------------------*/

public Hwn_StunType:Native_GetPlayerStun(iPluginId, iArgc) {
    new pPlayer = get_param(1);

    return @Player_GetStun(pPlayer);
}

public Native_SetPlayerStun(iPluginId, iArgc) {
    new pPlayer = get_param(1);
    new Hwn_StunType:iType = Hwn_StunType:get_param(2);

    @Player_SetStun(pPlayer, iType);
}

/*--------------------------------[ Methods ]--------------------------------*/

Hwn_StunType:@Player_GetStun(this) {
    return g_rgiPlayerStunType[this];
}

@Player_SetStun(this, Hwn_StunType:iType) {
    g_rgiPlayerStunType[this] = iType;
    
    if (iType == Hwn_StunType_None) {
        new pActiveItem = get_ent_data_entity(this, "CBasePlayer", "m_pActiveItem");
        if (pActiveItem != -1) ExecuteHamB(Ham_Item_Deploy, pActiveItem);

        PlayerCamera_Deactivate(this);
    } else {
        if (PlayerCamera_IsActive(this)) {
            PlayerCamera_Deactivate(this);
        }

        PlayerCamera_Activate(this);
        PlayerCamera_SetAngles(this, Float:{15.0, 0.0, 0.0});
        PlayerCamera_SetOffset(this, Float:{0.0, 0.0, 8.0});
        PlayerCamera_SetDistance(this, 128.0);

        new pActiveItem = get_ent_data_entity(this, "CBasePlayer", "m_pActiveItem");
        if (pActiveItem != -1) ExecuteHamB(Ham_Item_Holster, pActiveItem, 0);
    }

    rg_reset_maxspeed(this);
}

bool:@Player_CanUseWeapon(this) {
    if (!IS_PLAYER(this)) return true;
    if (!is_user_alive(this)) return true;
    if (g_rgiPlayerStunType[this] == Hwn_StunType_None) return true;

    return false;
}

/*--------------------------------[ Hooks ]--------------------------------*/

public HamHook_Player_Spawn(pPlayer) {
    g_rgiPlayerStunType[pPlayer] = Hwn_StunType_None;
}

public HamHook_Weapon_CanDeploy(pWeapon) {
    new pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");

    if (!@Player_CanUseWeapon(pPlayer)) {
        SetHamReturnInteger(0);
        return HAM_OVERRIDE;
    }

    return HAM_IGNORED;
}

public HamHook_Weapon_GetMaxSpeed(pWeapon) {
    new pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");

    if (!@Player_CanUseWeapon(pPlayer)) {
        switch (g_rgiPlayerStunType[pPlayer]) {
            case Hwn_StunType_Full: SetHamReturnFloat(1.0);
            case Hwn_StunType_Slowdown: SetHamReturnFloat(100.0);
        }

        return HAM_OVERRIDE;
    }

    return HAM_IGNORED;
}

public HamHook_Weapon_PrimaryAttack(pWeapon) {
    new pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");

    return @Player_CanUseWeapon(pPlayer) ? HAM_IGNORED : HAM_SUPERCEDE;
}

public HamHook_Weapon_SecondaryAttack(pWeapon) {
    new pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");

    return @Player_CanUseWeapon(pPlayer) ? HAM_IGNORED : HAM_SUPERCEDE;
}

public HamHook_Weapon_Reload(pWeapon) {
    new pPlayer = get_ent_data_entity(pWeapon, "CBasePlayerItem", "m_pPlayer");

    return @Player_CanUseWeapon(pPlayer) ? HAM_IGNORED : HAM_SUPERCEDE;
}
