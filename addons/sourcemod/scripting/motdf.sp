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

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <SteamWorks>
#include <smjansson>

#pragma newdecls required

#define PLUGIN_VERSION 		"1.00 BETA 1"
#define MAX_MOTD_URL_SIZE 	192
#define VALIDATE_IP			0
#define VALIDATE_TOKEN		1

public Plugin myinfo = 
{
	name = "MOTD Fixer",
	author = "dubbeh",
	description = "Fixes the MOTD loading under CS:GO",
	version = PLUGIN_VERSION,
	url = "https://dubbeh.net"
};

char g_szRegisterURL[128] = "https://motd.dubbeh.net/register.php";
char g_szRedirectURL[128] = "https://motd.dubbeh.net/redirect.php";
char g_szServerToken[64] = "";

ConVar g_cVarEnable = null;
ConVar g_cVarLogging = null;
ConVar g_cVarValidateType = null;

// Thanks to GoD-Tony for this macro
#define STEAMWORKS_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "SteamWorks_IsLoaded") == FeatureStatus_Available)
#define SMJANSSON_AVAILABLE()	(GetFeatureStatus(FeatureType_Native, "json_object") == FeatureStatus_Available)

#include "motdf/config.sp"

MOTDConfig cfg;

#include "motdf/helpers.sp"
#include "motdf/natives.sp"
#include "motdf/register.sp"


public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin is for CS:GO only. Fixes the MOTD loading.");	
	}
	
	CreateConVar("motdf_version", PLUGIN_VERSION, "MOTD Fixer version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cVarEnable = CreateConVar("motdf_enable", "1.0", "Enable MOTD Fixer", 0, true, 0.0, true, 1.0);
	g_cVarLogging = CreateConVar("motdf_logging", "1.0", "Enable MOTD Fixer logging", 0, true, 0.0, true, 1.0);
	g_cVarValidateType = CreateConVar("modtf_validatetype","1.0", "0 = IP | 1 = Token authentication", 0, true, 0.0, true, 1.0);
	
	RegAdminCmd("motdf_register", Command_MOTDRegisterServer, ADMFLAG_RCON, "Register the current server to use the MOTD redirect service.");
}

public void OnAllPluginsLoaded()
{
	if (!STEAMWORKS_AVAILABLE()) {
		SetFailState("Unable to find SteamWorks. Please install it from https://forums.alliedmods.net/showthread.php?t=229556");
	} else if (!SMJANSSON_AVAILABLE()) {
		SetFailState("Unable to find SMJansson. Please install it from https://forums.alliedmods.net/showthread.php?t=184604");
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("MOTDF_ShowMOTDPanel", Native_MOTDF_ShowMOTDPanel);
	return APLRes_Success;
}

public void OnMapStart()
{
	cfg.Load();
}

public void OnConfigsExecuted()
{
	// Apply fix for the latest CS:GO Update that broken MOTD functionality
	ServerCommand("sm_cvar sv_disable_motd 0");
}
