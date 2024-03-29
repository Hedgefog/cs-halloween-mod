/*
    6.4.2
        Fixes:
            Fixed objective marks spawn

    6.4.1
        Fixes:
            Fixed HHH NPC pathfinding
            Pumpkin no longer drops on suicide

    6.4.0
        Additions and improvements:
            Added Skeletons Horde spell
            Added Intangibility spell
            Added objective marks
            Added player highlight
            Added Magic Wheel of Fate spell
            Added a random bonus drop from the bucket when scoring points
            Players now always drop pumpkin in collector gamemode
            Removed Fortune Wheel of Fate spell
            Reduced Monoculus rocket damage
            Increased Monoculus NPC hit range
            Increased crit pumpkin effect duration
            Increased Skeleton NPC damage
            Increased Spooky Pumpkin NPC health
            Increased Spooky Pumpkin NPC speed
            Reduced Ghost NPC speed
            Rare spells appear less frequently now
            Improved HHH NPC AI
            Improved Monoculus NPC AI
            Improved Skeleton NPC AI
            Improved collector gamemode win conditions
            Added glow for Monoculus NPC
            Increased light level for default gamemode
            Added Ukrainian translation

        Cvars:
            Added hwn_objective_marks cvar
            Added hwn_player_highlight cvar
            Added hwn_player_highlight_primary_brightness cvar
            Added hwn_player_highlight_secondary_brightness cvar
            Added hwn_spellbook_rare_chance cvar
            Added hwn_bucket_bonus_chance cvar

        Fixes:
            Fixed errors related to the blink spellball

    6.3.0
        Additions and improvements:
            Added player preview when choosing cosmetics
            Force equipment change is now available on all spawn points
            Players can no longer cast spells during freezetime and with the FL_FROZEN flag
            Reduced Monoculus HP
            Added Monoculus levels
            Power Up spell now heals
            Reworked lightning spell
            Increased fireball speed
            Increased blinkball speed
            Event points are no longer created at enemy spawn
            Added spell groups (common, rare)
            Spellbook now indicates a spell group with different particles
            Improved NPC targeting and navigation
            Added spell flags to the spells api
            Added event points API
            Added Gifts API
            Improved magic glow particle
            Power Up spell optimization
            Player burn api optimization
            Many performance optimizations
            Round logic moved to the separate API

        Cvars:
            Added hwn_pcosmetic_menu_preview cvar
            Added hwn_pcosmetic_menu_preview_light cvar
            Added hwn_spellbook_max_rare_spell_count cvar

        Fixes:
            Fixed Power Up spell jump behavior
            Fixed jump animation for Power Up spell
            Fixed bug when monoculus can shoot while in stun
            Fixed crit sound volume
            Fixed invisibility spell fade effect
            Fixed gift spawn task
            Fixed temp entities with ignoreRounds flag behavior
            Fixed bots cosmetics

        Credits:
            iwillnotleave (player burn api and Power Up spell optimization)

    6.2.0
        Additions and improvements:
            New team bucket
            Added round time for collector gamemode
            Added objectives blocking while the boss is alive
            Added boss spawning on team points collect
            Added bonuses for team bucket filling
            Reduced Monoculus damage
            Added spells localization
            Added bosses localization
            Bots now use spells
            Bots are now equipped with random cosmetics
            Explosions now take obstacles into account
            Improved radius damage calculation
            Crit damage now applies only to players and NPCs
            Added a chance to drop a spellbook from an NPC on kill
            Buckets now ignore wallbang damage
            Added random equipment for bots
            Added drop forward flag to hwn_pumpkin_dispenser entity
            Removed drop direction flag from hwn_pumpkin_dispenser entity
            Added onhit mode for crit effects
            Improved explosion effect
            Improved custom lighting for default gamemode
            Improved overheal spell effect
            Increased spawn range
            Added flash and wave bucket effect on win

        Cvars:
            Added hwn_collector_roundtime cvar
            Added hwn_collector_roundtime_overtime cvar
            Added hwn_bucket_bonus_health cvar
            Added hwn_bucket_bonus_armor cvar
            Added hwn_bucket_bonus_ammo cvar
            Added hwn_collector_npc_drop_chance_spell cvar
            Added hwn_collector_teampoints_to_boss_spawn cvar
            Added hwn_bots_spells cvar
            Added hwn_bots_cosmetics cvar

        Fixes:
            Fixed team score calculation for reapi version
            Fixed crit trace origin
            Fixed explosive pumpkin damage
            Fixed first pumpkin picked message condition

    6.1.0
        Additions and improvements:
            Reduced the fire rate boost for the powerup spell
            Added cvar to specify the number of spells on spawn
            New config loader implementation
            Increased flying range of blink spell ball 
            Added Portuguese translation (by artYY)
            Updated Hungarian translation (by regener)

        Cvars:
            Removed hwn_gamemode_spell_on_spawn cvar
            Added hwn_gamemode_spells_on_spawn cvar

        Fixes:
            Fixed powerup spell effect duration
            Fixed spellball light

    6.0.0
        Additions and improvements:
            Added Wheel of Fate (random spell effects)
            Added crits
            Added crits spell
            Added a flash effect when picking up a pumpkin
            Added a flash effect while putting pumpkin into bucket
            Added Power Up spell
            Added Boss PVE
            Added showing of equipment menu when player respawning the first time
            Invisibility no longer invokes for nearby teammates
            Bosses will now kill the player when intersect while respawning
            Spellballs are now cast from view position
            Improved small skeletons spawning
            A new gift now appears only after picking up or disappear the old one
            NPCs can now walk up stairs
            Improved spells effects
            Improved HUD
            Money and Timer HUD in collector gamemode now hidden by default
            Added Hungarian translation (by regener)
            Renamed hwn_spawn_boss command to hwn_boss_spawn

        Cvars:
            Added hwn_spellbook_max_spell_count cvar
            Added hwn_spellbook_max_rare_spell_count cvar
            Added hwn_bucket_collect_flash cvar
            Added hwn_pumpkin_pickup_flash cvar
            Added hwn_wof_effect_time cvar
            Added hwn_collector_wof cvar
            Added hwn_collector_wof_delay cvar
            Added hwn_crits_damage_multiplier cvar
            Added hwn_crits_random cvar
            Added hwn_crits_random_chance_initial cvar
            Added hwn_crits_random_chance_max cvar
            Added hwn_crits_random_chance_bonus cvar
            Added hwn_crits_random_chance_penalty cvar
            Added hwn_crits_effect_trace cvar
            Added hwn_crits_effect_splash cvar
            Added hwn_crits_effect_flash cvar
            Added hwn_crits_effect_status_icon cvar
            Added hwn_crits_sound_use cvar
            Added hwn_crits_sound_hit cvar
            Added hwn_crits_sound_shoot cvar
            Added hwn_hud_collector_hide_money cvar
            Added hwn_hud_collector_hide_time cvar
            Added hwn_boss_pve cvar
            Added hwn_boss_spawn command
            Added hwn_wof_roll command
            Added hwn_wof_abort command
            Added hwn_spells_give command
            Added hwn_crits_toggle command

        Fixes:
            Fixed boss healthbar display
            Fixed blink spell teleportation
            Fixed ru lang
            Fixed small skeletons getting stuck
            Fixed small skeleton hitbox
            Fixed respawn on join

    4.0.0

        Additions and improvements:
            Added Moon Jump spell
            Added healthbar for bosses
            Added Spooky Pumpkin NPC
            Added smooth rotation for NPC
            Improved NPC movement algorithm
            Added localization for equipment menu title
            Added localization for cosmetic menu title
            Optimized models

        Cvars:
            Added hwn_gamemode_new_round_delay cvar
            Added hwn_pumpkin_mutate_chance cvar
            Added hwn_boss_healthbar cvar

        Fixes:
            Fixed interaction of some plugins
            Fixed issue when equipped items are disabled in the cosmetic menu
            Fixed cleaning tasks in some plugins

    3.1.0
        Equipment pumpkin now give ammo for all weapons.
        Cosmetic equip state now saved on player disconnect.
        Added localization for empty comsetic menu text.
        Added PInv_Event_Destroy forward, call when the player inventory api plugin destroy the handlers.
        Cosmetic api plugin now destroy handlers after player inventory api plugin.
        Monoculus rocket speed reduced to 720 ups.
        Fixed issue when the player losing some cosmetic items after disconnect.
        Fixed issue when the player's inventory was not saved after the server restart.

    3.0.1
        Fixed HHH NPC Pathfinding.
        Fixed monoculus rocket entity.

    3.0.0
        Halloween is here!
        Added new cosmetic items.
        Added monoculus npc.
        Fixed player cosmetic api.

    2.3.3
        fixed a bug in api_player_cosmetic which crash server after player disconnect.

    2.3.2
        ReAPI Support.
        Fixed equipment menu title.

    2.3.1
        Corpse no longer spawn in gamemode with player respawn
        Spell balls no longer pass through clip brashes
        Minimizes mod influence on shooting
        High performance improvement
        New Spell API
        Added event handler entity
        Added Lightning spell
        Added hwn_boss_min_damage_to_win cvar
        Improved NPC hit logic
        Added hwn_spawn_boss command
        Fixed npc kill reward in collector gamemode
        Fade effect of invisibility spell now saving after external fade effects
        Improved HHH NPC

    2.2.1
        Orpheu no longer required
        Orpheu replaced to RoundControl
        Changed color for 'hwn4' sky
        Fixed lighting
        Fixed crashes

    2.2.0
        Improved ghosts
        Improved performance
        Added cvar to disable particles
        Ghost can no longer disable Jack'O'Lantern around
        Added fps settings
        Fixed NPC reachable check
        Fixed crashes
        Fixed fireballs
        Fixed explosive pumpkins
        Fixed ce temp storage

    2.1.1
        Fixed buyzone in Default Gamemode

    2.1.0
        Updated Custom Entities API
        Players now can move through skeletons
        Ghosts now disable Jack'O'Lantern around
        In Collector Gamemode teampoins and player points now reset at new round
        Entity weaponbox now will be removed by correct way
        Killed ghosts now drop pumpkin
        Dead players can no longer cast spells
        Improved hit algorithm
        Removed vortex beam (cuz ugly)
        Fixed drop to bucket effect
        Fixed memory leaks
        Fixed ghost attack origin

    2.0.1
        Fixed bug when items duplicate after rejoin
        Fixed round termination problem on Linux Servers
        Updated EndRoundMessage signatures for Linux Servers

    2.0.0 Beta
        - First Release
*/

