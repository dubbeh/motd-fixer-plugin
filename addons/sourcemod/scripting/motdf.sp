/*
 * MOTD Fixer
 *
 * Fixes the MOTD loading of data under Counter-Strike : Global Offensive
 *
 * Coded by dubbeh - www.dubbeh.net
 *
 * Licensed under the GPLv3
 *
 */


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#include <smjansson>
#include <SteamWorks>
#include <updater>
#define REQUIRE_EXTENSIONS
#define REQUIRE_PLUGIN


#define PLUGIN_VERSION 		"1.00 FINAL"
#define MAX_MOTD_URL_SIZE 	192
#define VALIDATE_IP			0
#define VALIDATE_TOKEN		1

// Thanks to GoD-Tony for this macro
#define STEAMWORKS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SteamWorks_IsLoaded") == FeatureStatus_Available)
#define SMJANSSON_AVAILABLE() (GetFeatureStatus(FeatureType_Native, "json_object") == FeatureStatus_Available)

public Plugin myinfo = 
{
	name = "MOTD Fixer",
	author = "dubbeh",
	description = "Fixes the MOTD loading under CS:GO",
	version = PLUGIN_VERSION,
	url = "https://dubbeh.net"
};

char g_szUpdateURL[] = "https://update.dubbeh.net/motdf/motdf.txt";
char g_szRegisterURL[128] = "https://motd.dubbeh.net/register.php";
char g_szRedirectURL[128] = "https://motd.dubbeh.net/redirect.php";
char g_szServerToken[64] = "";

ConVar g_cVarEnable = null;
ConVar g_cVarLogging = null;
ConVar g_cVarValidateType = null;

bool g_bUpdaterAvail = false;

#include "motdf/config.sp"

MOTDConfig g_Config;

#include "motdf/helpers.sp"
#include "motdf/natives.sp"
#include "motdf/register.sp"


public void OnPluginStart()
{
	EngineVersion ev = GetEngineVersion();
	
	if (ev == Engine_CSGO) {
		CreateConVar("motdf_version", PLUGIN_VERSION, "MOTD Fixer version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
		g_cVarEnable = CreateConVar("motdf_enable", "1.0", "Enable MOTD Fixer", 0, true, 0.0, true, 1.0);
		g_cVarLogging = CreateConVar("motdf_logging", "1.0", "Enable MOTD Fixer logging", 0, true, 0.0, true, 1.0);
		g_cVarValidateType = CreateConVar("modtf_validatetype","1.0", "0 = IP | 1 = Token authentication", 0, true, 0.0, true, 1.0);

		RegAdminCmd("motdf_register", Command_MOTDRegisterServer, ADMFLAG_RCON, "Register the current server to use the MOTD redirect service.");
	} else {
		SetFailState("This plugin is for CS:GO only. Fixes the MOTD loading.");
	}
}

public void OnAllPluginsLoaded()
{
	if (!STEAMWORKS_AVAILABLE()) {
		MOTDFLogMessage("Unable to find SteamWorks. Please install it from https://forums.alliedmods.net/showthread.php?t=229556");
	} else {
		MOTDFLogMessage("Found extension SteamWorks.");
	}

	if (!SMJANSSON_AVAILABLE()) {
		MOTDFLogMessage("Unable to find SMJansson. Please install it from https://forums.alliedmods.net/showthread.php?t=184604");
	} else {
		MOTDFLogMessage("Found extension SMJansson.");
	}

	g_bUpdaterAvail = LibraryExists("updater");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("motdf");
	CreateNative("MOTDF_ShowMOTDPanel", Native_MOTDF_ShowMOTDPanel);
	return APLRes_Success;
}

public void OnMapStart()
{
	g_Config.Load();
	if (g_bUpdaterAvail)
		Updater_AddPlugin(g_szUpdateURL);
}

public void OnConfigsExecuted()
{
	// Apply fix for the latest CS:GO Update that broken MOTD functionality
	ServerCommand("sm_cvar sv_disable_motd 0");
}

public void OnLibraryAdded(const char[] name)
{
	if (LibraryExists("updater"))
		g_bUpdaterAvail = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "updater"))
		g_bUpdaterAvail = false;
}