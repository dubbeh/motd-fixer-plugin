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


public Action Command_MOTDRegisterServer(int iClient, int iArgs)
{
	if (g_cVarEnable.BoolValue) {
		RegisterServer(iClient);
	}
	
	return Plugin_Handled;
}

void RegisterServer(int iClient)
{
	char szRegisterURL[255] = "";
	Handle hHTTPRequest = INVALID_HANDLE;
	
	if (g_cVarValidateType.IntValue == VALIDATE_TOKEN) {
		
		if (STEAMWORKS_AVAILABLE() && SteamWorks_IsLoaded()) {
			
			Format(szRegisterURL, sizeof(szRegisterURL), "%s?server=1", g_szRegisterURL);
			
			if ((hHTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, szRegisterURL)) != INVALID_HANDLE) {
				
				if (SetServerInfoPostData(hHTTPRequest) && 
					SteamWorks_SetHTTPRequestNetworkActivityTimeout(hHTTPRequest, 10) && 
					SteamWorks_SetHTTPCallbacks(hHTTPRequest, SteamWorks_OnRegisterComplete) && 
					SteamWorks_SendHTTPRequest(hHTTPRequest))
				{
					MOTDFLogMessage("Command_MOTDRegisterServer () Registering server.");
				} else {
					MOTDFLogMessage("Command_MOTDRegisterServer () Error setting HTTP request data for server registration.");
				}
			} else {
				MOTDFLogMessage("Command_MOTDRegisterServer () Unable to create HTTP request.");
			}
		} else {
			MOTDFLogMessage("Command_MOTDRegisterServer () SteamWorks doesn't appear to be loaded. Make sure to have it installed and running first.");
		}
	} else {
		ReplyToCommand(iClient, "No need to register under IP based validation");
	}
	return;
}

public void SteamWorks_OnRegisterComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode)
{
	char szResponseData[512] = "";
	int iResponseSize = 0;
	char szJSONResMsg[512];
	bool bIsBlocked = false;
	
	if (!bFailure && bRequestSuccessful && eStatusCode == k_EHTTPStatusCode200OK)
	{
		if (SteamWorks_GetHTTPResponseBodySize(hRequest, iResponseSize) && SteamWorks_GetHTTPResponseBodyData(hRequest, szResponseData, iResponseSize))
		{
			if (ReadJSONResponse(szResponseData, szJSONResMsg, sizeof(szJSONResMsg), bIsBlocked, g_szServerToken, sizeof(g_szServerToken)))
			{
				MOTDFLogMessage(szJSONResMsg);
				
				if (g_szServerToken[0]) {
					g_Config.Save();
				} else {
					MOTDFLogMessage("SteamWorks_OnRegisterComplete() Error: No server token recieved from the registration request. Maybe the website is down?");
				}
			} else {
				MOTDFLogMessage("SteamWorks_OnRegisterComplete() Error: %s - Is Server Blocked: %s", szJSONResMsg, bIsBlocked ? "Yes" : "No");
			}
		} else {
			MOTDFLogMessage("SteamWorks_OnRegisterComplete() Error retrieving registration response data.");
		}
	} else {
		MOTDFLogMessage("SteamWorks_OnRegisterComplete() Error: Response code %d .", eStatusCode);
	}
	
	CloseHandle(hRequest);
}
