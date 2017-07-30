#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define CSW_SHIELD	2

#define AMMOTYPE_COUNT 15

stock const WeaponMaxBPAmmo[] =
{
	-1, 52, -1, 90, 1, 32, 1, 100,
	90, 1, 120, 100, 100, 90,
	90, 90, 100, 120, 30, 120, 200, 
	32, 90, 120, 90, 2, 35, 90, 
	90, -1, 100
};

stock const WeaponEntityNames[][] =
{
	"", "weapon_p228", "weapon_shield", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90"
};

stock const WeaponNames[][] =
{
	"None", "P228 Compact", "Tactical Shield", "SSG-08", "Hegrenade", "XM1014 M4", "C4", "MAC-10", 
	"AUG", "Smokegreande", "Dual Elites", "FiveseveN", "UMP 45", "SG-550", 
	"Galil", "Famas", "USP", "Glock 18C", "AWP", "MP5 Navy", "M249",
	"M3 Super 90", "M4A1", "TMP", "G3SG1", "Flashbang", "Desert Eagle", "SG-552", 
	"AK-47", "Knife", "P90"
};

stock const WeaponModels[][] =
{
	"", "models/w_p228.mdl", "models/w_shield.mdl", "models/w_scout.mdl", "models/w_hegrenade.mdl", "models/w_xm1014.mdl", "models/w_c4.mdl", "models/w_mac10.mdl",
	"models/w_aug.mdl", "models/w_smokegrenade.mdl", "models/w_elite.mdl", "models/w_fiveseven.mdl", "models/w_ump45.mdl", "models/w_sg550.mdl",
	"models/w_galil.mdl", "models/w_famas.mdl", "models/w_usp.mdl", "models/w_glock18.mdl", "models/w_awp.mdl", "models/w_mp5.mdl", "models/w_m249.mdl",
	"models/w_m3.mdl", "models/w_m4a1.mdl", "models/w_tmp.mdl", "models/w_g3sg1.mdl", "models/w_flashbang.mdl", "models/w_deagle.mdl", "models/w_sg552.mdl",
	"models/w_ak47.mdl", "models/w_knife.mdl", "models/w_p90.mdl"
};

stock const WeaponAmmo[] =
{
	-1, 9, -1, 2, 12, 5, 14, 6,
	4, 13, 10, 7, 6,  4, 
	4, 4, 6, 10, 1, 10, 3, 
	5, 4, 10, 2, 11, 8, 4, 
	2, -1, 7
};

stock const AmmoEntityNames[AMMOTYPE_COUNT][] =
{
	"", "ammo_338magnum", "ammo_762nato", "ammo_556natobox",
	"ammo_556nato", "ammo_buckshot", "ammo_45acp", "ammo_57mm", 
	"ammo_50ae", "ammo_357sig", "ammo_9mm", "", 
	"", "", ""
};