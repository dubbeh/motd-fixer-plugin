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


public int Native_MOTDF_ShowMOTDPanel(Handle hPlugin, int iNumParams)
{
	Handle hHTTPRequest = null;
	char szTitle[64] = "";
	char szURL[255] = "";
	char szRegisterURL[255] = "";
	
	if (g_cVarEnable.BoolValue)
	{
		if (iNumParams == 6)
		{
			// Grab all the parameters
			int iClientIndex = GetNativeCell(1);
			
			// Added check to avoid running anything with disconnected clients
			if (!iClientIndex || !IsClientConnected(iClientIndex) || !IsClientInGame(iClientIndex))
				return 0;
			
			if ((g_szServerToken[0] && g_cVarValidateType.IntValue == VALIDATE_TOKEN) || 
				g_cVarValidateType.IntValue == VALIDATE_IP)
			{
				int iClientSerial = GetClientSerial(iClientIndex); // Convert client index to serial for thread safe operations
				GetNativeString(2, szTitle, sizeof(szTitle)); // MOTD panel title
				GetNativeString(3, szURL, sizeof(szURL)); // Grab the URL
				bool bHidden = GetNativeCell(4); // Is the window hidden
				int iPanelWidth = GetNativeCell(5); // Get the MOTD panel width
				int iPanelHeight = GetNativeCell(6); // Get the MOTD panel height
				
				if (iClientSerial > 0 && szURL[0])
				{
					// Is SteamWorks available?
					if (STEAMWORKS_AVAILABLE() && SteamWorks_IsLoaded())
					{
						// First send the URL to be registered with the server
						Format(szRegisterURL, sizeof(szRegisterURL), "%s?client=1", g_szRegisterURL);
						if ((hHTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, szRegisterURL)) != INVALID_HANDLE)
						{
							if (SetClientRequestData(hHTTPRequest, iClientIndex, iClientSerial) && 
								SetPanelRequestData(hHTTPRequest, szTitle, szURL, bHidden, iPanelWidth, iPanelHeight))
							{
								if (!SteamWorks_SetHTTPRequestNetworkActivityTimeout(hHTTPRequest, 10) || 
									!SteamWorks_SetHTTPCallbacks(hHTTPRequest, SteamWorks_OnClientURLRegisterComplete) || 
									!SteamWorks_SendHTTPRequest(hHTTPRequest))
								{
									ThrowNativeError(SP_ERROR_NATIVE, "Error setting SteamWorks HTTP request info or sending.");
								} else {
									return 1;
								}
							} else {
								ThrowNativeError(SP_ERROR_NATIVE, "Error setting client or panel request data.");
							}
							
							CloseHandle(hHTTPRequest);
						} else {
							ThrowNativeError(SP_ERROR_NATIVE, "Error creating the SteamWorks HTTP request.");
						}
					} else {
						ThrowNativeError(SP_ERROR_NATIVE, "SteamWorks doesn't appear to be loaded. Make sure to have it installed and running first.");
					}
				} else {
					ThrowNativeError(SP_ERROR_NATIVE, "Client serial appears to be 0 or no URL set.");
				}
			} else {
				if (g_cVarAutoRegister.BoolValue) {
					ReplyToCommand(iClientIndex, "[MOTD-FIXER] No server token set. Auto-Registering server for usage.");
					RegisterServer(iClientIndex);
				} else {
					ThrowNativeError(SP_ERROR_NATIVE, "No server token set. Make sure to run motdf_register with RCON access first.");
				}
			}
		} else {
			ThrowNativeError(SP_ERROR_NATIVE, "Invalid number of parameters.");
		}
	}
	
	return 0;
}

// Set HTTP Post data - clientip and steamid64
bool SetClientRequestData(Handle hHTTPRequest, int iClient, int iClientSerial)
{
	DataPack dpClient = null;
	char szClientIP[64] = "";
	char szClientSteamID64[64] = "";
	
	if (GetClientIP(iClient, szClientIP, sizeof(szClientIP)) && 
		GetClientAuthId(iClient, AuthId_SteamID64, szClientSteamID64, sizeof(szClientSteamID64)) && 
		SetServerInfoPostData(hHTTPRequest))
	{
		dpClient = new DataPack();
		dpClient.WriteCell(iClientSerial);
		dpClient.WriteString(szClientSteamID64);
		dpClient.WriteString(szClientIP);
		dpClient.Reset(false);
		
		if (SteamWorks_SetHTTPRequestContextValue(hHTTPRequest, dpClient) && 
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "clientip", szClientIP) && 
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "steamid64", szClientSteamID64) && 
			SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "servertoken", (g_cVarValidateType.IntValue == VALIDATE_TOKEN) ? g_szServerToken : ""))
		{
			return true;
		} else {
			MOTDFLogMessage("SetClientRequestData() Error: Unable to set client or server post data.");
			return false;
		}
	}
	
	MOTDFLogMessage("SetClientRequestData() Error: Unable to set Client IP, Auth ID or Server Info.");
	return false;
}

bool SetPanelRequestData(Handle hHTTPRequest, char[] szTitle, char[] szURL, bool bPanelHidden, int iPanelWidth, int iPanelHeight)
{
	char szPanelWidth[8] = "";
	char szPanelHeight[8] = "";
	
	IntToString(iPanelWidth, szPanelWidth, sizeof(szPanelWidth));
	IntToString(iPanelHeight, szPanelHeight, sizeof(szPanelHeight));
	
	// Check that the panel_url isn't too long
	if (strlen(szURL) >= 255) {
		MOTDFLogMessage("SetPanelRequestData() Error: panel_url is too long >= 255 characters");
		return false;
	}
	
	if (SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "panel_title", szTitle) && 
		SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "panel_url", szURL) && 
		SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "panel_hidden", bPanelHidden ? "1" : "0") && 
		SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "panel_width", szPanelWidth) && 
		SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "panel_height", szPanelHeight))
	{
		return true;
	} else {
		MOTDFLogMessage("SetPanelRequestData() Error: Unable to set client panel data.");
		return false;
	}
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
	char szClientIP[64] = "";
	char szURL[128] = "";
	
	// Check if request was successfull
	if (!bFailure && bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		if (SteamWorks_GetHTTPResponseBodySize(hRequest, iResponseSize) && 
			SteamWorks_GetHTTPResponseBodyData(hRequest, szResponseData, iResponseSize))
		{
			if (ReadJSONResponse(szResponseData, szJSONResMsg, sizeof(szJSONResMsg), bIsBlocked))
			{
				// URL registered successfully - now we load the normal MOTD panel and let the web server do the rest
				if (dpClient != INVALID_HANDLE && !bIsBlocked)
				{
					ResetPack(dpClient);
					iClient = GetClientFromSerial(ReadPackCell(dpClient));
					if (iClient > 0 && IsClientConnected(iClient) && IsClientInGame(iClient))
					{
						ReadPackString(dpClient, szClientSteamID64, sizeof(szClientSteamID64));
						ReadPackString(dpClient, szClientIP, sizeof(szClientIP));
						Format(szURL, sizeof(szURL), "%s?sid=%s&ip=%s", g_szRedirectURL, szClientSteamID64, szClientIP);
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
