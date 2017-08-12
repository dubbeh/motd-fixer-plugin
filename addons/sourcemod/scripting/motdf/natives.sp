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


//native int MOTDF_ShowMOTDPanel (int iClientIndex, const char []szTitle, const char []szURL, bool bHidden = true, int iPanelWidth = 1280, int iPanelHeight = 720);
public int Native_MOTDF_ShowMOTDPanel (Handle hPlugin, int iNumParams)
{
	Handle hHTTPRequest = null;
	char szTitle[64] = "";
	char szURL[128] = "";
	char szRegisterURL[128] = "";

	if (g_cVarEnable.BoolValue)
	{
		if (iNumParams == 6)
		{
			if (g_szServerToken[0])
			{
				// Grab all the parameters
				int iClientIndex = GetNativeCell(1);
				int iClientSerial = GetClientSerial(iClientIndex); // Convert client index to serial for thread safe operations
				GetNativeString(2, szTitle, sizeof(szTitle)); // MOTD panel title - Unused right now but grabbed for the future
				GetNativeString(3, szURL, sizeof(szURL)); // Grab the URL
				bool bSilent = GetNativeCell(4); // Silent MOTD loading forced for now but still grab it
				int iPanelWidth = GetNativeCell(5); // Get the MOTD panel width
				int iPanelHeight = GetNativeCell(6); // Get the MOTD panel height

				if (iClientSerial > 0 && szURL[0])
				{
					// First send the URL to be registered with the server
					if (SteamWorks_IsLoaded())
					{
						Format(szRegisterURL, sizeof(szRegisterURL), "%s?client=1", g_szRegisterURL);
						if ((hHTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, szRegisterURL)) != INVALID_HANDLE)
						{
							if (!SetRequestData(hHTTPRequest, iClientIndex, iClientSerial, szURL) ||
								!SteamWorks_SetHTTPCallbacks(hHTTPRequest, SteamWorks_OnClientURLRegisterComplete) ||
								!SteamWorks_SendHTTPRequest(hHTTPRequest))
							{
								ThrowNativeError(SP_ERROR_NATIVE, "Error setting variables for the HTTP request.");
								CloseHandle(hHTTPRequest);
							}
						} else {
							ThrowNativeError(SP_ERROR_NATIVE, "Error creating the SteamWorks HTTP request.");
						}
					} else {
						ThrowNativeError(SP_ERROR_NATIVE, "SteamWorks doesn't appear to be loaded. Make sure to have it installed first.");
					}
				} else {
					ThrowNativeError(SP_ERROR_NATIVE, "Client serial appears to be 0 or no URL set.");
				}
			} else {
				ThrowNativeError(SP_ERROR_NATIVE, "No server token set. Make sure to run motdf_register with RCON access first.");
			}
		} else {
			ThrowNativeError(SP_ERROR_NATIVE, "Invalid number of parameters.");
		}
	}
}

// Set HTTP Post data - clientip and steamid64
bool SetRequestData(Handle hHTTPRequest, int iClient, int iClientSerial, char []szClientURL)
{
	DataPack dpClient = null;
	char szClientIP[64] = "";
	char szClientSteamID64[64] = "";
	int iServerIP[4];
	char szServerIP[64] = "";
	
	if (GetClientIP(iClient, szClientIP, sizeof(szClientIP)) &&
		GetClientAuthId(iClient, AuthId_SteamID64, szClientSteamID64, sizeof(szClientSteamID64)) &&
		SetServerInfoPostData(hHTTPRequest))
	{
		dpClient = new DataPack();
		dpClient.WriteCell(iClientSerial);
		dpClient.WriteString(szClientSteamID64);
		dpClient.Reset(false);
		
		SteamWorks_GetPublicIP(iServerIP);
		Format(szServerIP, sizeof(szServerIP), "%d.%d.%d.%d", iServerIP[0], iServerIP[1], iServerIP[2], iServerIP[3]);
		
		return SteamWorks_SetHTTPRequestContextValue(hHTTPRequest, dpClient) &&
			SteamWorks_SetHTTPRequestGetOrPostParameter (hHTTPRequest, "clientip", szClientIP) &&
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "steamid64", szClientSteamID64) &&
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "url", szClientURL) &&
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "servertoken", g_szServerToken);
	}

	return false;
}

/*
 * This is called after the client URL has been registered with the server - now we need to load the standard URL and let the server side script do the rest
 * 
 */
public void SteamWorks_OnClientURLRegisterComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any dpClient)
{
	char szResponseData[128] = "";
	int iResponseSize = 0;
	char szJSONResMsg[128] = "";
	bool bIsBlocked = false;
	int iClient = 0;
	char szClientSteamID64[64] = "";
	char szURL[128] = "";
	
	// Check if request was successfull
	if (!bFailure && bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		if (SteamWorks_GetHTTPResponseBodySize(hRequest, iResponseSize) &&
			SteamWorks_GetHTTPResponseBodyData(hRequest, szResponseData, iResponseSize))
		{
			if (ReadJSONResponse(szResponseData, szJSONResMsg, sizeof (szJSONResMsg), bIsBlocked))
			{
				// URL registered successfully - now we load the normal MOTD panel and let the web server do the rest
				if (dpClient != INVALID_HANDLE)
				{
					ResetPack(dpClient);
					iClient = GetClientFromSerial(ReadPackCell(dpClient));
					if (iClient > 0 && IsClientConnected(iClient) && IsClientInGame(iClient))
					{
						ReadPackString(dpClient, szClientSteamID64, sizeof(szClientSteamID64));
						Format(szURL, sizeof(szURL), "%s?sid=%s", g_szRedirectURL, szClientSteamID64);
						LoadMOTDPanel(iClient, "MOTD Fixer", szURL, false);
					}
				}
			} else {
				MOTDFLogMessage("Error: %s - Is Server Blocked: %s", szJSONResMsg, bIsBlocked ? "Yes" : "No");
			}
		} else {
			MOTDFLogMessage("Error getting registration response");
		}
	} else {
		MOTDFLogMessage("Error recieving HTTP request - Status Code: %d", eStatusCode);
	}
	
	// Make sure to close the handles to the DataPack and the HTTP Request
	CloseHandle(dpClient);
	CloseHandle(hRequest);
}
