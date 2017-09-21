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


methodmap MOTDConfig
{
	public KeyValues Init(char[] szPath, int iPathMaxSize)
	{
		KeyValues kv = null;
		
		BuildPath(Path_SM, szPath, iPathMaxSize, "configs/motdfix.txt");
		kv = new KeyValues("MOTD Fix");
		return kv;
	}
	
	public bool Load()
	{
		char szLocalPath[PLATFORM_MAX_PATH + 1];
		KeyValues kv = this.Init(szLocalPath, sizeof(szLocalPath));
		
		if (kv.ImportFromFile(szLocalPath))
		{
			MOTDFLogMessage("Loading KeyValues from file '%s'.", szLocalPath);
			kv.GetString("Base URL", g_szBaseURL, sizeof(g_szBaseURL), "https://motd.dubbeh.net");
			kv.GetString("Server Token", g_szServerToken, sizeof(g_szServerToken), "");
		} else {
			MOTDFLogMessage("Unable to find '%s'. Creating new file...", szLocalPath);
			
			kv.SetString("Base URL", "https://motd.dubbeh.net");
			kv.SetString("Server Token", "");
			kv.Rewind();
			
			if (!kv.ExportToFile(szLocalPath))
			{
				delete kv;
				SetFailState("There was a problem exporting the keyvalues structure.");
			}
		}
		
		delete kv;
	}
	
	public bool Save()
	{
		char szLocalPath[PLATFORM_MAX_PATH + 1];
		KeyValues kv = this.Init(szLocalPath, sizeof(szLocalPath));
		
		// Make sure we delete the old config file first
		DeleteFile(szLocalPath);
		
		kv.SetString("Base URL", g_szBaseURL);
		kv.SetString("Server Token", g_szServerToken);
		kv.Rewind();
		if (!kv.ExportToFile(szLocalPath))
		{
			delete kv;
			SetFailState("There was a problem exporting the keyvalues to file.");
		}
		
		delete kv;
	}
};
