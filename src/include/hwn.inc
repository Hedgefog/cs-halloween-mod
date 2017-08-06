/*
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

#define HWN_COLOR_PURPLE_F 			120.0, 0.0, 200.0
#define HWN_COLOR_PURPLE			120, 0, 200
#define HWN_COLOR_RED_F 			255.0, 0.0, 0.0
#define HWN_COLOR_YELLOW_F 			255.0, 200.0, 0.0
#define HWN_COLOR_GREEN_DARK_F 		47.0, 95.0, 15.0
#define HWN_COLOR_GREEN_DARK 		47, 95, 15

#define HWN_TITLE "Halloween Mod"
#define HWN_VERSION "2.3.1"

enum Hwn_GamemodeFlags (<<=1)
{
	Hwn_GamemodeFlag_None,
	Hwn_GamemodeFlag_Default = 1,
	Hwn_GamemodeFlag_RespawnPlayers,
	Hwn_GamemodeFlag_SpecialEquip
};

/*--------------------------------[ Gamemode ]--------------------------------*/

native Hwn_Gamemode_Register(const szName[], Hwn_GamemodeFlags:flags = Hwn_GamemodeFlag_None);
native Hwn_Gamemode_Activate();
native Hwn_Gamemode_DispatchWin(team);
native Hwn_Gamemode_GetCurrent();
native bool:Hwn_Gamemode_IsPlayerOnSpawn(id);
native Hwn_Gamemode_GetHandler(const szName[]);

forward Hwn_Gamemode_Fw_NewRound();
forward Hwn_Gamemode_Fw_RoundStart();
forward Hwn_Gamemode_Fw_RoundEnd();

/*--------------------------------[ Default Gamemode ]--------------------------------*/

native bool:Hwn_Gamemode_FindEventPoint(Float:vOrigin[3]);

/*--------------------------------[ Collector Gamemode ]--------------------------------*/

native Hwn_Collector_GetPlayerPoints(id);
native Hwn_Collector_SetPlayerPoints(id, count);
native Hwn_Collector_GetTeamPoints(team);
native Hwn_Collector_SetTeamPoints(team, count);

forward Hwn_Collector_Fw_TeamPoints(team);
forward Hwn_Collector_Fw_PlayerPoints(id);

/*--------------------------------[ Spells ]--------------------------------*/

native Hwn_Spell_Register(const szName[], const szCastCallback[]);
native Hwn_Spell_GetCount();
native Hwn_Spell_GetName(spell, szName[], maxlen);

native Hwn_Spell_GetPlayerSpell(id, &amount = 0);
native Hwn_Spell_SetPlayerSpell(id, spell, amount = 0);
native Hwn_Spell_CastPlayerSpell(id);

forward Hwn_Spell_Fw_Cast(id, spellIdx);

/*--------------------------------[ Cosmetic ]--------------------------------*/

native Hwn_Cosmetic_GetCount();
native Hwn_Cosmetic_GetCosmetic(index);

/*--------------------------------[ Bosses ]--------------------------------*/

native Hwn_Bosses_RegisterBoss(const szCEClassName[]);

forward Hwn_Bosses_Fw_BossSpawn(ent);
forward Hwn_Bosses_Fw_BossKill(ent);
forward Hwn_Bosses_Fw_BossEscape(ent);
forward Hwn_Bosses_Fw_BossTeleport(ent, handler);
forward Hwn_Bosses_Fw_Winner(id);

/*--------------------------------[ Player Equipment ]--------------------------------*/

native Hwn_PEquipment_ShowMenu(id);
native Hwn_PEquipment_Equip(id);

forward Hwn_PEquipment_Fw_Changed(id);

/*--------------------------------[ Menu ]--------------------------------*/

native Hwn_Menu_AddItem(const szTitle[], const szCallback[]);