#if defined _hwn_included
  #endinput
#endif
#define _hwn_included

#pragma reqlib hwn

/*--------------------------------[ Constants ]--------------------------------*/

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

#define HWN_TITLE "Halloween Mod"
#define HWN_VERSION "6.4.2"

enum _:Hwn_PumpkinType
{
    Hwn_PumpkinType_Uninitialized = 0,
    Hwn_PumpkinType_Default,
    Hwn_PumpkinType_Crits,
    Hwn_PumpkinType_Equipment,
    Hwn_PumpkinType_Health
};

enum Hwn_GamemodeFlags (<<=1)
{
    Hwn_GamemodeFlag_None,
    Hwn_GamemodeFlag_Default = 1,
    Hwn_GamemodeFlag_RespawnPlayers,
    Hwn_GamemodeFlag_SpecialEquip
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
    Hwn_SpellFlag_Radius
};

/*--------------------------------[ Core ]--------------------------------*/

forward Hwn_Fw_ConfigLoaded();

/*--------------------------------[ Event Points ]--------------------------------*/

native Hwn_EventPoints_Add(const Float:vOrigin[3]);
native Hwn_EventPoints_GetCount();
native Hwn_EventPoints_Get(pointIdx, Float:vOrigin[3]);
native Hwn_EventPoints_GetRandom(Float:vOrigin[3]);

