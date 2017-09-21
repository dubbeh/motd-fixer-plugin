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

#define PLUGIN_VERSION 		"1.06"
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
char g_szBaseURL[128] = "https://motd.dubbeh.net";
char g_szServerToken[64] = "";
char g_szConfigFile[] = "sourcemod/plugin.motdf.cfg";

ConVar g_cVarEnable = null;
ConVar g_cVarLogging = null;
ConVar g_cVarValidateType = null;
ConVar g_cVarAutoRegister = null;

bool g_bUpdaterAvail = false;

EngineVersion g_EngineVersion = Engine_Unknown;
bool g_bDisabledHTMLMOTD[MAXPLAYERS + 1];


#include "motdf/config.sp"

MOTDConfig g_Config;

#include "motdf/helpers.sp"
#include "motdf/natives.sp"
#include "motdf/commands.sp"


public void OnPluginStart()
{
	CreateConVar("motdf_version", PLUGIN_VERSION, "MOTD Fixer version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cVarEnable = CreateConVar("motdf_enable", "1.0", "Enable MOTD Fixer", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cVarLogging = CreateConVar("motdf_logging", "1.0", "Enable MOTD Fixer logging", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cVarValidateType = CreateConVar("motdf_validatetype", "1.0", "0 = IP | 1 = Token authentication", FCVAR_NONE, true, 0.0, true, 1.0);
	g_cVarAutoRegister = CreateConVar("motdf_autoregister", "1.0", "Auto-register the server on the first call to MOTDF_ShowMOTDPanel", FCVAR_NONE, true, 0.0, true, 1.0);
	
	LoadTranslations("motdf.phrases");
	
	RegAdminCmd("motdf_register", Command_MOTDRegisterServer, ADMFLAG_RCON, "Register the current server to use the MOTD redirect service.");
	RegAdminCmd("motdf_serverip", Command_MOTDGetServerIP, ADMFLAG_RCON, "Get the server IP that's recieved by the PHP script.");

	// Auto create the config file, if it doesn't exist
	AutoExecConfig(true, "plugin.motdf", "sourcemod");
	ServerCommand("exec %s", g_szConfigFile);
	
	for (int iIndex = 0; iIndex <= MAXPLAYERS; iIndex++) {
		g_bDisabledHTMLMOTD[iIndex] = false;
	}
	
	g_EngineVersion = GetEngineVersion();
	
	if (g_EngineVersion != Engine_CSGO)
	{
		MOTDFLogMessage("This plugin is currently for CS:GO only - Fixes the MOTD loading. Can be removed for other mods.");
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
	
	if (!g_bUpdaterAvail) {
		MOTDFLogMessage("Unable to find Updater. Please install it from https://forums.alliedmods.net/showthread.php?t=169095");
	} else {
		MOTDFLogMessage("Found plugin Updater.");
	}
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
	// Execute the config file
	ServerCommand("exec %s", g_szConfigFile);
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

public void OnClientPostAdminCheck(int iClient)
{
	g_bDisabledHTMLMOTD[iClient] = false;
	
	// Check if cl_disablehtmlmotd enabled
	QueryClientConVar(iClient, "cl_disablehtmlmotd", CheckDisabledHTMLMOTD);
}

// Thanks to psychonic for the cl_disablehtmlmotd query code - modified it a little
public int CheckDisabledHTMLMOTD(QueryCookie qcCookie, int iClient, ConVarQueryResult cqrResult, const char[] szCvarName, const char[] szCvarValue)
{
	if (cqrResult == ConVarQuery_Okay && StringToInt(szCvarValue) == 1)
	{
		g_bDisabledHTMLMOTD[iClient] = true;
		PrintToChat(iClient, "%T", "Disabled HTML MOTD On", LANG_SERVER);
	}
}
