/*************************************************************
*															 *
*						Warden Menu							 *
*						Author: Hypr						 *
*															 *
*************************************************************/

#pragma semicolon 1

#include <sourcemod>
#include <colorvariables>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#define REQUIRE_PLUGIN
#include <eskojbwarden>
#undef REQUIRE_PLUGIN

#define VERSION "1.1 (005)"

#define CHOICE1 "#choice1"
#define CHOICE2 "#choice2"
#define CHOICE3 "#choice3"
#define CHOICE4 "#choice4"
#define CHOICE5 "#choice5"
#define CHOICE6 "#choice6"
#define CHOICE7 "#choice7"
#define SPACER "#spacer"
#define CHOICE8 "#choice8"

bool IsGameActive = false;
char cmenuPrefix[] = "[{blue}WardenMenu{default}]";

// Current game
int hnsActive = 0;
int freedayActive = 0;
int wardayActive = 0;
int gravActive = 0;

// Track number of games played
int hnsTimes = 0;
int freedayTimes = 0;
int warTimes = 0;
int gravTimes = 0;

// ## CVars ##
ConVar cvVersion;
ConVar cvAutoOpen;
// Convars to add different menu entries
ConVar cvHnS;
ConVar cvHnSGod;
ConVar cvHnSTimes;
ConVar cvFreeday;
ConVar cvFreedayTimes;
ConVar cvWarday;
ConVar cvWardayTimes;
ConVar cvGrav;
ConVar cvGravTeam;
ConVar cvGravStrength;
ConVar cvGravTimes;
ConVar cvNoblock;
ConVar cvNoblockStandard;
ConVar cvEnableWeapons;

ConVar noblock;

public Plugin myinfo = {
	name = "[CS:GO] Warden Menu",
	author = "Hypr",
	description = "Gives wardens access to a special menu",
	version = VERSION,
	url = "https://condolent.xyz"
}

