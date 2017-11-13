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

void MOTDFLogMessage(char[] szInput, any...)
{
	char szBuffer[512] = "";
	
	if (g_cVarLogging.BoolValue)
	{
		VFormat(szBuffer, sizeof(szBuffer), szInput, 2);
		LogMessage(szBuffer);
	}
}

void LoadMOTDPanel(int iClient, char[] szTitle, char[] szPage, bool bHidden)
{
	if (!IsClientConnected(iClient) || !IsClientInGame(iClient))
		return;
	
	Handle kv = INVALID_HANDLE;
	
	kv = CreateKeyValues("data");
	
	KvSetString(kv, "title", szTitle);
	KvSetNum(kv, "type", MOTDPANEL_TYPE_URL);
	KvSetString(kv, "msg", szPage);
	KvSetNum(kv, "cmd", 0); //http://forums.alliedmods.net/showthread.php?p=1220212
	//KvSetNum(kv, "customsvr", 1); // Only for big panels in TF2 - Thanks Dr. McKay
	ShowVGUIPanel(iClient, "info", kv, bHidden);
	CloseHandle(kv);
}

bool ReadJSONResponse(char[] szResponseData, bool bGetServerToken)
{
	Handle hJSON = INVALID_HANDLE;
	bool bSuccess = false;
	g_bJSONServerIsBlocked = true;
	g_bJSONIsTokenValid = false;
	
	if (SMJANSSON_AVAILABLE())
	{
		if ((hJSON = json_load(szResponseData)) != INVALID_HANDLE)
		{
			if (bGetServerToken)
				json_object_get_string(hJSON, "token", g_szServerToken, MAX_TOKEN_SIZE);

			g_bJSONServerIsBlocked = json_object_get_bool(hJSON, "is_blocked");
			g_bJSONIsTokenValid = json_object_get_bool(hJSON, "is_token_valid");
			json_object_get_string(hJSON, "msg", g_szJSONResponseMsg, MAX_RESPONSE_MSG_SIZE);
			bSuccess = json_object_get_bool(hJSON, "success");
			
			CloseHandle(hJSON);
		} else {
			MOTDFLogMessage("Error parsing JSON Response.");
			MOTDFLogMessage("Response returned: %s\n", szResponseData);
		}
	} else {
		MOTDFLogMessage("Unable to find SMJansson. Please install it from https://forums.alliedmods.net/showthread.php?t=184604");
	}
	
	return bSuccess;
}

bool SetServerInfoPostData(Handle hHTTPRequest)
{
	char szServerName[64] = "";
	char szServerIP[64] = "";
	char szServerPort[8] = "";
	
	if (GetServerName(szServerName, sizeof(szServerName)) && 
		GetServerIP(szServerIP, sizeof(szServerIP)) && 
		GetServerPort(szServerPort, sizeof(szServerPort)))
	{
		return SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "servername", szServerName) && 
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "serverip", szServerIP) && 
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "serverport", szServerPort);
	} else {
		return false;
	}
}

bool GetServerName(char[] szBuffer, int iBufferSize)
{
	ConVar cVarHostName = null;
	
	if ((cVarHostName = FindConVar("hostname")) != null)
	{
		cVarHostName.GetString(szBuffer, iBufferSize);
		delete cVarHostName;
		return true;
	}
	
	MOTDFLogMessage("Error getting server name.");
	return false;
}

bool GetServerIP(char[] szBuffer, int iBufferSize)
{
	int iServerIP[4];
	
	if (SteamWorks_GetPublicIP(iServerIP))
	{
		Format(szBuffer, iBufferSize, "%d.%d.%d.%d", iServerIP[0], iServerIP[1], iServerIP[2], iServerIP[3]);
		return true;
	}
	
	MOTDFLogMessage("Error getting server IP.");
	return false;
}

bool GetServerPort(char[] szBuffer, int iBufferSize)
{
	ConVar cVarServerPort = null;
	
	if ((cVarServerPort = FindConVar("hostport")) != null)
	{
		IntToString(cVarServerPort.IntValue, szBuffer, iBufferSize);
		delete cVarServerPort;
		return true;
	}
	
	MOTDFLogMessage("Error getting server port.");
	return false;
}

// Check if the game engine is supported
bool IsEngineSupported(int iClient)
{
	if (g_EngineVersion != Engine_CSGO)
	{
		if (iClient && IsClientConnected(iClient) && IsClientInGame(iClient))
		    PrintToChat(iClient, "%T", "Engine Unsupported", LANG_SERVER);
		else if (!iClient)
			PrintToServer("%T", "Engine Unsupported", LANG_SERVER);

		return false;
	}
	
	return true;
}

void ShowMOTDPanelCustom (int iClient, const char[] szTitle, const char[] szPage, bool bHidden)
{
	Handle kv = INVALID_HANDLE;
	kv = CreateKeyValues("data");
		
	KvSetString(kv, "title", szTitle);
	KvSetNum(kv, "type", MOTDPANEL_TYPE_URL);
	KvSetString(kv, "msg", szPage);
	KvSetNum(kv, "cmd", 0); //http://forums.alliedmods.net/showthread.php?p=1220212
	//KvSetNum(kv, "customsvr", 1); // Only for big panels in TF2 - Thanks Dr. McKay
	ShowVGUIPanel(iClient, "info", kv, bHidden);
	CloseHandle(kv);
}