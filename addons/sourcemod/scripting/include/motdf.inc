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


#if defined _motdf_included
 #endinput
#endif
#define _motdf_included

public SharedPlugin __pl_motdf =
{
    name = "motdf",
    file = "motdf.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

/*
 * Show an MOTD Panel in CS:GO for the URL
 *
 * @param 	iClientIndex = The current server client index to display to
 * @param	szTitle = MOTD panel title
 * @param 	szURL = The URL to display
 * @param	bHidden = Display or Hide the panel (Only hidden works for now)
 * @param	iPanelWidth = MOTD Panel Width (Ignored from the reason above)
 * @param	iPanelHeight = MOTD Panel Height (Ignored from the reason above)
 * @return	False on failure - True on success
 *
 */
native int MOTDF_ShowMOTDPanel (int iClientIndex, const char []szTitle, const char []szURL, bool bHidden = true, int iPanelWidth = 1280, int iPanelHeight = 720);