public OnPluginStart() {
	
	LoadTranslations("cmenu.phrases.txt");
	SetGlobalTransTarget(LANG_SERVER);
	
	AutoExecConfig(true, "cmenu");
	
	//var = CreateConVar("cvar_name", "default_value", "description", cvarFlag, true, min, true, max);
	cvVersion = CreateConVar("sm_cmenu_version", VERSION, "Current version running. Debugging purposes only!", FCVAR_DONTRECORD|FCVAR_NOTIFY); // Not visible in config
	cvHnS = CreateConVar("sm_cmenu_hns", "1", "Add an option for Hide and Seek in the menu?\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvHnSGod = CreateConVar("sm_cmenu_hns_godmode", "1", "Makes CT's invulnerable against attacks from T's during HnS to prevent rebels.\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvHnSTimes = CreateConVar("sm_cmenu_hns_rounds", "2", "How many times is HnS allowed per map?\nSet to 0 for unlimited.", FCVAR_NOTIFY);
	cvFreeday = CreateConVar("sm_cmenu_freeday", "1", "Add an option for a freeday in the menu?\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvFreedayTimes = CreateConVar("sm_cmenu_freeday_rounds", "2", "How many times is a Freeday allowed per map?\nSet to 0 for unlimited.", FCVAR_NOTIFY);
	cvWarday = CreateConVar("sm_cmenu_warday", "1", "Add an option for Warday in the menu?\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvWardayTimes = CreateConVar("sm_cmenu_warday_rounds", "1", "How many times is a Warday allowed per map?\nSet to 0 for unlimited.", FCVAR_NOTIFY);
	cvGrav = CreateConVar("sm_cmenu_gravity", "1", "Add an option for a gravity freeday in the menu?\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvGravTeam = CreateConVar("sm_cmenu_gravity_team", "2", "Which team should get a special gravity on Gravity Freedays?\n0 = All teams.\n1 = Counter-Terrorists.\n2 = Terorrists.", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	cvGravStrength = CreateConVar("sm_cmenu_gravity_strength", "0.5", "What should the gravity be set to on Gravity Freedays?", FCVAR_NOTIFY);
	cvGravTimes = CreateConVar("sm_cmenu_gravity_rounds", "1", "How many times is a Gravity Freeday allowed per map?\nSet to 0 for unlimited.", FCVAR_NOTIFY);
	cvNoblock = CreateConVar("sm_cmenu_noblock", "1", "Add an option for toggling noblock in the menu?\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvNoblockStandard = CreateConVar("sm_cmenu_noblock_standard", "1", "What should the noblock rules be as default on start of each round?\nThis should have the same value as your mp_solid_teammates cvar in server.cfg.\n1 = Solid teammates.\n0 = No block.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvAutoOpen = CreateConVar("sm_cmenu_auto_open", "1", "Automatically open the menu when a user becomes warden?\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvEnableWeapons = CreateConVar("sm_cmenu_weapons", "1", "Add an option for giving the warden a list of weapons via the menu?\n0 = Disable.\n1 = Enable.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	noblock = FindConVar("mp_solid_teammates");
	
	RegAdminCmd("sm_abortgames", sm_abortgames, ADMFLAG_BAN);
	
	RegConsoleCmd("sm_cmenu", sm_cmenu);
	RegConsoleCmd("sm_wmenu", sm_cmenu);
	RegConsoleCmd("sm_noblock", sm_noblock);
	RegConsoleCmd("sm_days", sm_days);
	
	//HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	
	for(int i = 1; i < MaxClients; i++) {
		if(!IsClientInGame(i)) 
			continue;
		SDKHook(i, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}
	
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(EJBW_IsClientWarden(client)) {
		abortGames();
	}
}

/*public void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(hnsActive == 1 && GetClientTeam(client) == CS_TEAM_CT && cvHnSGod.IntValue == 1) {
		if(!IsFakeClient(attacker) && GetClientTeam(attacker) == CS_TEAM_T) {
			event.Cancel();
			CPrintToChat(attacker, "%s %t", cmenuPrefix, "No Rebel HnS");
		}
	}
}*/

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
	if(hnsActive == 1 && GetClientTeam(victim) == CS_TEAM_CT && cvHnSGod.IntValue == 1) {
		if(!IsFakeClient(inflictor) && GetClientTeam(inflictor) == CS_TEAM_T) {
			CPrintToChat(inflictor, "%s %t", cmenuPrefix, "No Rebel HnS");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	abortGames();
	SetConVarInt(noblock, cvNoblockStandard.IntValue, true, true);
}

public void OnMapStart() {
	abortGames();
}

public void EJBW_OnWardenCreatedByUser(int client) {
	CPrintToChat(client, "%s %t", cmenuPrefix, "Available to open menu");
	if(cvAutoOpen.IntValue == 1) {
		openMenu(client);
	} else {
		PrintToServer("Skipping auto open since it's disabled in config.");
	}
}

public Action sm_cmenu(int client, int args) {
	
	if(IsClientInGame(client) && !IsFakeClient(client)) {
		if(GetClientTeam(client) == CS_TEAM_CT) {
			if(IsPlayerAlive(client)) {
				if(EJBW_IsClientWarden(client)) {
					
					openMenu(client);
					
				} else {
					error(client, 0);
				}
			} else {
				error(client, 1);
			}
		} else {
			error(client, 2);
		}
	}
	
	return Plugin_Handled;
}

public Action sm_abortgames(int client, int args) {
	
	if(IsGameActive) {
		CPrintToChatAll("%s %t", cmenuPrefix, "Admin Aborted", client);
		abortGames();
	} else {
		CPrintToChat(client, "%s %t", cmenuPrefix, "Admin Abort Denied");
	}
	
	return Plugin_Handled;
}

public Action sm_noblock(int client, int args) {
	if(IsClientInGame(client) && !IsFakeClient(client)) {
		if(GetClientTeam(client) == CS_TEAM_CT) {
			if(IsPlayerAlive(client)) {
				if(EJBW_IsClientWarden(client)) {
					toggleNoblock();
				} else {
					error(client, 0);
				}
			} else {
				error(client, 1);
			}
		} else {
			error(client, 2);
		}
	}
	
	return Plugin_Handled;
}

public Action sm_days(int client, int args) {
	
	if(!IsFakeClient(client) && IsClientInGame(client) && GetClientTeam(client) == CS_TEAM_CT) {
		if(EJBW_IsClientWarden(client)) {
			openDaysMenu(client);
		} else {
			error(client, 0);
		}
	} else {
		CPrintToChat(client, "%s %t", cmenuPrefix, "Neither alive or ct");
	}
	
	return Plugin_Handled;
}

public void openMenu(int client) {
	Menu menu = new Menu(WardenMenuHandler, MENU_ACTIONS_ALL);
	
	char title[64];
	Format(title, sizeof(title), "%t", "Warden Menu Title");
	
	menu.SetTitle(title);
	if(cvEnableWeapons.IntValue == 1) {
		menu.AddItem(CHOICE1, "Choice 1");
	}
	menu.AddItem(CHOICE2, "Choice 2");
	if(cvNoblock.IntValue == 1) {
		menu.AddItem(CHOICE3, "Choice 3");
	}
	menu.AddItem(CHOICE8, "Choice 8");
	menu.Display(client, 20);
}

public int WardenMenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch(action) {
		case MenuAction_Start:{} // Displaying menu to client
		case MenuAction_Display:
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%t", "Warden Menu Title");
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
		}
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			if(StrEqual(info, CHOICE1)) {
				openWeaponsMenu(client);
			}
			if(StrEqual(info, CHOICE2)) {
				openDaysMenu(client);
			}
			if(StrEqual(info, CHOICE3)) {
				toggleNoblock();
			}
			if(StrEqual(info, CHOICE8)) {
				FakeClientCommand(client, "sm_uw");
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
			
			if(StrEqual(info, CHOICE1)) {
				return ITEMDRAW_DEFAULT;
			} else if(StrEqual(info, CHOICE2)) {
				return ITEMDRAW_DEFAULT;
			} else if(StrEqual(info, CHOICE8)) {
				return ITEMDRAW_DEFAULT;
			} else if(StrEqual(info, CHOICE3)) {
				return ITEMDRAW_DEFAULT;
			} else { 
				return style;
			}
		}
		case MenuAction_DisplayItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			char display[64];
			
			if(StrEqual(info, CHOICE1)) {
				Format(display, sizeof(display), "%t", "Weapons Menu Entry");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE2)) {
				Format(display, sizeof(display), "%t", "Days Entry");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE3)) {
				Format(display, sizeof(display), "%t", "Toggle Noblock Entry");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE8)) {
				Format(display, sizeof(display), "%t", "Leave Warden");
				return RedrawMenuItem(display);
			}
		}
	}
	
	return 0;
}

public void openDaysMenu(int client) {
	Menu menu = new Menu(DaysMenuHandler, MENU_ACTIONS_ALL);
	
	char title[64];
	Format(title, sizeof(title), "%t", "Days Menu Title");
	
	menu.SetTitle(title);
	if(cvFreeday.IntValue == 1) {
		menu.AddItem(CHOICE1, "Choice 1");
	}
	if(cvHnS.IntValue == 1) {
		menu.AddItem(CHOICE2, "Choice 2");
	}
	if(cvWarday.IntValue == 1) {
		menu.AddItem(CHOICE3, "Choice 3");
	}
	if(cvGrav.IntValue == 1) {
		menu.AddItem(CHOICE4, "Choice 4");
	}
	menu.AddItem(SPACER, "Spacer");
	menu.AddItem(CHOICE8, "Choice 8");
	menu.ExitBackButton = true;
	menu.Display(client, 20);
}

public int DaysMenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch(action) {
		case MenuAction_Start:
		{
			// Displaying menu to client
		}
		case MenuAction_Display:
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%t", "Days Menu Title");
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
		}
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			if(!IsGameActive) {
				if(StrEqual(info, CHOICE1)) {
					initFreeday(client);
				}
				if(StrEqual(info, CHOICE2)) {
					initHns(client);
				}
				if(StrEqual(info, CHOICE3)) {
					initWarday(client);
				}
				if(StrEqual(info, CHOICE4)) {
					initGrav(client);
				}
			} else {
				if(StrEqual(info, CHOICE8)) {
					abortGames();
				} else if(StrEqual(info, CHOICE1) || StrEqual(info, CHOICE2) || StrEqual(info, CHOICE3) || StrEqual(info, CHOICE4)) {
					CPrintToChat(client, "%s %t", cmenuPrefix, "Cannot Exec Game");
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
			
			// Disable all if a game is active!
			if(IsGameActive) {
				if(StrEqual(info, CHOICE1)) {
					return ITEMDRAW_DISABLED;
				} else if(StrEqual(info, CHOICE2)) {
					return ITEMDRAW_DISABLED;
				} else if(StrEqual(info, CHOICE3)) {
					return ITEMDRAW_DISABLED;
				} else if(StrEqual(info, CHOICE4)) {
					return ITEMDRAW_DISABLED;
				} else if(StrEqual(info, CHOICE8)) {
					return ITEMDRAW_DEFAULT;
				} else if(StrEqual(info, SPACER)) {
					return ITEMDRAW_SPACER;
				} else {
					return style;
				}
			} else {
				if(StrEqual(info, CHOICE8)) {
					return ITEMDRAW_DISABLED;
				} else if(StrEqual(info, SPACER)) {
					return ITEMDRAW_SPACER;
				} else {
					return style;
				}
			}
		}
		case MenuAction_DisplayItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			char display[64];
			
			if(StrEqual(info, CHOICE1)) {
				Format(display, sizeof(display), "%t", "Choice 1");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE2)) {
				Format(display, sizeof(display), "%t", "Choice 2");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE3)) {
				Format(display, sizeof(display), "%t", "Choice 3");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE4)) {
				Format(display, sizeof(display), "%t", "Choice 4");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE8)) {
				Format(display, sizeof(display), "%t", "Choice 8");
				return RedrawMenuItem(display);
			}
		}
	}
	
	return 0;
}