/*--------------------------------[ Gamemode ]--------------------------------*/

native Hwn_Gamemode_Register(const szName[], Hwn_GamemodeFlags:flags = Hwn_GamemodeFlag_None);
native Hwn_Gamemode_Activate();
native Hwn_Gamemode_DispatchWin(team);
native Hwn_Gamemode_GetCurrent();
native bool:Hwn_Gamemode_IsPlayerOnSpawn(id, bool:ignoreTeam = false);
native Hwn_Gamemode_GetHandler(const szName[]);
native Hwn_GamemodeFlags:Hwn_Gamemode_GetFlags();

forward Hwn_Gamemode_Fw_Activated(gamemode);

/*--------------------------------[ Collector Gamemode ]--------------------------------*/

native Hwn_Collector_GetPlayerPoints(id);
native Hwn_Collector_SetPlayerPoints(id, count);
native Hwn_Collector_GetTeamPoints(team);
native Hwn_Collector_SetTeamPoints(team, count);
native bool:Hwn_Collector_IsOvertime();
native bool:Hwn_Collector_ObjectiveBlocked();

forward Hwn_Collector_Fw_TeamPoints(team);
forward Hwn_Collector_Fw_PlayerPoints(id);
forward Hwn_Collector_Fw_Overtime(time);
forward Hwn_Collector_Fw_WinnerTeam(team);

