#if defined _hwn_const_included
  #endinput
#endif
#define _hwn_const_included

#define HWN_COLOR_PURPLE_F              120.0, 0.0, 200.0
#define HWN_COLOR_PURPLE                120, 0, 200
#define HWN_COLOR_RED_F                 255.0, 0.0, 0.0
#define HWN_COLOR_RED                   255, 0, 0
#define HWN_COLOR_BLUE_F                 0.0, 0.0, 255.0
#define HWN_COLOR_BLUE                   0, 0, 255
#define HWN_COLOR_YELLOW_F              255.0, 200.0, 0.0
#define HWN_COLOR_YELLOW                255, 200, 0
#define HWN_COLOR_GREEN_DARK_F          47.0, 95.0, 15.0
#define HWN_COLOR_GREEN_DARK            47, 95, 15
#define HWN_COLOR_ORANGE_DIRTY          52, 26, 8
#define HWN_COLOR_ORANGE_DIRTY_F        52.0, 26.0, 8.0
#define HWN_COLOR_PRIMARY_F             HWN_COLOR_PURPLE_F
#define HWN_COLOR_PRIMARY               HWN_COLOR_PURPLE
#define HWN_COLOR_PRIMARY_PALETTE2      7
#define HWN_COLOR_SECONDARY_F           HWN_COLOR_GREEN_DARK_F
#define HWN_COLOR_SECONDARY             HWN_COLOR_GREEN_DARK

#define HWN_NPC_RESPAWN_TIME 45.0
#define HWN_NPC_LIFE_TIME 30.0
#define HWN_ITEM_RESPAWN_TIME 30.0

#define HWN_TITLE "Halloween Mod"
#define HWN_VERSION "7.0.0"

enum _:Hwn_PumpkinType
{
    Hwn_PumpkinType_Uninitialized = 0,
    Hwn_PumpkinType_Default,
    Hwn_PumpkinType_Crits,
    Hwn_PumpkinType_Equipment,
    Hwn_PumpkinType_Health,
    Hwn_PumpkinType_Gravity
};

enum Hwn_GamemodeFlags (<<=1)
{
    Hwn_GamemodeFlag_None,
    Hwn_GamemodeFlag_Default = 1,
    Hwn_GamemodeFlag_RespawnPlayers,
    Hwn_GamemodeFlag_SpecialEquip,
    Hwn_GamemodeFlag_SpellShop
};

enum Hwn_SpellFlags (<<=1)
{
    Hwn_SpellFlag_None,
    Hwn_SpellFlag_Rare = 1,
    Hwn_SpellFlag_Throwable,
    Hwn_SpellFlag_Applicable,
    Hwn_SpellFlag_Ability,
    Hwn_SpellFlag_Heal,
    Hwn_SpellFlag_Damage,
    Hwn_SpellFlag_Radius,
    Hwn_SpellFlag_Protection
};
