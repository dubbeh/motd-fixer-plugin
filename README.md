# MOTD Fixer - SourceMod Plugin

## About
Fixes the changes to MOTD's in the latest Steam updates under CS:GO - Where you was unable to load anything past the first initial URL.
This issue is overcome by grabbing a users steam ID and prefixing them with a unique URL, to load concurrent requests from under each MOTD request and pre-registering their URL of choice.


## Installation:
1. Download and install SteamWorks from https://forums.alliedmods.net/showthread.php?t=229556
2. Download and install SMJansson from https://forums.alliedmods.net/showthread.php?t=184604
3. Grab the last download from the top right and extract to your game server folder (Everything should be self explanatory from the directory structure)
4. One you have everything installed and running correctly. Run "motdf_register" from the server console, to register your server for access and get a unique server token.
5. Now everything should be working as intended again - If you got a success on registering the server.

## License
This whole project is licensed under the GPLv3.

##Credits
Neuro_Toxin (Couple of ideas), Thrawn (SMJansson), KyleS (SteamWorks).