public void openWeaponsMenu(int client) {
	Menu menu = new Menu(weaponsMenuHandler, MENU_ACTIONS_ALL);
	
	char title[64];
	Format(title, sizeof(title), "%t", "Weapons Menu Title");
	
	menu.SetTitle(title);
	menu.AddItem(CHOICE1, "Choice 1"); // AK47
	menu.AddItem(CHOICE2, "Choice 2"); // M4A1-S
	menu.AddItem(CHOICE3, "Choice 3"); // M4A4
	menu.AddItem(CHOICE4, "Choice 4"); // AWP
	menu.AddItem(CHOICE5, "Choice 5"); // P90
	menu.AddItem(CHOICE6, "Choice 6"); // Negev
	menu.AddItem(CHOICE7, "Choice 7"); // Scout
	menu.ExitBackButton = true;
	menu.Display(client, 20);
}

public int weaponsMenuHandler(Menu menu, MenuAction action, int client, int param2) {
	
	switch(action) {
		case MenuAction_Start:{} // Opening the menu to client
		case MenuAction_Display:
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%t", "Weapons Menu Title");
			Panel panel = view_as<Panel>(param2);
			panel.SetTitle(buffer);
		}
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if(StrEqual(info, CHOICE1)) {
				if(!IsFakeClient(client) && IsClientInGame(client)) {
					GivePlayerItem(client, "weapon_ak47");
				}
			}
			if(StrEqual(info, CHOICE2)) {
				if(!IsFakeClient(client) && IsClientInGame(client)) {
					GivePlayerItem(client, "weapon_m4a1_silencer");
				}
			}
			if(StrEqual(info, CHOICE3)) {
				if(!IsFakeClient(client) && IsClientInGame(client)) {
					GivePlayerItem(client, "weapon_m4a1");
				}
			}
			if(StrEqual(info, CHOICE4)) {
				if(!IsFakeClient(client) && IsClientInGame(client)) {
					GivePlayerItem(client, "weapon_awp");
				}
			}
			if(StrEqual(info, CHOICE5)) {
				if(!IsFakeClient(client) && IsClientInGame(client)) {
					GivePlayerItem(client, "weapon_p90");
				}
			}
			if(StrEqual(info, CHOICE6)) {
				if(!IsFakeClient(client) && IsClientInGame(client)) {
					GivePlayerItem(client, "weapon_negev");
				}
			}
			if(StrEqual(info, CHOICE7)) {
				if(!IsFakeClient(client) && IsClientInGame(client)) {
					GivePlayerItem(client, "weapon_ssg08");
				}
			}
		}
		case MenuAction_End:{delete menu;}
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
			
			if(StrEqual(info, CHOICE1) || StrEqual(info, CHOICE2) || StrEqual(info, CHOICE3) || StrEqual(info, CHOICE4) || StrEqual(info, CHOICE5) || StrEqual(info, CHOICE6) || StrEqual(info, CHOICE7)) {
				return ITEMDRAW_DEFAULT;
			} else {
				return style;
			}
		}
		case MenuAction_DisplayItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			char display[64];
			
			if(StrEqual(info, CHOICE1)) {
				Format(display, sizeof(display), "AK47");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE2)) {
				Format(display, sizeof(display), "M4A1-S");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE3)) {
				Format(display, sizeof(display), "M4A4");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE4)) {
				Format(display, sizeof(display), "AWP");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE5)) {
				Format(display, sizeof(display), "P90");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE6)) {
				Format(display, sizeof(display), "Negev");
				return RedrawMenuItem(display);
			}
			if(StrEqual(info, CHOICE7)) {
				Format(display, sizeof(display), "Scout");
				return RedrawMenuItem(display);
			}
		}
	}
	
	return 0;
}