/*--------------------------------[ Gifts ]--------------------------------*/
native Hwn_Gifts_AddTarget(const Float:vOrigin[3]);
native Hwn_Gifts_GetTargetCount();
native Hwn_Gifts_GetTarget(targetIdx, Float:vOrigin[3]);

forward Hwn_Gifts_Fw_GiftSpawn(id, ent);
forward Hwn_Gifts_Fw_GiftPicked(id, ent);
forward Hwn_Gifts_Fw_GiftDisappear(id, ent);

/*--------------------------------[ Spells ]--------------------------------*/

native Hwn_Spell_Register(const szName[], Hwn_SpellFlags:flags = Hwn_SpellFlag_None, const szCastCallback[]);
native Hwn_Spell_GetCount();
native Hwn_Spell_GetName(spell, szOutput[], maxlen);
native Hwn_Spell_GetHandler(const szName[]);
native Hwn_Spell_GetDictionaryKey(spell, szOutput[], maxlen);
native Hwn_SpellFlags:Hwn_Spell_GetFlags(spell);

native Hwn_Spell_GetPlayerSpell(id, &amount = 0);
native Hwn_Spell_SetPlayerSpell(id, spell, amount = 0);
native Hwn_Spell_CastPlayerSpell(id);

forward Hwn_Spell_Fw_Cast(id, spellIdx);

/*--------------------------------[ Wheel of Fate ]--------------------------------*/
native Hwn_Wof_Spell_Register(const szName[], const szInvokeCallback[] = "", const szRevokeCallback[] = "");
native Hwn_Wof_Spell_GetCount();
native Hwn_Wof_Spell_GetName(spell, szOutput[], maxlen);
native Hwn_Wof_Spell_GetHandler(const szName[]);
native Hwn_Wof_Spell_GetDictionaryKey(spell, szOutput[], maxlen);
native Hwn_Wof_Roll();
native Hwn_Wof_Abort();
native Hwn_Wof_Effect_GetCurrentSpell();
native Float:Hwn_Wof_Effect_GetStartTime();
native Float:Hwn_Wof_Effect_GetDuration();

forward Hwn_Wof_Fw_Roll_Start();
forward Hwn_Wof_Fw_Roll_End();
forward Hwn_Wof_Fw_Effect_Start(spellIdx);
forward Hwn_Wof_Fw_Effect_End(spellIdx);
forward Hwn_Wof_Fw_Effect_Invoke(id, spellIdx, Float:fEffectTime);
forward Hwn_Wof_Fw_Effect_Revoke(id, spellIdx);
forward Hwn_Wof_Fw_Abort();

/*--------------------------------[ Cosmetic ]--------------------------------*/

native Hwn_Cosmetic_GetCount();
native Hwn_Cosmetic_GetCosmetic(index);
native Hwn_Cosmetic_Register(PCosmetic:hPCosmetic);

/*--------------------------------[ Bosses ]--------------------------------*/

native Hwn_Bosses_Register(const szCEClassName[], const szName[] = "Boss");
native Hwn_Bosses_Spawn();
native Hwn_Bosses_GetCurrent(&ent = 0);
native Hwn_Bosses_GetName(bossIdx, szOutput[], maxlen);
native Hwn_Bosses_GetDictionaryKey(bossIdx, szOutput[], maxlen);

forward Hwn_Bosses_Fw_BossSpawn(ent, Float:fLifeTime);
forward Hwn_Bosses_Fw_BossKill(ent);
forward Hwn_Bosses_Fw_BossEscape(ent);
forward Hwn_Bosses_Fw_BossTeleport(ent, handler);
forward Hwn_Bosses_Fw_Winner(id, damage);

/*--------------------------------[ Player Equipment ]--------------------------------*/

native Hwn_PEquipment_ShowMenu(id);
native Hwn_PEquipment_Equip(id);
native Hwn_PEquipment_GiveHealth(id, amount);
native Hwn_PEquipment_GiveArmor(id, amount);
native Hwn_PEquipment_GiveAmmo(id, amount = 1);

forward Hwn_PEquipment_Fw_Changed(id);

/*--------------------------------[ Menu ]--------------------------------*/

native Hwn_Menu_Open(id);
native Hwn_Menu_AddItem(const szTitle[], const szCallback[]);

/*--------------------------------[ Crits ]--------------------------------*/
native Hwn_Crits_Get(id);
native Hwn_Crits_Set(id, bool:value);
