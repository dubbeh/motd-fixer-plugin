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
			// Grab all client index parameter
			int iClientIndex = GetNativeCell(1);
			
			// Added check to avoid running anything with disconnected clients
			if (!iClientIndex || !IsClientConnected(iClientIndex) || !IsClientInGame(iClientIndex))
				return 0;
			
			// Check that the client has cl_disablehtmlmotd off before we register any URLs
			if (g_bDisabledHTMLMOTD[iClientIndex]) {
				PrintToChat(iClientIndex, "%T", "Disabled HTML MOTD On", LANG_SERVER);
				return 0;
			}
			
			if ((g_szServerToken[0] && g_cVarValidateType.IntValue == VALIDATE_TOKEN) || 
				g_cVarValidateType.IntValue == VALIDATE_IP)
			{
				int iClientSerial = GetClientSerial(iClientIndex); // Convert client index to serial for thread safe operations
				GetNativeString(2, szTitle, sizeof(szTitle)); // MOTD panel title
				GetNativeString(3, szURL, sizeof(szURL)); // Grab the URL
				bool bHidden = GetNativeCell(4); // Is the window hidden
				int iPanelWidth = GetNativeCell(5); // Get the MOTD panel width
				int iPanelHeight = GetNativeCell(6); // Get the MOTD panel height
				
				// If unsupported mod found - Load a panel with the users settings and display a message
				if (!IsEngineSupported(iClientIndex)) {
					ShowMOTDPanelCustom(iClientIndex, szTitle, szURL, bHidden);
					return 0;
				}
				
				if (iClientSerial > 0 && szURL[0])
				{
					// Is SteamWorks available?
					if (STEAMWORKS_AVAILABLE() && SteamWorks_IsLoaded())
					{
						// First send the URL to be registered with the server
						Format(szRegisterURL, sizeof(szRegisterURL), "%s/register.php?client=1", g_szBaseURL);
						
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
		GetClientAuthId(iClient, AuthId_SteamID64, szClientSteamID64, sizeof(szClientSteamID64)))
	{
		if (SetServerInfoPostData(hHTTPRequest))
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
		} else {
			MOTDFLogMessage("SetClientRequestData() Error: Unable to set Server Info.");
			return false;
		}
	}
	
	MOTDFLogMessage("SetClientRequestData() Error: Unable to set Client IP or Auth ID.");
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
 */
public void SteamWorks_OnClientURLRegisterComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any dpClient)
{
	char szResponseData[128] = "";
	int iResponseSize = 0;
	bool bSuccess = false;
	int iClient = 0;
	char szClientSteamID64[64] = "";
	char szClientIP[64] = "";
	char szURL[128] = "";
	Handle hHTTPRequest = INVALID_HANDLE;
	
	// Check if request was successfull
	if (!bFailure && bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		if (SteamWorks_GetHTTPResponseBodySize(hRequest, iResponseSize) && 
			SteamWorks_GetHTTPResponseBodyData(hRequest, szResponseData, iResponseSize))
		{
			// First check the DataPack is valid first before we do any client processing
			if (dpClient != INVALID_HANDLE)
			{
				bSuccess = ReadJSONResponse(szResponseData, false);

				if (bSuccess && g_bJSONIsTokenValid && !g_bJSONServerIsBlocked)
				{
					ResetPack(dpClient);
					iClient = GetClientFromSerial(ReadPackCell(dpClient));
					if (iClient > 0 && IsClientConnected(iClient) && IsClientInGame(iClient))
					{
						ReadPackString(dpClient, szClientSteamID64, sizeof(szClientSteamID64));
						ReadPackString(dpClient, szClientIP, sizeof(szClientIP));
						Format(szURL, sizeof(szURL), "%s/redirect.php?sid=%s&ip=%s", g_szBaseURL, szClientSteamID64, szClientIP);
						LoadMOTDPanel(iClient, "MOTD Fixer", szURL, false);
					} else {
						// Assume client DC'd - Issue a "Delete from database" command instead
						ReadPackString(dpClient, szClientSteamID64, sizeof(szClientSteamID64));
						ReadPackString(dpClient, szClientIP, sizeof(szClientIP));
						
						Format(szURL, sizeof(szURL), "%s/delete.php?sid=%s&ip=%s", g_szBaseURL, szClientSteamID64, szClientIP);
						
						if ((hHTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, szURL)) != INVALID_HANDLE)
						{
							if (!SetServerInfoPostData(hHTTPRequest) || 
								!SteamWorks_SetHTTPRequestGetOrPostParameter(hHTTPRequest, "servertoken", (g_cVarValidateType.IntValue == VALIDATE_TOKEN) ? g_szServerToken : "") || 
								!SteamWorks_SetHTTPRequestNetworkActivityTimeout(hHTTPRequest, 10) || 
								!SteamWorks_SetHTTPCallbacks(hHTTPRequest, SteamWorks_OnClientURLDeleteComplete) || 
								!SteamWorks_SendHTTPRequest(hHTTPRequest))
							{
								MOTDFLogMessage("SteamWorks_OnClientURLRegisterComplete () : Error sending the client delete command.");
							}
						}
					}
				}
				// Check if the server token is invalid and not blocked
				else if (!g_bJSONIsTokenValid && !g_bJSONServerIsBlocked)
				{
					// Lets re-register the server because the token appears to be invalid
					if (g_cVarAutoRegister.BoolValue)
					{
						MOTDFLogMessage("SteamWorks_OnClientURLRegisterComplete () : Server token is invalid - Registering server again.");
						RegisterServer(0);
					} else {
						MOTDFLogMessage("SteamWorks_OnClientURLRegisterComplete () : Server token is invalid - Run motdf_register to update (auto-registering disabled in the config)");
					}
					
					ResetPack(dpClient);
					iClient = GetClientFromSerial(ReadPackCell(dpClient));
					
					if (iClient > 0 && IsClientConnected(iClient) && IsClientInGame(iClient))
						PrintToChat(iClient, "%T", "Token Invalid", LANG_SERVER);
				}
				// Server is blocked
				else if (g_bJSONServerIsBlocked)
				{
					MOTDFLogMessage("SteamWorks_OnClientURLRegisterComplete () : Server appears to be blocked from using %s.", g_szBaseURL);
				}
				
				CloseHandle(dpClient);
			} else {
				MOTDFLogMessage("SteamWorks_OnClientURLRegisterComplete () : Clients DataPack handle is invalid.");
			}
		} else {
			MOTDFLogMessage("SteamWorks_OnClientURLRegisterComplete () : Error getting registration response");
		}
	} else {
		MOTDFLogMessage("SteamWorks_OnClientURLRegisterComplete () : Error recieving HTTP request - Status Code: %d", eStatusCode);
	}
	
	// Make sure to close the handle to the HTTP Request
	CloseHandle(hRequest);
}

public void SteamWorks_OnClientURLDeleteComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data)
{
	// Check if request was unsuccessfull
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		MOTDFLogMessage("SteamWorks_OnClientURLDeleteComplete () : Error recieving HTTP request - Status Code: %d", eStatusCode);
	}
	
	CloseHandle(hRequest);
}