public void abortGames() {
	if(IsGameActive) {
		// Reset
		IsGameActive = false;
		hnsActive = 0;
		wardayActive = 0;
		freedayActive = 0;
		gravActive = 0;
		for(new i = 1; i < MaxClients; i++) {
			SetEntityGravity(i, 1.0);
		}
	} else {
		PrintToServer("%t", "Failed to abort Server");
	}
}

public void initHns(int client) {
	if(cvHnSTimes.IntValue == 0) {
		PrintHintTextToAll("%t", "HnS Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "HnS Begun");
		hnsActive = 1;
		IsGameActive = true;
	} else if(cvHnSTimes.IntValue != 0 && hnsTimes >= cvHnSTimes.IntValue) {
		
		CPrintToChat(client, "%s %t", cmenuPrefix, "Too many hns", hnsTimes, cvHnSTimes.IntValue);
		
	} else if(cvHnSTimes.IntValue != 0 && hnsTimes < cvHnSTimes.IntValue) {
		PrintHintTextToAll("%t", "HnS Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "HnS Begun");
		hnsActive = 1;
		IsGameActive = true;
		hnsTimes++;
	}
}

public void initFreeday(int client) {
	
	/*
	* What to do to the server here??
	* Probably nothing that needs to be done..
	*/
	
	if(cvFreedayTimes.IntValue == 0) {
		PrintHintTextToAll("%t", "Freeday Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "Freeday Begun");
		freedayActive = 1;
		IsGameActive = true;
	} else if(cvFreedayTimes.IntValue != 0 && freedayTimes >= cvFreedayTimes.IntValue) {
		CPrintToChat(client, "%s %t", cmenuPrefix, "Too many freedays", freedayTimes, cvFreedayTimes.IntValue);
	} else if(cvFreedayTimes.IntValue != 0 && freedayTimes < cvFreedayTimes.IntValue) {
		PrintHintTextToAll("%t", "Freeday Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "Freeday Begun");
		freedayActive = 1;
		IsGameActive = true;
		freedayTimes++;
	}
}

public void initWarday(int client) {
	
	/*
	* Same here. Anything to do to the server?
	*/
	
	if(cvWardayTimes.IntValue == 0) {
		PrintHintTextToAll("%t", "Warday Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "Warday Begun");
		wardayActive = 1;
		IsGameActive = true;
	} else if(cvWardayTimes.IntValue != 0 && warTimes >= cvWardayTimes.IntValue) {
		CPrintToChat(client, "%s %t", "Too many wardays", warTimes, cvWardayTimes.IntValue);
	} else if(cvWardayTimes.IntValue != 0 && warTimes < cvWardayTimes.IntValue) {
		PrintHintTextToAll("%t", "Warday Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "Warday Begun");
		wardayActive = 1;
		IsGameActive = true;
		warTimes++;
	}
	
}

public void initGrav(int client) {
	if(cvGravTimes.IntValue == 0) {
		PrintHintTextToAll("%t", "Gravday Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "Gravday Begun");
		gravActive = 1;
		IsGameActive = true;
		
		for(new i = 1; i < MaxClients; i++) {
			if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_T) {
				SetEntityGravity(i, 2.5);
			}
		}
	} else if(cvGravTimes.IntValue != 0 && gravTimes >= cvGravTimes.IntValue) {
		CPrintToChat(client, "%s %t", cmenuPrefix, "Too many gravdays", gravTimes, cvGravTimes.IntValue);
	} else if(cvGravTimes.IntValue != 0 && gravTimes < cvGravTimes.IntValue) {
		PrintHintTextToAll("%t", "Gravday Begun");
		CPrintToChatAll("%s %t", cmenuPrefix, "Gravday Begun");
		gravActive = 1;
		IsGameActive = true;
		
		for(new i = 1; i < MaxClients; i++) {
			if(cvGravTeam.IntValue == 0) {
				if(IsClientInGame(i) && !IsFakeClient(i)) {
					SetEntityGravity(i, cvGravStrength.FloatValue);
				}
			} else if(cvGravTeam.IntValue == 1) {
				if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_CT) {
					SetEntityGravity(i, cvGravStrength.FloatValue);
				}
			} else if(cvGravTeam.IntValue == 2) {
				if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == CS_TEAM_T) {
					SetEntityGravity(i, cvGravStrength.FloatValue);
				}
			}
		}
		
	}
}

public void toggleNoblock() {
	if(noblock.IntValue == 1) {
		CPrintToChatAll("%s %t", cmenuPrefix, "Noblock on");
		SetConVarInt(noblock, 0, true, true);
	} else if(noblock.IntValue == 0) {
		CPrintToChatAll("%s %t", cmenuPrefix, "Noblock off");
		SetConVarInt(noblock, 1, true, true);
	}
}

public void error(int client, int errorCode) {
	if(errorCode == 0) {
		CPrintToChat(client, "%s %t", cmenuPrefix, "Not Warden");
	}
	if(errorCode == 1) {
		CPrintToChat(client, "%s %t", cmenuPrefix, "Not Alive");
	}
	if(errorCode == 2) {
		CPrintToChat(client, "%s %t", cmenuPrefix, "Not CT");
	}
}