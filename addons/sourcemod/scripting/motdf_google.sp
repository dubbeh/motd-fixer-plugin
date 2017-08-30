/*
 * MOTD Fixer Google Example
 *
 * Example on how to use MOTD Fixer with a Google search
 *
 * Coded by dubbeh - www.dubbeh.net
 *
 * Licensed under the GPLv3
 *
 */


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <motdf>


public Plugin myinfo = 
{
	name = "MOTD Fixer Google Example",
	author = "dubbeh",
	description = "Basic example showing how MOTD Fixer works",
	version = "1.0",
	url = "https://dubbeh.net"
};


public void OnPluginStart()
{
	RegConsoleCmd("sm_google", Command_Google, "Launches Google with a search query string");
}

public Action Command_Google(int iClient, int iArgs)
{
	char szURL[256] = "";
	char szQueryString[128] = "";
	
	GetCmdArgString(szQueryString, sizeof(szQueryString));
	ReplaceString(szQueryString, sizeof(szQueryString), " ", "+", false);
	Format(szURL, sizeof(szURL), "https://www.google.com?search?q=%s", szQueryString);
	MOTDF_ShowMOTDPanel(iClient, "Google", szURL, false, 1024, 576);
	return Plugin_Handled;
}